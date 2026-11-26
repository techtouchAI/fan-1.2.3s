import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirsam/data/local/saved_exam_store.dart';
import 'package:mirsam/domain/models/library.dart';
import 'package:mirsam/domain/models/question_print_settings.dart';
import 'package:mirsam/domain/services/exam_paper_formatter.dart';
import 'package:mirsam/domain/services/question_print_plan.dart';
import 'package:mirsam/presentation/state/saved_exam_library.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_support.dart';

void main() {
  setUpAll(ensureLibrary);

  test('backup restores all grades without replacing an existing paper', () async {
    final source = SavedExamLibrary(MemorySavedExamStore());
    final first = source.save(<String, dynamic>{}, gradeId: 'g1');
    source.save(<String, dynamic>{}, gradeId: 'g2');
    final backup = await source.exportBackup();
    final destination = SavedExamLibrary(MemorySavedExamStore());
    expect(await destination.importBackup(backup), 2);
    expect(destination.papers.map((p) => p.gradeId).toSet(), <String>{'g1', 'g2'});
    expect(await destination.importBackup(backup), 0);
    destination.rename(first.id, 'النسخة المحلية');
    expect(await destination.importBackup(backup), 1);
    expect(destination.byId(first.id)!.customTitle, 'النسخة المحلية');
    expect(destination.papers.length, 3);
    await destination.flush();
    source.dispose();
    destination.dispose();
  });

  test('invalid or partial backup never changes existing papers', () async {
    final library = SavedExamLibrary(MemorySavedExamStore());
    library.save(<String, dynamic>{}, gradeId: 'g1');
    await library.flush();
    for (final raw in <String>['', '{broken', '{"version":2,"papers":[]}',
      jsonEncode(<String, dynamic>{'version': 1, 'papers': <Object>[<String, dynamic>{}]})]) {
      await expectLater(library.importBackup(raw), throwsFormatException);
      expect(library.papers.length, 1);
    }
    library.dispose();
  });

  test('raw recovery records remain in the exported archive', () async {
    const raw = '{"version":1,"papers":[],"recoveryRecords":[{"unknown":true}]}';
    SharedPreferences.setMockInitialValues(<String, Object>{SharedPrefsSavedExamStore.storageKey: raw});
    final prefs = await SharedPreferences.getInstance();
    final library = SavedExamLibrary(SharedPrefsSavedExamStore(prefs));
    expect(await library.exportBackup(), raw);
    await expectLater(library.importBackup(raw), throwsFormatException);
    expect(prefs.getString(SharedPrefsSavedExamStore.storageKey), raw);
    library.dispose();
  });

  test('summary supports topic-only units and source-derived bank preserves original questions', () async {
    final content = await ensureLibrary();
    final intro = content.unitsOf('intro').single;
    final plan = QuestionPrintPlan.fromSelection(<LearningUnit>[intro], <String>{intro.id},
        settings: const QuestionPrintSettings(mode: StudentPrintMode.summary, compactSpacing: true));
    expect(plan.isEmpty, isFalse);
    expect(plan.units.single.topics, isNotEmpty);
    expect(plan.settings.compactSpacing, isTrue);
    final units = content.unitsOf('g1');
    final options = examQuestionOptions(units);
    final originals = units.expand((unit) => unit.questions).length;
    expect(options.length, greaterThan(originals));
    final ids = options.map((option) => option.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final unit in units) {
      for (final topic in unit.topics.where((topic) => topic.bullets.isNotEmpty)) {
        final added = options.firstWhere((o) => o.id == '${unit.id}:topic-${topic.id}-statement-0');
        expect(added.question.prompt, topic.bullets.first.trim());
        expect(added.question.boolAnswer, isTrue);
      }
    }
  });
}
