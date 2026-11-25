import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mirsam/data/local/exam_document_exporter.dart';
import 'package:mirsam/data/local/memory_progress_repository.dart';
import 'package:mirsam/data/local/prefs_exam_profile_repository.dart';
import 'package:mirsam/data/local/prefs_exam_question_bank_repository.dart';
import 'package:mirsam/data/local/saved_exam_store.dart';
import 'package:mirsam/domain/models/exam_draft_snapshot.dart';
import 'package:mirsam/domain/models/exam_paper.dart';
import 'package:mirsam/domain/models/exam_question_bank.dart';
import 'package:mirsam/domain/models/library.dart';
import 'package:mirsam/domain/models/progress.dart';
import 'package:mirsam/domain/models/saved_exam.dart';
import 'package:mirsam/domain/repositories/exam_profile_repository.dart';
import 'package:mirsam/presentation/state/app_state.dart';
import 'package:mirsam/presentation/state/exam_composer_state.dart';
import 'package:mirsam/presentation/state/saved_exam_library.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Library library;
  setUpAll(() async {
    library = await ensureLibrary();
  });
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  ExamComposerState composer({bool emptySource = false}) {
    final state = ExamComposerState(
      units: emptySource ? <LearningUnit>[] : library.unitsOf('g1'),
      drawings: emptySource ? <TopicDrawing>[] : library.drawings,
      gradeLabel: 'الأول المتوسط',
      profile: const ExamProfile(gradeLabel: 'الثالث المتوسط'),
    );
    addTearDown(state.dispose);
    return state;
  }

  SavedExamPaper record(Map<String, dynamic> draft) => SavedExamPaper(
    id: 'one',
    gradeId: 'g1',
    draft: draft,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  test('active curriculum grade wins over stale profile grade', () {
    expect(composer().gradeLabel, 'الأول المتوسط');
  });

  test('v2 freezes text and choices without depending on installed source', () {
    final state = composer();
    final option = state.optionsOf(QuestionKind.choice).first;
    state.toggleItem(QuestionKind.choice, option.id);
    final saved = state.toDraft();
    final restored = composer(emptySource: true)..restoreDraft(saved);
    final item = restored.selectedItems(QuestionKind.choice).single;
    expect(item.prompt, option.question.prompt);
    expect(item.options, option.question.options);
    expect(restored.unresolvedSourceIds, isEmpty);
    expect(restored.toDraft(), saved);
    restored.editItem(ExamTheoryItem(id: item.id, kind: item.kind, prompt: 'تعديل مستقل'));
    expect(restored.selectedItems(item.kind).single.prompt, 'تعديل مستقل');
    expect(option.question.prompt, isNot('تعديل مستقل'));
  });

  test('v1 migration retains missing ids and requires explicit removal', () {
    final state = composer();
    final old = state.toDraft()
      ..['version'] = 1
      ..remove('items');
    (old['selection'] as Map)['open'] = <String>['removed:question'];
    state.restoreDraft(old);
    expect(state.unresolvedSourceIds, <String>{'removed:question'});
    expect(state.paper, isNull);
    expect(state.issues.single, contains('استعادة'));
    final next = composer()..restoreDraft(state.toDraft());
    expect(next.restorationWarnings, isNotEmpty);
    expect(next.unresolvedSourceIds, state.unresolvedSourceIds);
    next.discardUnresolvedItems();
    expect(next.unresolvedSourceIds, isEmpty);
    expect(next.selectionOf(QuestionKind.open), isEmpty);
  });

  test('v1 edited content can be recovered even if its source was removed', () {
    final state = composer(emptySource: true);
    state.restoreDraft(<String, dynamic>{
      'version': 1,
      'selection': <String, dynamic>{
        'open': <String>['gone'],
      },
      'overrides': <dynamic>[
        <String, dynamic>{
          'id': 'gone',
          'kind': 'open',
          'prompt': 'نص المعلم',
          'options': <String>[],
        },
      ],
    });
    expect(state.unresolvedSourceIds, isEmpty);
    expect(state.selectedItems(QuestionKind.open).single.prompt, 'نص المعلم');
  });

  test('corrupt nested drafts are rejected before state changes or notifications', () {
    final state = composer()..setSchoolName('الأصل');
    final before = state.toDraft();
    var notifications = 0;
    state.addListener(() => notifications++);
    final badValues = <Map<String, dynamic>>[
      <String, dynamic>{'version': 999},
      <String, dynamic>{
        'selection': <String, dynamic>{'open': 42},
      },
      <String, dynamic>{
        'degrees': <String, dynamic>{'choice': 'bad'},
      },
      <String, dynamic>{
        'customized': <String, dynamic>{'open': 'true'},
      },
      <String, dynamic>{
        'answerLines': <String, dynamic>{'open': <int>[]},
      },
      <String, dynamic>{
        'practical': <dynamic>[
          <String, dynamic>{'drawingId': 1},
        ],
      },
      <String, dynamic>{
        'overrides': <dynamic>[
          <String, dynamic>{'id': 'x', 'kind': 'invalid', 'prompt': ''},
        ],
      },
      <String, dynamic>{'font': 'future-font'},
      <String, dynamic>{
        'selection': <String, dynamic>{
          'open': <String>['not-frozen'],
        },
      },
    ];
    for (final fields in badValues) {
      expect(
        () => state.restoreDraft(<String, dynamic>{...before, 'schoolName': 'changed', ...fields}),
        throwsFormatException,
        reason: '$fields',
      );
      expect(state.toDraft(), before);
    }
    expect(notifications, 0);
  });

  test('snapshot is deeply isolated but preserves unfinished numeric fields', () {
    final raw = composer().toDraft()..['bodyFontSize'] = null;
    final saved = ExamDraftSnapshot.decode(raw);
    raw['schoolName'] = 'mutated';
    saved.toJson()['schoolName'] = 'also mutated';
    expect(saved.toJson()['schoolName'], '');
    expect(saved.toJson()['bodyFontSize'], isNull);
  });

  test('damaged and future-version records survive a subsequent archive write', () async {
    final valid = record(composer().toDraft()).toJson();
    final corrupt = <String, dynamic>{
      ...valid,
      'id': 'corrupt',
      'draft': <String, dynamic>{'version': 1, 'practical': 5},
    };
    final future = <String, dynamic>{
      ...valid,
      'id': 'future',
      'draft': <String, dynamic>{'version': 99},
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      SharedPrefsSavedExamStore.storageKey,
      jsonEncode(<String, dynamic>{
        'version': 1,
        'papers': <dynamic>[corrupt, valid, future],
      }),
    );
    final store = SharedPrefsSavedExamStore(prefs);
    expect(store.read().length, 1);
    expect(store.loadWarnings, isNotEmpty);
    await store.write(store.read());
    final archive = SavedExamArchive.decode(prefs.getString(SharedPrefsSavedExamStore.storageKey));
    expect(archive.papers.length, 1);
    expect(archive.recoveryRecords, <dynamic>[corrupt, future]);
  });

  for (final raw in <Object>['{broken', '{"version":99,"papers":[]}', 17]) {
    test('unreadable root stays protected: $raw', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        SharedPrefsSavedExamStore.storageKey: raw,
      });
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPrefsSavedExamStore(prefs);
      final papers = SavedExamLibrary(store);
      addTearDown(papers.dispose);
      expect(store.isReadOnly, isTrue);
      expect(() => papers.save(composer().toDraft(), gradeId: 'g1'), throwsStateError);
      await expectLater(store.write(<SavedExamPaper>[]), throwsStateError);
      expect(prefs.get(SharedPrefsSavedExamStore.storageKey), raw);
    });
  }

  test('bank snapshots retain edits, instructions, degrees and drawing identities', () {
    final state = composer();
    final option = state.options.first;
    state.toggleItem(option.question.kind, option.id);
    state.editItem(ExamTheoryItem(id: option.id, kind: option.question.kind, prompt: 'سؤال محرر'));
    state.setInstruction(option.question.kind, 'تعليمات خاصة');
    state.setDegree(option.question.kind, 22);
    state.selectDrawing(0, state.drawings.first);
    final group = ExamQuestionBankEntry.fromJson(
      state.toBankEntry(id: 'group', title: 'مجموعة').toJson(),
    );
    final restored = composer()
      ..setSchoolName('تبقى هذه المدرسة')
      ..applyBankEntry(group);
    expect(restored.schoolName, 'تبقى هذه المدرسة');
    expect(restored.selectedItems(option.question.kind).single.prompt, 'سؤال محرر');
    expect(restored.instructionOf(option.question.kind), 'تعليمات خاصة');
    expect(restored.degreeOf(option.question.kind), 22);
    expect(restored.practical.first.drawingId, state.practical.first.drawingId);
  });

  test('legacy bank import clears unrelated edits, instructions and drawings', () {
    final state = composer();
    final option = state.options.first;
    state.editItem(ExamTheoryItem(id: option.id, kind: option.question.kind, prompt: 'تعديل سابق'));
    state.setInstruction(option.question.kind, 'تعليمات سابقة');
    state.selectDrawing(0, state.drawings.first);
    state.applyBankEntry(
      ExamQuestionBankEntry(
        id: 'legacy',
        title: '',
        savedAt: DateTime.utc(2026),
        selection: <String, List<String>>{
          option.question.kind.name: <String>[option.id],
        },
        practicalPrompts: <String>['عملي يدوي'],
      ),
    );
    expect(state.selectedItems(option.question.kind).single.prompt, option.question.prompt);
    expect(state.isInstructionCustomized(option.question.kind), isFalse);
    expect(state.practical.first.drawingId, isNull);
    expect(state.practical.first.drawingTitle, isNull);
    expect(state.practical.first.prompt, 'عملي يدوي');
  });

  test('malformed group rows are isolated and retained on the next save', () async {
    final valid = composer().toBankEntry(id: 'valid', title: 'سليم');
    final bad = <String, dynamic>{'id': 'bad', 'practicalPrompts': 8};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      PrefsExamQuestionBankRepository.storageKey,
      jsonEncode(<dynamic>[bad, valid.toJson()]),
    );
    const repo = PrefsExamQuestionBankRepository();
    final loaded = await repo.load();
    expect(loaded.single.id, 'valid');
    await repo.save(loaded);
    final rows = jsonDecode(prefs.getString(PrefsExamQuestionBankRepository.storageKey)!) as List;
    expect(rows.length, 2);
    expect(rows.last, bad);
  });

  test('optional corrupt profile fields do not prevent startup', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PrefsExamProfileRepository.storageKey: jsonEncode(<String, dynamic>{
        'teacherName': <String>['invalid'],
        'gradeLabel': 3,
        'font': false,
        'schoolName': 'سليمة',
      }),
    });
    final profile = await const PrefsExamProfileRepository().load();
    expect(profile.teacherName, '');
    expect(profile.gradeLabel, '');
    expect(profile.schoolName, 'سليمة');
  });

  test('durability remains pending until the store actually acknowledges it', () async {
    final store = _ControlledStore();
    final papers = SavedExamLibrary(store);
    addTearDown(papers.dispose);
    papers.save(composer().toDraft(), gradeId: 'g1');
    expect(papers.isSaving, isTrue);
    expect(papers.isDurable, isFalse);
    store.release.complete();
    expect(await papers.flushChecked(), isTrue);
    expect(papers.isSaving, isFalse);
  });

  test('failed persistence is not reported durable and retry writes the latest work', () async {
    final store = _ControlledStore()..fail = true;
    final papers = SavedExamLibrary(store);
    addTearDown(papers.dispose);
    final previous = FlutterError.onError;
    FlutterError.onError = (_) {};
    addTearDown(() => FlutterError.onError = previous);
    papers.save(composer().toDraft(), gradeId: 'g1');
    store.release.complete();
    expect(await papers.flushChecked(), isFalse);
    expect(papers.lastWriteError, isNotNull);
    store.fail = false;
    papers.retry();
    expect(await papers.flushChecked(), isTrue);
    expect(store.read().length, 1);
  });

  test('profile writes are serialized and failures do not poison the next update', () async {
    final repository = _OrderedProfiles();
    final app = AppState(
      library: library,
      progress: ReadingProgress(gradeId: 'g1'),
      progressRepository: MemoryProgressRepository(),
      profileRepository: repository,
    );
    addTearDown(app.dispose);
    final first = app.updateTeacherProfile(const ExamProfile(teacherName: 'first'));
    final firstExpectation = expectLater(first, throwsStateError);
    final second = app.updateTeacherProfile(const ExamProfile(teacherName: 'second'));
    await Future<void>.delayed(Duration.zero);
    expect(repository.names, <String>['first']);
    repository.release.complete();
    await firstExpectation;
    await second;
    expect(repository.names, <String>['first', 'second']);
    expect(app.teacherProfile.teacherName, 'second');
  });

  test('export cancellation is a typed result rather than a successful save', () {
    const result = ExamExportResult(message: 'أُلغي الحفظ', status: ExamExportStatus.cancelled);
    expect(result.wasCancelled, isTrue);
    expect(result.path, isNull);
  });
}

class _ControlledStore extends MemorySavedExamStore {
  final release = Completer<void>();
  bool fail = false;
  @override
  Future<void> write(List<SavedExamPaper> papers) async {
    await release.future;
    if (fail) throw StateError('Simulated disk failure');
    await super.write(papers);
  }
}

class _OrderedProfiles implements ExamProfileRepository {
  final release = Completer<void>();
  final names = <String>[];
  @override
  Future<ExamProfile> load() async => const ExamProfile();
  @override
  Future<void> save(ExamProfile profile) async {
    names.add(profile.teacherName);
    if (names.length == 1) {
      await release.future;
      throw StateError('Simulated profile failure');
    }
  }
}
