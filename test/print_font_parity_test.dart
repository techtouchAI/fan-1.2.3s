import 'package:flutter_test/flutter_test.dart';
import 'package:mirsam/data/local/docx/exam_docx_builder.dart';
import 'package:mirsam/domain/models/exam_paper.dart';
import 'package:mirsam/domain/models/question_print_settings.dart';
import 'package:mirsam/domain/repositories/exam_profile_repository.dart';
import 'package:mirsam/presentation/state/exam_composer_state.dart';

import 'docx_test_support.dart';
import 'test_support.dart';

void main() {
  test('PDF offers all six reference font families using bundled weights', () {
    expect(QuestionPrintFont.values.map((f) => f.family).toSet(), <String>{
      'IBMPlexSansArabic',
      'NotoKufiArabic',
      'Amiri',
      'Cairo',
      'Tajawal',
      'Almarai',
    });
    for (final font in QuestionPrintFont.values) {
      expect(font.regularAsset, 'assets/fonts/${font.family}-Regular.ttf');
      expect(font.boldAsset, 'assets/fonts/${font.family}-Bold.ttf');
    }
    // The existing question_pdf_test suite now runs its embedding, shaped
    // glyph and largest-size page-boundary assertions for all six families.
  });

  test('Cairo persists across composer snapshots and profiles and reaches OOXML', () async {
    final library = await ensureLibrary();
    final state = ExamComposerState(
      units: library.unitsOf('g1'),
      drawings: library.drawings,
      gradeLabel: 'الأول المتوسط',
    )..setFont(ExamPaperFont.cairo);
    final restored = ExamComposerState(
      units: library.unitsOf('g1'),
      drawings: library.drawings,
      gradeLabel: 'الأول المتوسط',
    )..restoreDraft(state.toDraft());
    addTearDown(state.dispose);
    addTearDown(restored.dispose);
    expect(restored.font, ExamPaperFont.cairo);
    expect(
      ExamProfile.fromJson(restored.toProfile().toJson()).typography.font,
      ExamPaperFont.cairo,
    );
    final paper = buildSamplePaper(
      typography: const ExamPaperTypography(font: ExamPaperFont.cairo),
    );
    final xml = documentXmlOf(ExamDocxBuilder.build(paper));
    expect(xml, contains('w:cs="Cairo"'));
    expect(xml, contains('w:ascii="Cairo"'));
    expectWellFormedXml(xml);
  });
}
