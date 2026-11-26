import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirsam/domain/models/library.dart';
import 'package:mirsam/domain/services/search_service.dart';
import 'package:mirsam/presentation/screens/curriculum_result_screen.dart';
import 'package:mirsam/presentation/screens/search_screen.dart';
import 'package:mirsam/presentation/screens/unit_screen.dart';
import 'package:mirsam/presentation/state/app_state.dart';
import 'package:mirsam/presentation/widgets/unit_question_card.dart';

import 'test_support.dart';

void main() {
  late Library library;
  setUpAll(() async {
    library = await ensureLibrary();
  });

  Library fixture() => Library(
    title: 'Test',
    subtitle: '',
    sections: const [],
    lessons: const [],
    glossary: const [],
    plates: const [],
    drawings: const [],
    units: <LearningUnit>[
      for (final grade in <String>['g1', 'g2'])
        LearningUnit(
          id: '$grade-unit',
          sectionId: grade,
          title: 'وحدة',
          displayTitle: 'وحدة الفن',
          grade: grade,
          order: 1,
          template: PresentationTemplate.concept,
          accent: 'primary',
          figures: const [],
          topics: const <Topic>[
            Topic(id: 'same', title: 'موضوع مميز', bullets: <String>['شرح مستقل']),
          ],
          questions: <Question>[
            Question(
              id: 'same',
              kind: QuestionKind.open,
              prompt: 'سؤال عن الفن',
              textAnswer: 'الزبرجد جوابفريد$grade',
              answerSupport: 'شاهدتصحيح',
            ),
            const Question(
              id: 'unknown',
              kind: QuestionKind.choice,
              prompt: 'اختيار غير موثق',
              options: <String>['خيارأ', 'خيارب'],
            ),
            const Question(
              id: 'unknown-bool',
              kind: QuestionKind.trueFalse,
              prompt: 'عبارة غير موثقة',
            ),
          ],
        ),
    ],
  );

  test('answer-only and support-only queries return precise question destinations', () {
    final service = SearchService(fixture());
    final hits = service.search('جوابفريدg1', matchMode: SearchMatchMode.allWords);
    expect(hits.length, 1);
    expect(hits.single.type, SearchHitType.question);
    expect(hits.single.unitId, 'g1-unit');
    expect(hits.single.questionId, 'same');
    expect(hits.single.snippet, contains('جوابفريدg1'));
    expect(service.search('شاهدتصحيح', type: SearchHitType.question).length, 2);
    expect(service.search('خيارأ', type: SearchHitType.question).length, 2);
    expect(service.search('راجع نص الوحدة', type: SearchHitType.question), isEmpty);
    expect(service.search('خطأ', type: SearchHitType.question), isEmpty);
  });

  test('topics and repeated local question ids stay independently scoped', () {
    final service = SearchService(fixture());
    final topics = service.search(
      'شرح مستقل',
      type: SearchHitType.topic,
      matchMode: SearchMatchMode.allWords,
    );
    expect(topics.length, 2);
    expect(topics.map((h) => h.id).toSet().length, 2);
    expect(topics.every((h) => h.topicId == 'same' && h.questionId == null), isTrue);
    final filtered = SearchService(fixture(), unitFilter: <String>{'g2-unit'});
    expect(filtered.search('الزبرجد').every((h) => h.unitId == 'g2-unit'), isTrue);
    expect(filtered.search('جوابفريدg1'), isEmpty);
  });

  test('all-word and any-word policies are explicit and deterministic', () {
    final service = SearchService(fixture());
    expect(service.search('الزبرجد غيرموجود', matchMode: SearchMatchMode.allWords), isEmpty);
    expect(service.search('الزبرجد غيرموجود', matchMode: SearchMatchMode.anyWord), isNotEmpty);
    expect(service.search('الزبرجد').map((h) => h.id), service.search('الزبرجد').map((h) => h.id));
    expect(
      service.search('الزبرجد', type: SearchHitType.question, limit: 1).single.type,
      SearchHitType.question,
    );
  });

  test('missing and invalid answer indexes are never interpreted as documented answers', () {
    const missingBool = Question(id: 'x', kind: QuestionKind.trueFalse, prompt: '');
    const negative = Question(
      id: 'x',
      kind: QuestionKind.choice,
      prompt: '',
      options: <String>['خيار'],
      answerIndex: -1,
    );
    const tooLarge = Question(
      id: 'x',
      kind: QuestionKind.choice,
      prompt: '',
      options: <String>['خيار'],
      answerIndex: 2,
    );
    expect(missingBool.documentedAnswerText, '');
    expect(negative.documentedAnswerText, '');
    expect(tooLarge.documentedAnswerText, '');
  });

  testWidgets('question result opens the exact answer and can open its whole unit', (tester) async {
    await pumpScreen(tester, const SearchScreen(), size: const Size(900, 1800));
    final unit = library.unitsOf('g1').firstWhere((u) => u.questions.isNotEmpty);
    final question = unit.questions.first;
    await tester.enterText(find.byType(TextField), question.prompt);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    final tile = find.byKey(ValueKey<String>('search-hit-${unit.id}:question:${question.id}'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    final detail = tester.widget<CurriculumResultScreen>(find.byType(CurriculumResultScreen));
    expect(detail.unitId, unit.id);
    expect(detail.questionId, question.id);
    expect(find.byType(UnitQuestionCard), findsOneWidget);
    expect(find.text(question.documentedAnswerText), findsOneWidget);
    await tester.tap(find.text('فتح الوحدة كاملةً'));
    await tester.pumpAndSettle();
    expect(tester.widget<UnitScreen>(find.byType(UnitScreen)).unitId, unit.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing grade invalidates retained question search results', (tester) async {
    final app = await pumpScreen(tester, const SearchScreen(), size: const Size(900, 1800));
    final unit = library.unitsOf('g1').firstWhere((u) => u.questions.isNotEmpty);
    await tester.enterText(find.byType(TextField), unit.questions.first.prompt);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    await app.setGrade('g3');
    await tester.pumpAndSettle();
    final oldHitPrefix = 'search-hit-${unit.id}:question:';
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(oldHitPrefix),
      ),
      findsNothing,
    );
  });

  testWidgets('topic result renders the targeted source content, not a generic unit', (
    tester,
  ) async {
    final unit = library.unitsOf('g1').first;
    final topic = unit.topics.first;
    await pumpScreen(tester, CurriculumResultScreen(unitId: unit.id, topicId: topic.id));
    expect(find.text(topic.title), findsOneWidget);
    if (topic.bullets.isNotEmpty) expect(find.text(topic.bullets.first), findsOneWidget);
    expect(find.text('فتح الوحدة كاملةً'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stale foreign-grade destinations never substitute content', (tester) async {
    final unit = library.unitsOf('g3').first;
    await pumpScreen(
      tester,
      CurriculumResultScreen(unitId: unit.id, topicId: unit.topics.first.id),
    );
    expect(find.text('لم تعد هذه النتيجة متاحة ضمن الصف الحالي.'), findsOneWidget);
    expect(find.byType(UnitQuestionCard), findsNothing);
    expect(AppScope.read(tester.element(find.byType(CurriculumResultScreen))).gradeId, 'g1');
  });
}
