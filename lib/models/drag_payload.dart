class DragPayload {
  final String path;
  final bool isDirectory;
  final List<String> paths;

  DragPayload({
    required this.path,
    required this.isDirectory,
    required this.paths,
  });
}
