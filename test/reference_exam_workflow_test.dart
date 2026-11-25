import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirsam/data/local/memory_exam_profile_repository.dart';
import 'package:mirsam/data/local/memory_exam_question_bank_repository.dart';
import 'package:mirsam/data/local/saved_exam_store.dart';
import 'package:mirsam/domain/models/exam_paper.dart';
import 'package:mirsam/domain/models/library.dart';
import 'package:mirsam/domain/models/saved_exam.dart';
import 'package:mirsam/domain/models/progress.dart';
import 'package:mirsam/domain/models/question_print_settings.dart';
import 'package:mirsam/domain/services/exam_paper_formatter.dart';
import 'package:mirsam/domain/services/question_print_plan.dart';
import 'package:mirsam/presentation/screens/exam_composer_screen.dart';
import 'package:mirsam/presentation/screens/quiz_picker_screen.dart';
import 'package:mirsam/presentation/screens/saved_exams_screen.dart';
import 'package:mirsam/presentation/state/exam_composer_state.dart';
import 'package:mirsam/presentation/state/saved_exam_library.dart';
import 'package:mirsam/presentation/widgets/exam/exam_live_preview.dart';

import 'overflow_utils.dart';
import 'test_support.dart';

void main() {
  late Library library;
  ExamComposerState draft() => ExamComposerState(
    units: library.unitsOf('g1'),
    drawings: library.drawings,
    gradeLabel: 'الأول المتوسط',
  );
  setUpAll(() async {
    library = await ensureLibrary();
  });

  test('all draft fields survive save, including incomplete input and local edits', () {
    final state = draft();
    final option = state.options.first;
    state.toggleItem(option.question.kind, option.id);
    state.editItem(
      ExamTheoryItem(
        id: option.id,
        kind: option.question.kind,
        prompt: 'نص محلي',
        options: const <String>['أ', 'ب'],
      ),
    );
    state.setSchoolName('مدرسة الاختبار');
    state.setBodyFontSize(null);
    state.setInstruction(option.question.kind, 'تعليمات مخصصة');
    state.setPracticalPrompt(0, 'ارسم منظراً');
    final saved = state.toDraft();
    final restored = draft()..restoreDraft(saved);
    expect(restored.toDraft(), saved);
    expect(restored.paper, isNull);
    expect(restored.selectedItems(option.question.kind).single.prompt, 'نص محلي');
    expect(option.question.prompt, isNot('نص محلي'));
    state.dispose();
    restored.dispose();
  });

  test('balanced generation respects scope and final document question order', () {
    final state = draft();
    final unit = state.options.first.unitId;
    state.generateBalancedExam(unitIds: <String>{unit}, random: Random(4), perKind: 3);
    for (final kind in ExamTheoryQuestion.kinds) {
      final items = state.selectedItems(kind);
      expect(items.length, lessThanOrEqualTo(3));
      expect(items.every((item) => item.id.startsWith('$unit:')), isTrue);
      expect(
        items.map((item) => item.id),
        state
            .optionsOf(kind)
            .where((option) => state.isSelected(kind, option.id))
            .map((option) => option.id),
      );
    }
    state.dispose();
  });

  test('bank add/replace selection never imports foreign identifiers', () {
    final state = draft();
    final kind = state.options.first.question.kind;
    final options = state.optionsOf(kind);
    state.selectItems(kind, <String>[options.first.id, 'unknown']);
    state.selectItems(kind, <String>[options.last.id]);
    expect(state.selectionOf(kind), containsAll(<String>[options.first.id, options.last.id]));
    state.selectItems(kind, <String>[options.last.id], replace: true);
    expect(state.selectionOf(kind), <String>{options.last.id});
    state.dispose();
  });

  test(
    'saved library creates, revises, duplicates, renames and deletes independent drafts',
    () async {
      final store = MemorySavedExamStore();
      final papers = SavedExamLibrary(store);
      final state = draft();
      final first = papers.save(state.toDraft(), gradeId: 'g1');
      state.setSchoolName('ألف');
      final next = papers.save(state.toDraft(), id: first.id, gradeId: 'g1');
      expect(next.revision, 2);
      expect(papers.save(state.toDraft(), id: first.id, gradeId: 'g1').revision, 2);
      final copy = papers.duplicate(first.id)!;
      papers.rename(copy.id, 'نسخة للصف');
      papers.delete(first.id);
      await papers.flush();
      final restarted = SavedExamLibrary(store);
      expect(restarted.papers.single.displayTitle, 'نسخة للصف');
      expect(restarted.papers.single.draft['schoolName'], 'ألف');
      final mutation = restarted.papers.single.draft..['schoolName'] = 'changed';
      expect(mutation['schoolName'], 'changed');
      expect(restarted.papers.single.draft['schoolName'], 'ألف');
      state.dispose();
      papers.dispose();
      restarted.dispose();
    },
  );

  test('coalesced writes persist the last rapid edit rather than an earlier draft', () async {
    final store = _DelayedStore();
    final papers = SavedExamLibrary(store);
    final state = draft();
    final first = papers.save(state.toDraft(), gradeId: 'g1');
    for (var i = 0; i < 20; i++) {
      state.setSchoolName('$i');
      papers.save(state.toDraft(), id: first.id, gradeId: 'g1');
    }
    store.release.complete();
    await papers.flush();
    expect(store.read().single.draft['schoolName'], '19');
    expect(store.writeCount, 2);
    state.dispose();
    papers.dispose();
  });

  test('a damaged saved record does not erase other papers', () {
    final state = draft();
    final papers = SavedExamLibrary(MemorySavedExamStore());
    final saved = papers.save(state.toDraft(), gradeId: 'g1');
    expect(
      SavedExamStore.decode(
        jsonEncode(<String, dynamic>{
          'papers': <dynamic>[<String, dynamic>{}, saved.toJson()],
        }),
      ).length,
      1,
    );
    state.dispose();
  });

  test('print styles change selection counts without changing source order', () {
    final units = library.unitsOf('g1');
    final plan = QuestionPrintPlan.fromSelection(
      units,
      units.map((unit) => unit.id).toSet(),
      allowedKinds: <QuestionKind>{QuestionKind.choice},
      settings: const QuestionPrintSettings(includeAnswers: false),
    );
    expect(plan.sections.single.kind, QuestionKind.choice);
    expect(
      plan.questionCount,
      units.fold<int>(
        0,
        (sum, unit) => sum + unit.questions.where((q) => q.kind == QuestionKind.choice).length,
      ),
    );
    final question = plan.sections.single.groups.first.questions.first;
    expect(
      formatPrintableQuestion(question, 1, includeAnswers: false),
      isNot(contains('الإجابة:')),
    );
    expect(formatPrintableQuestion(question, 1), contains('الإجابة:'));
  });

  test('interactive quiz history survives restart separately from best unit scores', () {
    final progress = ReadingProgress(gradeId: 'g1');
    final state = buildState(library: library, progress: progress);
    state.recordInteractiveQuiz(scopeLabel: 'شامل', correct: 3, total: 5);
    final restored = ReadingProgress.fromJson(state.progress.toJson());
    expect(restored.quizHistory.single.correct, 3);
    expect(restored.quizHistory.single.total, 5);
    expect(restored.quizScores, isEmpty);
  });

  testWidgets(
    'reference composer has editor/preview tabs, autosaves incomplete work and reopens it',
    (tester) async {
      final app = await pumpScreen(
        tester,
        ExamComposerScreen(
          profileRepository: MemoryExamProfileRepository(),
          questionBankRepository: MemoryExamQuestionBankRepository(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('إعداد الأسئلة'), findsOneWidget);
      final field = find.byKey(const ValueKey<String>('exam-school'));
      await tester.ensureVisible(field);
      await tester.enterText(field, 'مدرسة محفوظة');
      await tester.pumpAndSettle();
      expect(app.savedExams.papers.single.draft['schoolName'], 'مدرسة محفوظة');
      final id = app.savedExams.papers.single.id;
      final before = app.savedExams.papers.length;
      final context = tester.element(find.byType(ExamComposerScreen));
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SavedExamsScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey<String>('saved-exam-$id')));
      await tester.pumpAndSettle();
      final restored = tester.widget<TextField>(find.byKey(const ValueKey<String>('exam-school')));
      expect(restored.controller!.text, 'مدرسة محفوظة');
      expect(app.savedExams.papers.length, before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('A4 preview and zoom fit a narrow screen', (tester) async {
    final state = draft();
    await pumpScreen(
      tester,
      Scaffold(body: ExamLivePreview(paper: state.buildPaperWith(const ExamPaperTypography()))),
      size: const Size(360, 800),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('تكبير المعاينة'), findsOneWidget);
    await tester.tap(find.byTooltip('تكبير المعاينة'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(findFlexOverflows(tester), isEmpty);
    expect(
      find.text(
        examPaperAsPlainText(state.buildPaperWith(const ExamPaperTypography())).split('\n').first,
      ),
      findsOneWidget,
    );
    state.dispose();
  });

  testWidgets('interactive lobby uses art kinds and keeps unit review access', (tester) async {
    await pumpScreen(tester, const QuizPickerScreen());
    expect(find.byKey(const ValueKey<String>('quiz-unit-filter')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('quiz-style-trueFalse')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('start-quiz-button')));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('quiz-option-0')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('quiz-option-0')));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('quiz-next-button')), findsOneWidget);
  });
}

class _DelayedStore extends MemorySavedExamStore {
  final release = Completer<void>();
  @override
  Future<void> write(List<SavedExamPaper> papers) async {
    await release.future;
    await super.write(papers);
  }
}
