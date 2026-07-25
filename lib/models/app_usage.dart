class AppUsage {
  final String packageName;
  final String appName;
  final Duration totalTime;
  final String? appIcon;

  AppUsage({
    required this.packageName,
    required this.appName,
    required this.totalTime,
    this.appIcon,
  });

  double get percentage => 0.0;

  String get formattedTime {
    final hours = totalTime.inHours;
    final minutes = totalTime.inMinutes.remainder(60);
    if (hours > 0) {
      return '$hours giờ $minutes phút';
    }
    return '$minutes phút';
  }

  factory AppUsage.fromJson(Map<String, dynamic> json) {
    return AppUsage(
      packageName: json['packageName'] ?? '',
      appName: json['appName'] ?? '',
      totalTime: Duration(
        milliseconds: (json['totalTime'] as num?)?.toInt() ?? 0,
      ),
      appIcon: json['appIcon'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'packageName': packageName,
      'appName': appName,
      'totalTime': totalTime.inSeconds,
      'appIcon': appIcon,
    };
  }
  
}