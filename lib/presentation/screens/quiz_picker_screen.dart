import 'package:flutter/material.dart';

import '../../core/theme/dimens.dart';
import '../../core/utils/arabic_text.dart';
import '../../core/widgets/app_page.dart';
import '../navigation/app_routes.dart';
import '../state/app_state.dart';
import '../widgets/text_scale_controls.dart';

/// Entry point only: each unit keeps its existing question order and quiz flow.
class QuizPickerScreen extends StatelessWidget {
  const QuizPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final units = state.visibleUnits.where((unit) => unit.questions.isNotEmpty);
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختبر فهمك'),
        actions: const <Widget>[TextScaleControls()],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: <Widget>[
          AppPage(
            maxWidth: AppLayout.readingMaxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: AppSpacing.md),
                Text(state.gradeTitle, style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.lg),
                for (final unit in units)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(AppSpacing.md),
                        leading: Icon(Icons.quiz_outlined, color: theme.colorScheme.primary),
                        title: Text(unit.title),
                        subtitle: Text('${toArabicDigits('${unit.questions.length}')} سؤالاً'),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () => AppRoutes.openQuiz(context, unit),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
