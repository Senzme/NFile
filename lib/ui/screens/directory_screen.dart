import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:open_filex/open_filex.dart';
import '../../providers/file_manager_provider.dart';
import '../widgets/file_item.dart';
import '../widgets/folder_item.dart';
import '../widgets/file_action_dialogs.dart';
import '../../core/icon_fonts/broken_icons.dart';

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FileManagerProvider>().init();
    });
  }

  void _handleAction(BuildContext context, String action, String path) async {
    final provider = context.read<FileManagerProvider>();
    switch (action) {
      case 'copy':
        provider.copyFile(path);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
        break;
      case 'cut':
        provider.cutFile(path);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cut to clipboard')));
        break;
      case 'rename':
        final currentName = path.split('/').last;
        final newName = await FileActionDialogs.showTextInputDialog(
          context,
          title: 'Rename',
          hint: 'Enter new name',
          initialValue: currentName,
          actionText: 'Rename',
        );
        if (newName != null && newName.isNotEmpty) {
          await provider.renameFile(path, newName);
        }
        break;
      case 'delete':
        final confirm = await FileActionDialogs.showConfirmDialog(
          context,
          title: 'Delete File',
          content: 'Are you sure you want to delete this item? This cannot be undone.',
        );
        if (confirm) {
          await provider.deleteFile(path);
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FileManagerProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Files'),
            leading: IconButton(
              icon: const Icon(Broken.arrow_left),
              onPressed: () => provider.goBack(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Broken.search_normal),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Search not implemented yet')));
                },
              ),
              IconButton(
                icon: const Icon(Broken.note_add),
                onPressed: () async {
                  final fileName = await FileActionDialogs.showTextInputDialog(
                    context,
                    title: 'New File',
                    hint: 'File name',
                    actionText: 'Create',
                  );
                  if (fileName != null && fileName.isNotEmpty) {
                    await provider.createFile(fileName);
                  }
                },
              ),
              IconButton(
                icon: const Icon(Broken.folder_add),
                onPressed: () async {
                  final folderName = await FileActionDialogs.showTextInputDialog(
                    context,
                    title: 'New Folder',
                    hint: 'Folder name',
                    actionText: 'Create',
                  );
                  if (folderName != null && folderName.isNotEmpty) {
                    await provider.createFolder(folderName);
                  }
                },
              ),
            ],
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  slivers: [
                    CupertinoSliverRefreshControl(
                      onRefresh: () => provider.loadDirectory(provider.currentPath),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.only(bottom: 80),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = provider.currentFiles[index];
                            if (item.isDirectory) {
                              return FolderItem(
                                folder: item,
                                onTap: () => provider.loadDirectory(item.path),
                                onAction: (action) => _handleAction(context, action, item.path),
                              );
                            } else {
                              return FileItem(
                                file: item,
                                onTap: () => provider.openFile(context, item.path),
                                onAction: (action) => _handleAction(context, action, item.path),
                              );
                            }
                          },
                          childCount: provider.currentFiles.length,
                        ),
                      ),
                    ),
                  ],
                ),
          floatingActionButton: provider.hasClipboard
              ? FloatingActionButton.extended(
                  onPressed: () async {
                    await provider.pasteFile();
                    if(context.mounted){
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pasted successfully')));
                    }
                  },
                  icon: const Icon(Broken.clipboard),
                  label: const Text('Paste Here'),
                )
              : null,
        );
      },
    );
  }
}
