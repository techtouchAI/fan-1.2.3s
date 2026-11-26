import 'package:flutter/material.dart';

import '../../../core/theme/dimens.dart';
import '../../../core/utils/arabic_text.dart';
import '../../../domain/models/exam_paper.dart';
import '../../state/exam_composer_state.dart';
import 'exam_panel_parts.dart';

/// Editor for flexible teacher-authored questions (definitions, blanks,
/// reasoning, comparisons, and branching أ/ب questions).
class ExamFreeQuestionsPanel extends StatelessWidget {
  const ExamFreeQuestionsPanel({super.key, required this.state});

  final ExamComposerState state;

  @override
  Widget build(BuildContext context) {
    final questions = state.freeQuestions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ExamPanelCard(
          title: 'أسئلة حرة وتفريعات (أ / ب)',
          subtitle:
              'أضف أسئلة تعاريف أو فراغات أو تعليل أو مقارنة أو سؤالاً مقسماً '
              'إلى فرعين (أ / ب) مع خيار الترك.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  ActionChip(
                    key: const ValueKey<String>('add-template-definitions'),
                    avatar: const Icon(Icons.menu_book_outlined, size: 16),
                    label: const Text('تعاريف'),
                    onPressed: () => state.addTemplateFreeQuestion('definitions'),
                  ),
                  ActionChip(
                    key: const ValueKey<String>('add-template-blanks'),
                    avatar: const Icon(Icons.short_text_outlined, size: 16),
                    label: const Text('فراغات'),
                    onPressed: () => state.addTemplateFreeQuestion('blanks'),
                  ),
                  ActionChip(
                    key: const ValueKey<String>('add-template-reasons'),
                    avatar: const Icon(Icons.help_outline, size: 16),
                    label: const Text('تعليل'),
                    onPressed: () => state.addTemplateFreeQuestion('reasons'),
                  ),
                  ActionChip(
                    key: const ValueKey<String>('add-template-compare'),
                    avatar: const Icon(Icons.compare_arrows_outlined, size: 16),
                    label: const Text('مقارنة'),
                    onPressed: () => state.addTemplateFreeQuestion('compare'),
                  ),
                  ActionChip(
                    key: const ValueKey<String>('add-template-branches'),
                    avatar: const Icon(Icons.call_split_outlined, size: 16),
                    label: const Text('فرعان (أ / ب)'),
                    onPressed: () => state.addTemplateFreeQuestion('branches'),
                  ),
                  FilledButton.tonalIcon(
                    key: const ValueKey<String>('add-free-question'),
                    onPressed: () => state.addFreeQuestion(
                      title: 'أجب عما يأتي :',
                      items: const <String>[''],
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('سؤال حر فارغ'),
                  ),
                ],
              ),
            ],
          ),
        ),
        for (var i = 0; i < questions.length; i++) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          _FreeQuestionCard(
            key: ValueKey<String>('free-question-card-${questions[i].id}'),
            question: questions[i],
            index: i,
            totalCount: questions.length,
            onChanged: (ExamFreeQuestion updated) =>
                state.updateFreeQuestion(i, updated),
            onRemove: () => state.removeFreeQuestion(i),
            onMoveUp: i > 0 ? () => state.moveFreeQuestion(i, i - 1) : null,
            onMoveDown: i + 1 < questions.length
                ? () => state.moveFreeQuestion(i, i + 1)
                : null,
          ),
        ],
      ],
    );
  }
}

class _FreeQuestionCard extends StatelessWidget {
  const _FreeQuestionCard({
    super.key,
    required this.question,
    required this.index,
    required this.totalCount,
    required this.onChanged,
    required this.onRemove,
    this.onMoveUp,
    this.onMoveDown,
  });

  final ExamFreeQuestion question;
  final int index;
  final int totalCount;
  final ValueChanged<ExamFreeQuestion> onChanged;
  final VoidCallback onRemove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExamPanelCard(
      title: 'سؤال حر ${toArabicDigits('${index + 1}')}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.end,
            children: <Widget>[
              if (onMoveUp != null)
                IconButton(
                  tooltip: 'تحريك للأعلى',
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  onPressed: onMoveUp,
                ),
              if (onMoveDown != null)
                IconButton(
                  tooltip: 'تحريك للأسفل',
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  onPressed: onMoveDown,
                ),
              IconButton(
                key: ValueKey<String>('delete-free-question-${question.id}'),
                tooltip: 'حذف السؤال الحر',
                icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                onPressed: onRemove,
              ),
            ],
          ),
          TextFormField(
            key: ValueKey<String>('free-title-${question.id}'),
            initialValue: question.title,
            decoration: const InputDecoration(
              labelText: 'منطوق السؤال الرئيس',
              hintText: 'مثال: عرف ما يأتي : / أجب عن أحد الفرعين :',
              border: OutlineInputBorder(),
            ),
            onChanged: (String v) => onChanged(question.copyWith(title: v)),
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final noteField = TextFormField(
                key: ValueKey<String>('free-note-${question.id}'),
                initialValue: question.choiceNote,
                decoration: const InputDecoration(
                  labelText: 'قاعدة الاختيار / الترك (اختياري)',
                  hintText: 'لثلاث فقط / ترك فرع واحد',
                  border: OutlineInputBorder(),
                ),
                onChanged: (String v) =>
                    onChanged(question.copyWith(choiceNote: v)),
              );
              final degField = TextFormField(
                key: ValueKey<String>('free-degree-${question.id}'),
                initialValue: '${question.degree}',
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'الدرجة',
                  border: OutlineInputBorder(),
                ),
                onChanged: (String v) => onChanged(
                  question.copyWith(degree: parseIntegerDigits(v) ?? 0),
                ),
              );
              if (constraints.maxWidth >= 480) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(flex: 3, child: noteField),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(flex: 1, child: degField),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  noteField,
                  const SizedBox(height: AppSpacing.sm),
                  degField,
                ],
              );
            },
          ),
          if (question.items.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text('الفقرات الفرعية', style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            for (var itemIdx = 0; itemIdx < question.items.length; itemIdx++) ...<Widget>[
              if (itemIdx > 0) const SizedBox(height: AppSpacing.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      key: ValueKey<String>('free-item-${question.id}-$itemIdx'),
                      initialValue: question.items[itemIdx],
                      decoration: InputDecoration(
                        labelText: 'فقرة ${toArabicDigits('${itemIdx + 1}')}',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (String v) {
                        final next = List<String>.of(question.items);
                        next[itemIdx] = v;
                        onChanged(question.copyWith(items: next));
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'إزالة الفقرة',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      final next = List<String>.of(question.items)
                        ..removeAt(itemIdx);
                      onChanged(question.copyWith(items: next));
                    },
                  ),
                ],
              ),
            ],
          ],
          if (question.branches.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            for (var bIdx = 0; bIdx < question.branches.length; bIdx++) ...<Widget>[
              if (bIdx > 0) const SizedBox(height: AppSpacing.sm),
              _BranchEditor(
                questionId: question.id,
                branchIndex: bIdx,
                branch: question.branches[bIdx],
                onChanged: (ExamQuestionBranch updated) {
                  final next = List<ExamQuestionBranch>.of(question.branches);
                  next[bIdx] = updated;
                  onChanged(question.copyWith(branches: next));
                },
                onRemove: () {
                  final next = List<ExamQuestionBranch>.of(question.branches)
                    ..removeAt(bIdx);
                  onChanged(question.copyWith(branches: next));
                },
              ),
            ],
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              TextButton.icon(
                key: ValueKey<String>('free-add-item-${question.id}'),
                onPressed: () => onChanged(
                  question.copyWith(items: <String>[...question.items, '']),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('إضافة فقرة'),
              ),
              if (question.branches.length < 4)
                TextButton.icon(
                  key: ValueKey<String>('free-add-branch-${question.id}'),
                  onPressed: () {
                    final labels = ExamQuestionBranch.arabicBranchLabels;
                    final nextLabel =
                        labels[question.branches.length % labels.length];
                    onChanged(
                      question.copyWith(
                        branches: <ExamQuestionBranch>[
                          ...question.branches,
                          ExamQuestionBranch(
                            label: nextLabel,
                            prompt: '',
                            items: const <String>[''],
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.call_split, size: 18),
                  label: const Text('إضافة فرع (أ / ب)'),
                ),
              ChoiceChip(
                key: ValueKey<String>('free-lines-toggle-${question.id}'),
                label: Text(
                  question.answerLineCount > 0
                      ? 'أسطر إجابة: ${toArabicDigits('${question.answerLineCount}')}'
                      : 'إضافة أسطر إجابة منقطة',
                ),
                selected: question.answerLineCount > 0,
                onSelected: (_) => onChanged(
                  question.copyWith(
                    answerLineCount: question.answerLineCount > 0 ? 0 : 2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BranchEditor extends StatelessWidget {
  const _BranchEditor({
    required this.questionId,
    required this.branchIndex,
    required this.branch,
    required this.onChanged,
    required this.onRemove,
  });

  final String questionId;
  final int branchIndex;
  final ExamQuestionBranch branch;
  final ValueChanged<ExamQuestionBranch> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'فرع (${branch.label})',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              IconButton(
                tooltip: 'حذف الفرع',
                icon: const Icon(Icons.close, size: 18),
                onPressed: onRemove,
              ),
            ],
          ),
          TextFormField(
            key: ValueKey<String>('branch-prompt-$questionId-$branchIndex'),
            initialValue: branch.prompt,
            decoration: const InputDecoration(
              labelText: 'عنوان الفرع',
              hintText: 'مثال: عرف ما يأتي / عدد ما يأتي',
              border: OutlineInputBorder(),
            ),
            onChanged: (String v) => onChanged(branch.copyWith(prompt: v)),
          ),
          for (var i = 0; i < branch.items.length; i++) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    key: ValueKey<String>(
                      'branch-item-$questionId-$branchIndex-$i',
                    ),
                    initialValue: branch.items[i],
                    decoration: InputDecoration(
                      labelText: 'نقطة ${toArabicDigits('${i + 1}')}',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (String v) {
                      final next = List<String>.of(branch.items);
                      next[i] = v;
                      onChanged(branch.copyWith(items: next));
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'حذف النقطة',
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  onPressed: () {
                    final next = List<String>.of(branch.items)..removeAt(i);
                    onChanged(branch.copyWith(items: next));
                  },
                ),
              ],
            ),
          ],
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: ValueKey<String>('branch-add-item-$questionId-$branchIndex'),
              onPressed: () => onChanged(
                branch.copyWith(items: <String>[...branch.items, '']),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('إضافة نقطة للفرع'),
            ),
          ),
        ],
      ),
    );
  }
}
