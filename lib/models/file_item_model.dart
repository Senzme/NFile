import 'dart:io';

class FileItemModel {
  final FileSystemEntity entity;
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime modified;

  FileItemModel({
    required this.entity,
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.modified,
  });

  factory FileItemModel.fromEntity(FileSystemEntity entity) {
    final stat = entity.statSync();
    return FileItemModel(
      entity: entity,
      name: entity.path.split(Platform.pathSeparator).last,
      path: entity.path,
      isDirectory: entity is Directory,
      size: stat.size,
      modified: stat.modified,
    );
  }

  bool get isHidden => name.startsWith('.') && name != '.' && name != '..';
}
