import 'package:flutter/material.dart';

import '../theme/dimens.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.accent,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Color? accent;
  final Widget? trailing;

  /// Largest share of the row width the [trailing] action may take.
  static const double maxTrailingFraction = 0.45;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barColor = accent ?? theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 5,
                height: subtitle == null ? 24 : 38,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: theme.textTheme.titleLarge),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(subtitle!, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (trailing != null)
                // A long action label (e.g. «استبدال من بنك الإملاء») must not
                // push the row past a narrow phone: cap the action so its
                // (Flexible) button label wraps instead of overflowing.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * maxTrailingFraction,
                  ),
                  child: trailing,
                ),
            ],
          );
        },
      ),
    );
  }
}
