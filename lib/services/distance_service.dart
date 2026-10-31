import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Đo khoảng cách MẮT -> MÀN HÌNH bằng camera trước, dùng cho bài kiểm tra
/// thị lực và chức năng nhắc giữ khoảng cách (thay lời nhắc tĩnh "giữ cách
/// 40cm" bằng số đo THẬT theo thời gian thực).
///
/// CÁCH TÍNH (không cần hiệu chỉnh riêng từng máy):
///   1. ML Kit tìm khuôn mặt + 2 điểm mốc MẮT TRÁI/MẮT PHẢI trên khung hình.
///   2. Khoảng cách 2 mắt tính bằng PIXEL trên ảnh, so với khoảng cách 2
///      đồng tử TRUNG BÌNH của người trưởng thành (~6.3cm, số liệu nhân
///      trắc học phổ biến) để suy ra khoảng cách thật bằng công thức tam
///      giác đồng dạng:
///         khoảng_cách_cm = (6.3cm × tiêu_cự_px) / khoảng_cách_2_mắt_px
///   3. `tiêu_cự_px` ước lượng từ độ rộng ảnh + góc nhìn (FOV) ngang giả
///      định ~70° — thông số phổ biến của camera trước điện thoại, KHÔNG
///      đọc được chính xác tuyệt đối qua Flutter cho mọi máy.
///      => Sai số nằm chủ yếu ở bước này và gần như TỈ LỆ THUẬN với khoảng cách,
///      nên có thể bù bằng 1 hệ số hiệu chỉnh (xem DistanceMonitorService.calibration).
///
/// BUG ĐÃ SỬA ("Face not detected" dù mặt rõ ràng trong khung hình): dùng
/// `FaceDetectorMode.accurate` + phương án DỰ PHÒNG theo độ rộng khuôn mặt
/// khi thiếu landmark mắt.
///
/// NÂNG CẤP: độ phân giải camera tăng từ `low` (320x240) lên `medium`
/// (~720x480). Ở 40cm khuôn mặt chỉ rộng ~80px trên ảnh `low` — dưới mức ML Kit
/// nhận diện ổn định (khuyến nghị >= ~100px), nên hay chập chờn "không thấy
/// mặt". `medium` cho khuôn mặt ~2 lần rộng hơn mà vẫn đủ nhẹ.
///
/// GIỚI HẠN: ước lượng dựa trên số đo trung bình dân số + giả định góc nhìn
/// camera — sai số thô khoảng ±15-20% (giảm đáng kể sau khi hiệu chỉnh).
/// Kết quả đo 1 khung hình: khoảng cách + xác suất mở mắt từng bên (0.0 =
/// chắc chắn nhắm, 1.0 = chắc chắn mở). Xác suất mắt null nếu ML Kit không
/// trả về được (thường do góc mặt/ánh sáng), lúc đó coi như "chưa xác định
/// được", không nên khẳng định là nhắm hay mở.
class FaceMeasurement {
  const FaceMeasurement({
    required this.distanceCm,
    required this.leftEyeOpenProbability,
    required this.rightEyeOpenProbability,
  });

  final double? distanceCm;
  // LƯU Ý HỆ QUY CHIẾU: đây là mắt TRÁI/PHẢI THẬT của người dùng (theo cách
  // ML Kit gắn nhãn landmark dựa trên cấu trúc khuôn mặt, không phải theo
  // vị trí trái/phải trên ẢNH).
  final double? leftEyeOpenProbability;
  final double? rightEyeOpenProbability;
}

class DistanceService {
  DistanceService._();
  static final instance = DistanceService._();

  static const double _kInterpupillaryDistanceCm = 6.3;
  static const double _kAverageFaceWidthCm = 14.0;
  static const double _kAssumedHorizontalFovDegrees = 70;

  CameraController? _controller;
  FaceDetector? _faceDetector;
  bool _busy = false;
  bool _disposed = false;

  final _distanceController = StreamController<FaceMeasurement?>.broadcast();

  /// Stream kết quả đo (khoảng cách + độ mở từng mắt), null = hiện không
  /// thấy khuôn mặt rõ ràng (quá tối, ra khỏi khung hình, camera chưa sẵn
  /// sàng...).
  Stream<FaceMeasurement?> get distanceStream => _distanceController.stream;

  bool get isRunning => _controller != null && (_controller?.value.isStreamingImages ?? false);

  Future<bool> isCameraAvailable() async {
    try {
      final cameras = await availableCameras();
      return cameras.any((c) => c.lensDirection == CameraLensDirection.front);
    } catch (_) {
      return false;
    }
  }

  Future<bool> start() async {
    if (isRunning) return true;
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        front,
        ResolutionPreset.medium, // đủ lớn để ML Kit nhận diện mặt ổn định (xem ghi chú đầu file)
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await _controller!.initialize();

      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableLandmarks: true,
          // enableClassification: lấy leftEyeOpenProbability /
          // rightEyeOpenProbability — dùng cho việc kiểm tra "mắt còn lại
          // có đang nhắm/che đúng không" trong bài đo thị lực từng mắt.
          enableClassification: true,
          performanceMode: FaceDetectorMode.accurate,
        ),
      );

      _disposed = false;
      await _controller!.startImageStream(_onFrame);
      return true;
    } catch (_) {
      await stop();
      return false;
    }
  }

  Future<void> stop() async {
    _disposed = true;
    try {
      if (_controller?.value.isStreamingImages ?? false) {
        await _controller?.stopImageStream();
      }
    } catch (_) {}
    await _controller?.dispose();
    _controller = null;
    await _faceDetector?.close();
    _faceDetector = null;
  }

  void _onFrame(CameraImage image) async {
    if (_busy || _disposed || _faceDetector == null || _controller == null) return;
    _busy = true;
    try {
      final inputImage = _toInputImage(image, _controller!.description);
      if (inputImage == null) {
        _distanceController.add(null);
        return;
      }
      final faces = await _faceDetector!.processImage(inputImage);
      if (faces.isEmpty) {
        _distanceController.add(null);
        return;
      }
      final face = faces.first;
      final imageWidthPx = image.width.toDouble();
      final fovRad = _kAssumedHorizontalFovDegrees * math.pi / 180;
      final focalLengthPx = (imageWidthPx / 2) / math.tan(fovRad / 2);

      final leftEye = face.landmarks[FaceLandmarkType.leftEye];
      final rightEye = face.landmarks[FaceLandmarkType.rightEye];

      double? distanceCm;
      if (leftEye != null && rightEye != null) {
        // Cách chính, chính xác hơn: dựa trên khoảng cách 2 mắt.
        final dx = (leftEye.position.x - rightEye.position.x).toDouble();
        final dy = (leftEye.position.y - rightEye.position.y).toDouble();
        final eyeDistancePx = math.sqrt(dx * dx + dy * dy);
        if (eyeDistancePx >= 1) {
          distanceCm = (_kInterpupillaryDistanceCm * focalLengthPx) / eyeDistancePx;
        }
      }
      if (distanceCm == null) {
        // Dự phòng: đã thấy khuôn mặt (bounding box) nhưng thiếu landmark
        // mắt -> ước lượng bằng độ rộng khuôn mặt thay vì báo "không thấy".
        final faceWidthPx = face.boundingBox.width;
        if (faceWidthPx >= 1) {
          distanceCm = (_kAverageFaceWidthCm * focalLengthPx) / faceWidthPx;
        }
      }

      if (distanceCm == null) {
        _distanceController.add(null);
        return;
      }
      // Giới hạn khoảng hợp lý (10cm-150cm) — ngoài khoảng này gần như chắc
      // chắn là nhiễu/đo sai.
      if (distanceCm < 10 || distanceCm > 150) {
        _distanceController.add(null);
        return;
      }
      // ĐẢO NGƯỢC CÓ CHỦ ĐÍCH: ML Kit trả left/rightEyeOpenProbability theo
      // giải phẫu khuôn mặt trên buffer ảnh GỐC của camera trước (chưa lật
      // gương), trong khi preview hiển thị cho người dùng lại bị lật gương.
      // Lời nhắc "che mắt trái/phải" trong UI nói theo góc nhìn soi gương nên
      // phải đảo 2 giá trị cho khớp.
      _distanceController.add(FaceMeasurement(
        distanceCm: distanceCm,
        leftEyeOpenProbability: face.rightEyeOpenProbability,
        rightEyeOpenProbability: face.leftEyeOpenProbability,
      ));
    } catch (_) {
      _distanceController.add(null);
    } finally {
      _busy = false;
    }
  }

  InputImage? _toInputImage(CameraImage image, CameraDescription description) {
    try {
      final rotation = InputImageRotationValue.fromRawValue(description.sensorOrientation) ??
          InputImageRotation.rotation0deg;

      // NV21 (Android) chỉ có 1 plane khi dùng imageFormatGroup: nv21.
      final plane = image.planes.first;
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    } catch (_) {
      return null;
    }
  }
}