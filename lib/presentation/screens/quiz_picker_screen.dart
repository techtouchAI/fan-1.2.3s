import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import '../../core/utils/arabic_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/section_header.dart';
import '../../domain/models/library.dart';
import '../../domain/models/exam_paper.dart';
import '../state/app_state.dart';
import '../widgets/text_scale_controls.dart';
import '../navigation/app_routes.dart';

class QuizPickerScreen extends StatefulWidget {
  const QuizPickerScreen({super.key});

  @override
  State<QuizPickerScreen> createState() => _QuizPickerScreenState();
}

class _QuizPickerScreenState extends State<QuizPickerScreen> {
  String _selectedUnitId = 'all';
  String _selectedExamStyle = 'all';
  List<_QuizEntry>? _activeSession;
  int _currentIndex = 0;
  int _correctCount = 0;
  bool _answeredCurrent = false;
  bool _lastCorrect = false;
  int? _pickedIndex;

  void _startQuiz(AppState state) {
    final rng = Random();
    final units = _selectedUnitId == 'all'
        ? state.visibleUnits
        : state.visibleUnits.where((u) => u.id == _selectedUnitId).toList();
    final pool = <_QuizEntry>[];
    for (final u in units) {
      for (final q in u.questions) {
        if (_selectedExamStyle != 'all' && q.kind.name != _selectedExamStyle) {
          continue;
        }
        if (q.isGradable) {
          pool.add(_QuizEntry.fromQuestion(unitTitle: u.displayTitle, question: q, rng: rng));
        }
      }
    }
    pool.shuffle(rng);
    final selected = pool.take(10).toList(growable: false);
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد أسئلة مطابقة لهذا النمط في النطاق المحدد.')),
      );
      return;
    }
    setState(() {
      _activeSession = selected;
      _currentIndex = 0;
      _correctCount = 0;
      _answeredCurrent = false;
      _pickedIndex = null;
    });
  }

  void _submitAnswer(int index, bool isCorrect) {
    if (_answeredCurrent) {
      return;
    }
    setState(() {
      _answeredCurrent = true;
      _pickedIndex = index;
      _lastCorrect = isCorrect;
      if (isCorrect) {
        _correctCount++;
      }
    });
  }

  void _nextQuestion(AppState state) {
    final session = _activeSession!;
    if (_currentIndex + 1 >= session.length) {
      final unitLabel = _selectedUnitId == 'all'
          ? state.gradeTitle
          : (state.library.unitById(_selectedUnitId)?.displayTitle ?? state.gradeTitle);
      final styleSuffix = _selectedExamStyle == 'all'
          ? ''
          : ' • ${theoryKindLabel(QuestionKind.values.firstWhere((kind) => kind.name == _selectedExamStyle))}';
      state.recordInteractiveQuiz(
        scopeLabel: '$unitLabel$styleSuffix',
        correct: _correctCount,
        total: session.length,
      );
      setState(() {
        _activeSession = null;
        _pickedIndex = null;
      });
      return;
    }
    setState(() {
      _currentIndex++;
      _answeredCurrent = false;
      _pickedIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final units = state.visibleUnits;
    if (_selectedUnitId != 'all' && !units.any((u) => u.id == _selectedUnitId)) {
      _selectedUnitId = 'all';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('الاختبار التفاعلي — ${state.gradeTitle}'),
        actions: const <Widget>[TextScaleControls()],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: <Widget>[
          AppPage(
            maxWidth: AppLayout.readingMaxWidth,
            child: _activeSession == null
                ? _buildLobby(context, state, units, theme, scheme)
                : _buildActiveQuiz(context, state, theme, scheme),
          ),
        ],
      ),
    );
  }

  Widget _buildLobby(
    BuildContext context,
    AppState state,
    List<LearningUnit> units,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    final history = state.progress.quizHistory
        .where((result) => result.gradeId == state.gradeId)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'اختبر إتقانك بأنماط الأسئلة الوزارية الرسمية مع التصحيح الفوري والشرح النموذجي',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                key: const ValueKey<String>('quiz-unit-filter'),
                initialValue: _selectedUnitId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'نطاق الاختبار'),
                items: <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: 'all',
                    child: Text('شامل لجميع وحدات ${state.gradeTitle}'),
                  ),
                  for (final u in units)
                    DropdownMenuItem<String>(value: u.id, child: Text(u.displayTitle)),
                ],
                onChanged: (String? v) {
                  if (v != null) {
                    setState(() => _selectedUnitId = v);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.md),
              Text('نمط السؤال الرسمي:', style: theme.textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  ChoiceChip(
                    key: const ValueKey<String>('quiz-style-all'),
                    label: const Text('جميع الأنماط'),
                    selected: _selectedExamStyle == 'all',
                    onSelected: (_) => setState(() => _selectedExamStyle = 'all'),
                  ),
                  for (final style
                      in QuestionKind.values
                          .where((kind) => kind != QuestionKind.open)
                          .map((kind) => kind.name))
                    ChoiceChip(
                      key: ValueKey<String>('quiz-style-$style'),
                      label: Text(
                        theoryKindLabel(
                          QuestionKind.values.firstWhere((kind) => kind.name == style),
                        ),
                      ),
                      selected: _selectedExamStyle == style,
                      onSelected: (_) => setState(() => _selectedExamStyle = style),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                key: const ValueKey<String>('start-quiz-button'),
                onPressed: () => _startQuiz(state),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('بدء جولة الاختبار'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(
          title: 'مراجعة جميع أسئلة الوحدة',
          subtitle: 'يشمل أسئلة التعداد وإجاباتها الموثقة، بترتيب المنهج الأصلي.',
        ),
        for (final unit in units.where((unit) => unit.questions.isNotEmpty))
          Card(
            child: ListTile(
              title: Text(unit.title),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => AppRoutes.openQuiz(context, unit),
            ),
          ),
        if (history.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(title: 'سجل نتائجك السابقة', accent: scheme.secondary),
          for (final score in history)
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${toArabicDigits('${score.correct}')}/${toArabicDigits('${score.total}')}',
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                  ),
                ),
                title: Text(score.scopeLabel),
                subtitle: Text(
                  'نسبة الإتقان: ${toArabicDigits('${((score.correct / score.total) * 100).round()}')}٪',
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildActiveQuiz(
    BuildContext context,
    AppState state,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    final session = _activeSession!;
    final entry = session[_currentIndex];
    final q = entry.question;
    final okColor = AppColors.resolveAccent('green', theme.brightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'السؤال ${toArabicDigits('${_currentIndex + 1}')} من ${toArabicDigits('${session.length}')}',
                style: theme.textTheme.labelLarge,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _activeSession = null),
              child: const Text('إنهاء الجولة'),
            ),
          ],
        ),
        LinearProgressIndicator(
          value: (_currentIndex + 1) / session.length,
          borderRadius: BorderRadius.circular(6),
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(entry.unitTitle, style: theme.textTheme.labelMedium),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      theoryKindLabel(q.kind),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(q.prompt, style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              for (var i = 0; i < entry.options.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    key: ValueKey<String>('quiz-option-$i'),
                    style: OutlinedButton.styleFrom(
                      alignment: AlignmentDirectional.centerStart,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      backgroundColor: _answeredCurrent && i == entry.correctIndex
                          ? okColor.withValues(alpha: 0.14)
                          : (_answeredCurrent && _pickedIndex == i && i != entry.correctIndex)
                          ? scheme.error.withValues(alpha: 0.12)
                          : null,
                    ),
                    onPressed: _answeredCurrent
                        ? null
                        : () => _submitAnswer(i, i == entry.correctIndex),
                    child: Text(entry.options[i]),
                  ),
                ),
              if (_answeredCurrent) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: (_lastCorrect ? okColor : scheme.error).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _lastCorrect ? 'إجابة صحيحة! أحسنت.' : 'الجواب النموذجي الصحيح:',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: _lastCorrect ? okColor : scheme.error,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(q.answerText, style: theme.textTheme.bodyMedium),
                      if (q.kind == QuestionKind.choice &&
                          q.answerSupport != null &&
                          q.answerSupport!.trim().isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text('الشاهد: ${q.answerSupport}', style: theme.textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  key: const ValueKey<String>('quiz-next-button'),
                  onPressed: () => _nextQuestion(state),
                  child: Text(
                    _currentIndex + 1 >= session.length
                        ? 'حفظ النتيجة وإنهاء الاختبار'
                        : 'السؤال التالي',
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _QuizEntry {
  const _QuizEntry({
    required this.unitTitle,
    required this.question,
    required this.options,
    required this.correctIndex,
  });

  factory _QuizEntry.fromQuestion({
    required String unitTitle,
    required Question question,
    required Random rng,
  }) {
    final baseOptions = question.kind == QuestionKind.trueFalse
        ? const <String>['صح', 'خطأ']
        : question.options;
    final baseCorrect = question.kind == QuestionKind.trueFalse
        ? (question.boolAnswer == true ? 0 : 1)
        : question.answerIndex!;
    final indices = List<int>.generate(baseOptions.length, (i) => i)..shuffle(rng);
    final shuffled = <String>[for (final idx in indices) baseOptions[idx]];
    final newCorrect = indices.indexOf(baseCorrect);
    return _QuizEntry(
      unitTitle: unitTitle,
      question: question,
      options: shuffled,
      correctIndex: newCorrect < 0 ? 0 : newCorrect,
    );
  }

  final String unitTitle;
  final Question question;
  final List<String> options;
  final int correctIndex;
}
