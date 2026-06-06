import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../core/icon_fonts/broken_icons.dart';
import '../../../../models/app_info_model.dart';
import '../../../../services/app_manager_service.dart';
import '../../../../core/utils.dart';

class AppListTab extends StatelessWidget {
  final List<AppInfoModel> apps;
  final Set<String> selectedPackages;
  final Function(String) onToggleSelection;
  final Function(AppInfoModel) onShowOptions;
  final Map<String, Uint8List> iconCache;

  const AppListTab({
    key,
    required this.apps,
    required this.selectedPackages,
    required this.onToggleSelection,
    required this.onShowOptions,
    required this.iconCache,
  }) : super(key: key);

  bool get _isSelectionMode => selectedPackages.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (apps.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Broken.mobile,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No applications found',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        final isSelected = selectedPackages.contains(app.packageName);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withOpacity(0.35)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.dividerColor.withOpacity(0.06),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: InkWell(
            onTap: () {
              if (_isSelectionMode) {
                onToggleSelection(app.packageName);
              } else {
                onShowOptions(app);
              }
            },
            onLongPress: () {
              onToggleSelection(app.packageName);
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  // App Icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _AppIconWidget(
                        packageName: app.packageName,
                        iconCache: iconCache,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${app.packageName} • v${app.version}',
                          style: TextStyle(
                            color: theme.textTheme.bodySmall?.color?.withOpacity(0.55),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        FileUtils.formatBytes(app.apkSize, 1),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 4),
                        Icon(
                          Broken.tick_square,
                          color: theme.colorScheme.primary,
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AppIconWidget extends StatelessWidget {
  final String packageName;
  final Map<String, Uint8List> iconCache;
  final double size;

  const _AppIconWidget({
    required this.packageName,
    required this.iconCache,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    if (iconCache.containsKey(packageName)) {
      return Image.memory(
        iconCache[packageName]!,
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
    }

    return FutureBuilder<Uint8List?>(
      future: AppManagerService.getAppIcon(packageName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
          iconCache[packageName] = snapshot.data!;
          return Image.memory(
            snapshot.data!,
            width: size,
            height: size,
            fit: BoxFit.contain,
          );
        }
        return Icon(Broken.mobile, size: size * 0.8, color: Theme.of(context).colorScheme.primary.withOpacity(0.5));
      },
    );
  }
}
