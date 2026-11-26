import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirsam/data/local/curated_question_bank.dart';
import 'package:mirsam/domain/models/library.dart';
import 'package:mirsam/domain/services/exam_paper_formatter.dart';
import 'package:mirsam/presentation/state/exam_composer_state.dart';
import 'package:mirsam/presentation/widgets/exam/exam_bank_picker.dart';

import 'test_support.dart';

void main() {
  setUpAll(ensureLibrary);

  test('every grade topic has a source-backed false statement and choice', () async {
    final library = await ensureLibrary();
    for (final grade in <String>['g1', 'g2', 'g3']) {
      final units = library.unitsOf(grade);
      final options = examQuestionOptions(units);
      for (final unit in units) {
        for (final topic in unit.topics) {
          for (final suffix in <String>['false', 'choice']) {
            final item = options.singleWhere(
              (option) => option.id == '${unit.id}:curated-${topic.id}-$suffix',
            );
            expect(topic.bullets, contains(item.question.answerSupport));
            expect(item.question.isGradable, isTrue);
            if (suffix == 'false') {
              expect(item.question.boolAnswer, isFalse);
            } else {
              expect(item.question.documentedAnswerText, isNotEmpty);
              expect(item.question.options.toSet().length, item.question.options.length);
            }
          }
        }
        expect(unit.questions.every((q) => !q.id.startsWith('curated-')), isTrue);
      }
    }
  });

  test('curated choices and statements survive a draft round trip', () async {
    final library = await ensureLibrary();
    ExamComposerState create() => ExamComposerState(
      units: library.unitsOf('g1'), drawings: library.drawings, gradeLabel: 'الأول',
    );
    final source = create();
    final falseQuestion = source.optionsOf(QuestionKind.trueFalse).firstWhere(
      (option) => option.id == 'g1-u1:curated-t3-false',
    );
    final choice = source.optionsOf(QuestionKind.choice).firstWhere(
      (option) => option.id == 'g1-u1:curated-t3-choice',
    );
    source.toggleItem(QuestionKind.trueFalse, falseQuestion.id);
    source.toggleItem(QuestionKind.choice, choice.id);
    final restored = create()..restoreDraft(source.toDraft());
    expect(restored.selectedItems(QuestionKind.trueFalse).single.prompt, falseQuestion.question.prompt);
    expect(restored.selectedItems(QuestionKind.choice).single.options, choice.question.options);
    expect(restored.unresolvedSourceIds, isEmpty);
    source.dispose();
    restored.dispose();
  });

  testWidgets('teacher can find and add a reviewed question with its answer and evidence', (tester) async {
    final library = await ensureLibrary();
    final state = ExamComposerState(
      units: library.unitsOf('g1'), drawings: library.drawings, gradeLabel: 'الأول',
    );
    addTearDown(state.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
      builder: (context) => TextButton(
        onPressed: () => showExamBankPicker(context, state, QuestionKind.trueFalse, () {}),
        child: const Text('فتح'),
      ),
    ))));
    await tester.tap(find.text('فتح'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey<String>('bank-search')), 'الأخضر والبرتقالي والبنفسجي');
    await tester.pumpAndSettle();
    final prompt = find.text('الألوان الأساسية في الصبغات هي الأخضر والبرتقالي والبنفسجي.');
    expect(prompt, findsOneWidget);
    expect(find.textContaining('الإجابة: خطأ'), findsOneWidget);
    expect(find.textContaining('الشاهد:'), findsOneWidget);
    await tester.tap(prompt);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('bank-apply')));
    await tester.pumpAndSettle();
    expect(state.isSelected(QuestionKind.trueFalse, 'g1-u1:curated-t3-false'), isTrue);
  });

  test('rejects invalid evidence, duplicate identities and out-of-range answers', () {
    final bank = jsonDecode(File('assets/question_bank/curated.json').readAsStringSync())
        as Map<String, dynamic>;
    final curriculum = jsonDecode(File('assets/content/curriculum.json').readAsStringSync())
        as Map<String, dynamic>;
    Map<String, dynamic> clone() => jsonDecode(jsonEncode(bank)) as Map<String, dynamic>;
    final badEvidence = clone();
    (badEvidence['questions'] as List).first['answerSupport'] = 'غير موجود';
    expect(() => parseCuratedQuestionBank(badEvidence, curriculum), throwsFormatException);
    final badChoice = clone();
    (badChoice['questions'] as List)[1]['answerIndex'] = 9;
    expect(() => parseCuratedQuestionBank(badChoice, curriculum), throwsFormatException);
    final duplicate = clone();
    (duplicate['questions'] as List).add((duplicate['questions'] as List).first);
    expect(() => parseCuratedQuestionBank(duplicate, curriculum), throwsFormatException);
  });
}
