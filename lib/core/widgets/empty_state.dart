import 'package:flutter/material.dart';

import '../theme/dimens.dart';

/// Neutral placeholder for empty lists and empty searches.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: scheme.primary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            if (message != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
