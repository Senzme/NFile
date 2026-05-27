class AppInfoModel {
  final String name;
  final String packageName;
  final String version;
  final int apkSize;
  final bool isSystem;
  final DateTime installTime;

  AppInfoModel({
    required this.name,
    required this.packageName,
    required this.version,
    required this.apkSize,
    required this.isSystem,
    required this.installTime,
  });

  factory AppInfoModel.fromMap(Map<dynamic, dynamic> map) {
    return AppInfoModel(
      name: map['name'] ?? '',
      packageName: map['packageName'] ?? '',
      version: map['version'] ?? '',
      apkSize: map['apkSize'] as int? ?? 0,
      isSystem: map['isSystem'] as bool? ?? false,
      installTime: DateTime.fromMillisecondsSinceEpoch(map['installTime'] as int? ?? 0),
    );
  }
}
