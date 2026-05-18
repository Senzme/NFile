class CustomShortcutModel {
  final String id;
  final String label;
  final String path;
  final bool isDirectory;

  CustomShortcutModel({
    required this.id,
    required this.label,
    required this.path,
    required this.isDirectory,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'path': path,
    'isDirectory': isDirectory,
  };

  factory CustomShortcutModel.fromJson(Map<String, dynamic> json) => CustomShortcutModel(
    id: json['id'] as String,
    label: json['label'] as String,
    path: json['path'] as String,
    isDirectory: json['isDirectory'] as bool? ?? true,
  );
}
