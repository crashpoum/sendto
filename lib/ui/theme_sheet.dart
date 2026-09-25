import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

IconData themeIconFor(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.system:
      return Icons.contrast;
    case AppThemeMode.light:
      return Icons.light_mode_outlined;
    case AppThemeMode.dark:
      return Icons.dark_mode_outlined;
    case AppThemeMode.oled:
      return Icons.circle;
  }
}

Future<void> showThemeSheet(BuildContext context, ThemeController themes) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: Theme.of(sheetContext).dividerColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Text('Theme', style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 16),
              for (final mode in AppThemeMode.values)
                _ThemeRow(
                  label: _label(mode),
                  icon: themeIconFor(mode),
                  selected: themes.mode == mode,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    themes.setMode(mode);
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

String _label(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.system:
      return 'System';
    case AppThemeMode.light:
      return 'Light';
    case AppThemeMode.dark:
      return 'Dark';
    case AppThemeMode.oled:
      return 'OLED';
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.titleMedium),
            ),
            if (selected) const Icon(Icons.check, size: 20),
          ],
        ),
      ),
    );
  }
}
