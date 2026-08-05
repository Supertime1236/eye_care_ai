import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/rank_tier.dart';

/// Một dòng trong bảng xếp hạng — ứng với 1 người dùng.
class LeaderboardEntry {
  LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.avatarUrl,
    required this.streakDays,
    required this.tierId,
    required this.updatedAt,
  });

  final String uid;
  final String displayName;
  final String? avatarUrl;
  final int streakDays;
  final String tierId;
  final DateTime? updatedAt;

  RankTier get tier => RankTiers.all.firstWhere(
        (t) => t.id == tierId,
        orElse: () => RankTiers.forStreak(streakDays),
      );

  factory LeaderboardEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final streakDays = (data['streakDays'] as num?)?.toInt() ?? 0;
    return LeaderboardEntry(
      uid: doc.id,
      displayName: (data['displayName'] as String?)?.trim().isNotEmpty == true
          ? data['displayName'] as String
          : 'Ẩn danh',
      avatarUrl: data['avatarUrl'] as String?,
      streakDays: streakDays,
      tierId: (data['tierId'] as String?) ?? RankTiers.forStreak(streakDays).id,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Đồng bộ streak lên Firestore (collection `leaderboard`, mỗi document là
/// 1 user, id = uid) và đọc bảng xếp hạng của TẤT CẢ người dùng, sắp xếp
/// giảm dần theo số ngày streak (ai duy trì lâu nhất đứng đầu).
///
/// Cấu trúc Firestore:
///   leaderboard/{uid}: {
///     displayName: string,
///     avatarUrl: string?,
///     streakDays: number,
///     tierId: string,
///     updatedAt: Timestamp,
///   }
///
/// LƯU Ý: cần bật Cloud Firestore trong Firebase Console cho project này (và
/// thêm rule cho phép user đã đăng nhập đọc toàn bộ collection `leaderboard`
/// nhưng chỉ được ghi vào document của chính mình), ví dụ:
///
/// match /leaderboard/{uid} {
///   allow read: if request.auth != null;
///   allow write: if request.auth != null && request.auth.uid == uid;
/// }
class LeaderboardService {
  LeaderboardService._();
  static final LeaderboardService instance = LeaderboardService._();

  CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection('leaderboard');

  /// Đẩy streak hiện tại của user đang đăng nhập lên Firestore. Gọi mỗi khi
  /// streakDays thay đổi (sau refreshHabitsFromDevice) — an toàn để gọi
  /// nhiều lần, Firestore sẽ chỉ merge/ghi đè field liên quan.
  Future<void> syncMyStreak({required int streakDays}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // Khách (guest mode) không có bảng xếp hạng.

    final tier = RankTiers.forStreak(streakDays);
    final displayName = (user.displayName?.trim().isNotEmpty == true)
        ? user.displayName!
        : (user.email?.split('@').first ?? 'Ẩn danh');

    try {
      await _collection.doc(user.uid).set({
        'displayName': displayName,
        'avatarUrl': user.photoURL,
        'streakDays': streakDays,
        'tierId': tier.id,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Không chặn luồng chính của app (vd offline, chưa bật Firestore) —
      // bảng xếp hạng chỉ là tính năng phụ, không được làm app bị crash.
    }
  }

  /// Lấy top N người dùng có streak cao nhất, giảm dần.
  Future<List<LeaderboardEntry>> fetchTopStreaks({int limit = 50}) async {
    try {
      final snapshot =
          await _collection.orderBy('streakDays', descending: true).limit(limit).get();
      return snapshot.docs.map(LeaderboardEntry.fromDoc).toList();
    } catch (e) {
      return const [];
    }
  }

  /// Stream realtime của bảng xếp hạng — dùng cho màn hình Rank để tự cập
  /// nhật khi có người khác đổi streak, không cần người dùng tự kéo làm mới.
  Stream<List<LeaderboardEntry>> watchTopStreaks({int limit = 50}) {
    return _collection
        .orderBy('streakDays', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(LeaderboardEntry.fromDoc).toList())
        .handleError((_) {
      // Nuốt lỗi (vd Firestore chưa bật) để không làm crash StreamBuilder —
      // UI sẽ tự hiện trạng thái rỗng/lỗi nhẹ nhàng.
    });
  }

  /// Thứ hạng (1-based) của 1 uid trong toàn bộ bảng xếp hạng, null nếu
  /// không nằm trong top đã tải hoặc chưa có dữ liệu.
  static int? rankOf(List<LeaderboardEntry> entries, String? uid) {
    if (uid == null) return null;
    final index = entries.indexWhere((e) => e.uid == uid);
    if (index == -1) return null;
    return index + 1;
  }
}
