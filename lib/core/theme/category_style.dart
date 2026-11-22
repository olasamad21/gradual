import 'package:flutter/material.dart';

import 'app_colors.dart';

/// An icon that suggests a content category, such as a database drum for
/// "databases". Unknown categories get a neutral label icon.
IconData categoryIcon(String category) {
  switch (category.trim().toLowerCase()) {
    case 'databases':
    case 'data':
      return Icons.storage_rounded;
    case 'concurrency':
    case 'synchronization':
      return Icons.sync_alt_rounded;
    case 'async':
      return Icons.bolt_rounded;
    case 'operating-systems':
      return Icons.memory_rounded;
    case 'web':
    case 'networking':
      return Icons.public_rounded;
    case 'security':
      return Icons.shield_rounded;
    case 'backend':
      return Icons.dns_rounded;
    case 'performance':
      return Icons.speed_rounded;
    case 'infrastructure':
      return Icons.cloud_rounded;
    case 'pitfalls':
      return Icons.warning_amber_rounded;
    case 'patterns':
    case 'design-patterns':
      return Icons.widgets_rounded;
    case 'algorithms':
      return Icons.route_rounded;
    case 'data-structures':
      return Icons.account_tree_rounded;
    case 'oop':
    case 'solid':
      return Icons.category_rounded;
    case 'version-control':
      return Icons.call_split_rounded;
    case 'collaboration':
      return Icons.groups_rounded;
    case 'testing':
      return Icons.science_rounded;
    case 'devops':
      return Icons.rocket_launch_rounded;
    case 'code-quality':
      return Icons.auto_fix_high_rounded;
    default:
      return Icons.label_rounded;
  }
}

/// A stable accent colour per category, so the same topic always looks the
/// same across screens.
Color categoryColor(AppColors c, String category) {
  final palette = [c.info, c.accentPurple, c.success, c.caution, c.wordAccents[2], c.warningStrong, c.dangerStrong];
  final key = category.trim().toLowerCase();
  var hash = 0;
  for (final unit in key.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return palette[hash % palette.length];
}
