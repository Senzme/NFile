import 'file_item_model.dart';

class FolderTab {
  final String id;
  String currentPath;
  List<FileItemModel> currentFiles;
  bool isLoading;
  bool isRestrictedMode;
  bool needsPermission;
  bool useRootMode;
  bool useShizukuMode;
  bool isRootAvailable;
  final Set<String> selectedPaths;
  double scrollOffset;
  final Map<String, double> scrollPositions;
  bool isPinned;

  FolderTab({
    required this.id,
    required this.currentPath,
    this.currentFiles = const [],
    this.isLoading = false,
    this.isRestrictedMode = false,
    this.needsPermission = false,
    this.useRootMode = false,
    this.useShizukuMode = false,
    this.isRootAvailable = false,
    Set<String>? selectedPaths,
    this.scrollOffset = 0.0,
    Map<String, double>? scrollPositions,
    this.isPinned = false,
  }) : selectedPaths = selectedPaths ?? {},
       scrollPositions = scrollPositions ?? {};
}
