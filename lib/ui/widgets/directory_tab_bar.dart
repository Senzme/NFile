import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../providers/file_manager_provider.dart';
import '../../core/icon_fonts/broken_icons.dart';
import 'tab_options_sheet.dart';

class DirectoryTabBar extends StatelessWidget implements PreferredSizeWidget {
  final FileManagerProvider provider;
  const DirectoryTabBar({super.key, required this.provider});

  @override
  Size get preferredSize => const Size.fromHeight(50);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tabs = provider.tabs;
    final activeIndex = provider.activeTabIndex;

    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withOpacity(0.08),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: tabs.length,
              itemBuilder: (context, index) {
                final tab = tabs[index];
                final isSelected = index == activeIndex;
                final isRoot = tab.currentPath == provider.rootPath;
                final title = isRoot ? 'Home' : p.basename(tab.currentPath);

                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: isSelected
                        ? theme.colorScheme.primaryContainer.withOpacity(0.8)
                        : theme.colorScheme.surfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => provider.setActiveTab(index),
                      onLongPress: () => TabOptionsSheet.show(context, provider, index),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.primary.withOpacity(0.4)
                                : theme.dividerColor.withOpacity(0.05),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              tab.isPinned
                                  ? Icons.push_pin_rounded
                                  : (isRoot ? Broken.home_1 : Broken.folder),
                              size: 16,
                              color: tab.isPinned
                                  ? Colors.orange
                                  : (isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface.withOpacity(0.6)),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              title.isEmpty ? '/' : title,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface.withOpacity(0.8)),
                            ),
                            if (tabs.length > 1 && !tab.isPinned) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => provider.closeTab(index),
                                child: Icon(
                                  Icons.close,
                                  size: 14,
                                  color: isSelected
                                      ? theme.colorScheme.primary.withOpacity(0.7)
                                      : theme.colorScheme.onSurface.withOpacity(0.4),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            height: 32,
            width: 1,
            color: theme.dividerColor.withOpacity(0.12),
          ),
          IconButton(
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            icon: const Icon(Broken.add, size: 20),
            tooltip: 'New Tab',
            onPressed: () {
              provider.addTab(provider.rootPath);
            },
          ),
          PopupMenuButton<String>(
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            icon: const Icon(Broken.more, size: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            position: PopupMenuPosition.under,
            onSelected: (value) {
              if (value == 'close_others') {
                provider.closeOtherTabs();
              } else if (value == 'duplicate') {
                provider.duplicateActiveTab();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'duplicate',
                child: Row(
                  children: [
                    Icon(Broken.copy, size: 18),
                    SizedBox(width: 10),
                    Text('Duplicate Tab', style: TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'close_others',
                child: Row(
                  children: [
                    Icon(Broken.close_circle, size: 18),
                    SizedBox(width: 10),
                    Text('Close Other Tabs', style: TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
