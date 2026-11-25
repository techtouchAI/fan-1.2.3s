import 'package:flutter/material.dart';

import '../../core/theme/dimens.dart';
import '../../core/utils/arabic_text.dart';
import '../../domain/models/library.dart';

/// One source-backed question, shared by the unit reader and search details.
/// Missing answers remain missing: they are never inferred from null values.
class UnitQuestionCard extends StatelessWidget {
  const UnitQuestionCard({
    super.key,
    required this.question,
    this.number,
    this.initiallyExpanded = false,
  });
  final Question question;
  final int? number;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final answer = question.documentedAnswerText;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ExpansionTile(
        key: ValueKey<String>('unit-question-${question.id}'),
        initiallyExpanded: initiallyExpanded,
        title: Text(
          number == null ? question.prompt : '${toArabicDigits('$number')} • ${question.prompt}',
        ),
        subtitle: question.options.isEmpty ? null : Text(question.options.join(' / ')),
        childrenPadding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(answer.isEmpty ? 'الإجابة غير متوفرة في المصدر' : answer),
          ),
          if (question.answerSupport?.trim().isNotEmpty == true)
            Text('الشاهد / التصحيح: ${question.answerSupport}'),
        ],
      ),
    );
  }
}
