import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import '../../core/widgets/app_page.dart';
import '../navigation/app_routes.dart';
import '../state/app_state.dart';
import '../widgets/text_scale_controls.dart';
import '../widgets/topic_card.dart';
import '../widgets/topic_drawing_card.dart';
import '../widgets/unit_question_card.dart';

/// A precise search destination. Identifiers remain scoped to the owning unit;
/// this screen never guesses an answer or substitutes another topic on failure.
class CurriculumResultScreen extends StatelessWidget {
  const CurriculumResultScreen({super.key, required this.unitId, this.topicId, this.questionId});
  final String unitId;
  final String? topicId;
  final String? questionId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final unit = state.library.unitById(unitId);
    final topic = unit?.topics.where((t) => t.id == topicId).firstOrNull;
    final question = unit?.questions.where((q) => q.id == questionId).firstOrNull;
    if (unit == null ||
        (!unit.isStandalone && unit.sectionId != state.gradeId) ||
        (topic == null && question == null)) {
      return Scaffold(
        appBar: AppBar(title: const Text('نتيجة البحث')),
        body: const Center(child: Text('لم تعد هذه النتيجة متاحة ضمن الصف الحالي.')),
      );
    }
    final accent = AppColors.fromAccent(
      unit.accent,
      Theme.of(context).brightness == Brightness.dark,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(question != null ? 'سؤال من المنهج' : 'موضوع من المنهج'),
        actions: const <Widget>[TextScaleControls()],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        children: <Widget>[
          AppPage(
            maxWidth: AppLayout.readingMaxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(unit.displayTitle, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                if (topic != null) ...<Widget>[
                  TopicDrawings(
                    drawings: state
                        .drawingsOfUnit(unitId)
                        .where((d) => d.topicId == topic.id)
                        .toList(),
                    accent: accent,
                  ),
                  TopicCard(topic: topic, accent: accent),
                ],
                if (question != null) UnitQuestionCard(question: question, initiallyExpanded: true),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton.icon(
                  onPressed: () => AppRoutes.openUnit(context, unit),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('فتح الوحدة كاملةً'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
