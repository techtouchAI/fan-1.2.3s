import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirsam/data/local/docx/exam_docx_builder.dart';
import 'package:mirsam/data/local/memory_exam_profile_repository.dart';
import 'package:mirsam/data/local/memory_exam_question_bank_repository.dart';
import 'package:mirsam/domain/models/exam_draft_snapshot.dart';
import 'package:mirsam/domain/models/exam_paper.dart';
import 'package:mirsam/domain/models/library.dart';
import 'package:mirsam/domain/services/exam_paper_formatter.dart';
import 'package:mirsam/presentation/screens/exam_composer_screen.dart';
import 'package:mirsam/presentation/screens/quiz_picker_screen.dart';
import 'package:mirsam/presentation/state/exam_composer_state.dart';
import 'package:mirsam/presentation/widgets/exam/exam_live_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'docx_test_support.dart';
import 'test_support.dart';

void main() {
  late Library library;

  setUpAll(() async {
    library = await ensureLibrary();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('custom header, margins, free questions and branches match across formatter and DOCX', () {
    const paper = ExamPaper(
      info: ExamPaperInfo(
        schoolName: 'متوسطة الفرات للبنين',
        gradeLabel: 'الثالث المتوسط',
        sectionName: 'ب',
        term: ExamTerm.monthly,
        round: ExamRound.first,
        academicYear: '2026 – 2027',
        teacherName: 'حيدر السعدي',
      ),
      headerConfig: ExamHeaderConfig(
        directorateLine: 'المديرية العامة لتربية بابل',
        examDuration: 'ساعة واحدة',
        paperNote: 'ملاحظة: الإجابة عن جميع الأسئلة على الورقة نفسها.',
        closingWish: 'مع التمنيات بالنجاح الباهر',
        showScoreTable: false,
        showStudentFields: true,
      ),
      typography: ExamPaperTypography(
        font: ExamPaperFont.tajawal,
        headerFontSize: 12,
        bodyFontSize: 13,
        headingFontSize: 14,
      ),
      margins: ExamPageMargins.compact,
      theoryDegree: 60,
      practicalDegree: 40,
      theory: <ExamTheoryQuestion>[
        ExamTheoryQuestion(
          kind: QuestionKind.trueFalse,
          instruction: 'ضع علامة صح أو خطأ :',
          degree: 20,
          items: <ExamTheoryItem>[
            ExamTheoryItem(
              id: 'custom:trueFalse:1',
              kind: QuestionKind.trueFalse,
              prompt: 'تتوازن الطبيعة الصامتة بتوزيع الكتل والأحجام في فضاء اللوحة.',
            ),
          ],
        ),
      ],
      freeQuestions: <ExamFreeQuestion>[
        ExamFreeQuestion(
          id: 'free:1',
          title: 'أجب عن أحد الفرعين :',
          choiceNote: 'ترك فرع واحد',
          degree: 40,
          answerLineCount: 2,
          branches: <ExamQuestionBranch>[
            ExamQuestionBranch(
              label: 'أ',
              prompt: 'عرف ما يأتي :',
              degree: 20,
              items: <String>['الطبيعة الصامتة', 'التناظر المحوري'],
            ),
            ExamQuestionBranch(
              label: 'ب',
              prompt: 'علل ما يأتي :',
              degree: 20,
              items: <String>['أهمية خط الأفق في رسم المنظور الهندسي.'],
            ),
          ],
        ),
      ],
      practical: <ExamPracticalQuestion>[
        ExamPracticalQuestion(
          prompt: 'ارسم تكويناً لطبيعة صامتة يظهر فيه التظليل المتدرج',
          degree: 40,
        ),
      ],
    );

    final cols = examHeaderColumns(paper);
    expect(cols.rightLines.first, 'المديرية العامة لتربية بابل');
    expect(cols.centerLines.first, 'اسئلة الامتحان الشهري / الدور الأول');
    expect(cols.leftLines.last, 'الزمن : ساعة واحدة');

    final plain = examPaperAsPlainText(paper);
    expect(plain, contains('المديرية العامة لتربية بابل'));
    expect(plain, contains('ملاحظة: الإجابة عن جميع الأسئلة على الورقة نفسها.'));
    expect(plain, contains('س2: أجب عن أحد الفرعين : (ترك فرع واحد)   ( 40 درجة )'));
    expect(plain, contains('فرع (أ): عرف ما يأتي :   ( 20 درجة )'));
    expect(plain, contains('1- الطبيعة الصامتة'));
    expect(plain, contains('فرع (ب): علل ما يأتي :   ( 20 درجة )'));
    expect(plain, contains('مع التمنيات بالنجاح الباهر'));
    expect(plain.endsWith(examPaperBodyAsPlainText(paper)), isTrue);

    final bytes = ExamDocxBuilder.build(paper);
    final xml = documentXmlOf(bytes);
    expectWellFormedXml(xml);
    expect(xml, contains('w:top="360" w:right="510" w:bottom="510" w:left="510"'));
    expect(xml, contains('w:cs="Tajawal"'));
    expect(xml, contains('المديرية العامة لتربية بابل'));
    expect(xml, contains('الزمن : ساعة واحدة'));
    expect(xml, contains('فرع (أ): عرف ما يأتي :   ( 20 درجة )'));
    expect(xml, contains('1- الطبيعة الصامتة'));
    // Score table was disabled, so only header row + footer signoff row remain (2 <w:tr> rows).
    expect(RegExp(r'<w:tr\b').allMatches(xml).length, 2);
  });

  test('draft snapshot v3 roundtrips custom items, free questions, margins and header config', () {
    final state = ExamComposerState(
      units: library.unitsOf('g3'),
      drawings: library.drawings,
      gradeLabel: 'الثالث المتوسط',
    );
    addTearDown(state.dispose);

    state.setSchoolName('إعدادية الحلة');
    state.setTeacherName('سعد العبيدي');
    state.setTerm(ExamTerm.monthly);
    state.setMargins(ExamPageMargins.comfortable);
    state.updateHeaderConfig(
      const ExamHeaderConfig(
        directorateLine: 'تربية بابل',
        examDuration: 'ساعتان',
        paperNote: 'الإجابة بالقلم الجاف الأزرق',
        showScoreTable: false,
      ),
    );
    final customId = state.addCustomItem(
      QuestionKind.choice,
      prompt: 'يُصنع القالب الجصي من مادة :',
      options: <String>['البورك الفني', 'الفحم النباتي', 'الحبر الصيني'],
    );
    state.addTemplateFreeQuestion('branches');
    state.addPracticalSlot();
    state.setPracticalPrompt(3, 'صمم وحدة زخرفية نباتية متناظرة');

    final draft = state.toDraft();
    expect(draft['version'], ExamDraftSnapshot.currentVersion);

    final restored = ExamComposerState(
      units: const <LearningUnit>[],
      drawings: const <TopicDrawing>[],
      gradeLabel: 'الأول المتوسط',
    )..restoreDraft(draft);
    addTearDown(restored.dispose);

    expect(restored.toDraft(), draft);
    expect(restored.term, ExamTerm.monthly);
    expect(restored.margins, ExamPageMargins.comfortable);
    expect(restored.headerConfig.directorateLine, 'تربية بابل');
    expect(restored.headerConfig.showScoreTable, isFalse);
    expect(restored.selectedItems(QuestionKind.choice).single.id, customId);
    expect(restored.selectedItems(QuestionKind.choice).single.isCustom, isTrue);
    expect(restored.freeQuestions.single.branches.length, 2);
    expect(restored.practical.length, 4);
    expect(restored.paper, isNotNull);
  });

  testWidgets('composer UI adds template free question and renders it in A4 live preview',
      (WidgetTester tester) async {
    await pumpScreen(
      tester,
      ExamComposerScreen(
        profileRepository: MemoryExamProfileRepository(),
        questionBankRepository: MemoryExamQuestionBankRepository(),
      ),
      size: const Size(1280, 1800),
    );
    await tester.pumpAndSettle();

    final branchesChip = find.byKey(const ValueKey<String>('add-template-branches'));
    await tester.ensureVisible(branchesChip);
    await tester.pump();
    await tester.tap(branchesChip);
    await tester.pumpAndSettle();

    expect(find.text('سؤال حر ١'), findsOneWidget);
    expect(find.text('فرع (أ)'), findsOneWidget);
    expect(find.text('فرع (ب)'), findsOneWidget);

    await tester.tap(find.text('معاينة ورقة A4'));
    await tester.pumpAndSettle();
    expect(find.byType(ExamLivePreview), findsOneWidget);
    expect(find.textContaining('فرع (أ):'), findsOneWidget);
  });

  testWidgets('interactive quiz supports open enumeration self-assessment round',
      (WidgetTester tester) async {
    await pumpScreen(tester, const QuizPickerScreen(), size: const Size(900, 1600));
    await tester.tap(find.byKey(const ValueKey<String>('quiz-style-open')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('start-quiz-button')));
    await tester.pump();

    expect(find.byKey(const ValueKey<String>('quiz-open-attempt')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey<String>('quiz-open-attempt')),
      '١- النقطة الأولى\n٢- النقطة الثانية',
    );
    await tester.tap(find.byKey(const ValueKey<String>('quiz-reveal-open')));
    await tester.pump();

    expect(find.text('الإجابة النموذجية الموثقة:'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('quiz-self-mastered')));
    await tester.pump();

    expect(find.byKey(const ValueKey<String>('quiz-next-button')), findsOneWidget);
  });
}
