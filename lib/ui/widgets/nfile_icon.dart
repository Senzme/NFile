import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/file_manager_provider.dart';
import '../../core/utils.dart';

class NfileIcon extends StatelessWidget {
  final IconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  const NfileIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final useMaterial = context.select<FileManagerProvider, bool>((p) => p.useMaterialIcons);
    return Icon(
      FileUtils.getAdaptiveIcon(icon, useMaterial),
      size: size,
      color: color,
      semanticLabel: semanticLabel,
    );
  }
}
