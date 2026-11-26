import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirsam/data/local/memory_exam_profile_repository.dart';
import 'package:mirsam/data/local/memory_progress_repository.dart';
import 'package:mirsam/data/local/saved_exam_store.dart';
import 'package:mirsam/domain/models/library.dart';
import 'package:mirsam/domain/models/progress.dart';
import 'package:mirsam/domain/models/saved_exam.dart';
import 'package:mirsam/domain/repositories/content_repository.dart';
import 'package:mirsam/domain/repositories/exam_profile_repository.dart';
import 'package:mirsam/presentation/screens/home_screen.dart';
import 'package:mirsam/presentation/state/app_state.dart';
import 'package:mirsam/presentation/state/bootstrap.dart';
import 'package:mirsam/presentation/state/exam_composer_state.dart';
import 'package:mirsam/presentation/widgets/exam/exam_generator_panel.dart';

import 'test_support.dart';

void main() {
  late Library library;
  setUpAll(() async {
    library = await ensureLibrary();
  });

  testWidgets('practical-only work requires confirmation before regeneration', (tester) async {
    final state = ExamComposerState(
      units: library.unitsOf('g1'),
      drawings: library.drawings,
      gradeLabel: 'الأول المتوسط',
    );
    addTearDown(state.dispose);
    state.setPracticalPrompt(0, 'عملي كتبه المدرس');
    var generations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ExamGeneratorPanel(state: state, onGenerated: () => generations++),
          ),
        ),
      ),
    );
    final button = find.byKey(const ValueKey<String>('generate-balanced-exam'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(state.practical.first.prompt, 'عملي كتبه المدرس');
    expect(generations, 0);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.text('توليد'));
    await tester.pumpAndSettle();
    expect(generations, 1);
    expect(state.practical.first.prompt, isNot('عملي كتبه المدرس'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('optional profile and store failures do not block the curriculum', (tester) async {
    await tester.pumpWidget(
      MirsamBootstrap(
        contentRepository: _Content(library),
        progressRepository: MemoryProgressRepository(ReadingProgress(gradeId: 'g1')),
        profileRepository: _UnavailableProfile(),
        savedExamStoreLoader: () async {
          throw StateError('Native storage unavailable');
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    final app = AppScope.read(tester.element(find.byType(HomeScreen)));
    expect(app.startupWarnings.length, 2);
    expect(app.savedExams.isReadOnly, isTrue);
    expect(await app.savedExams.flushChecked(), isFalse);
    expect(find.textContaining('تعذّر تحميل ملف المدرس'), findsOneWidget);
    expect(find.textContaining('تعذّر فتح مخزن الأوراق'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('essential content failure is still a startup error, not an empty curriculum', (
    tester,
  ) async {
    await tester.pumpWidget(
      MirsamBootstrap(
        contentRepository: _BrokenContent(),
        progressRepository: MemoryProgressRepository(),
        profileRepository: MemoryExamProfileRepository(),
        savedExamStoreLoader: () async => MemorySavedExamStore(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('تعذّر تحميل محتوى التطبيق'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('pending edits finish across an application pause and resume', (tester) async {
    final store = _PendingStore();
    await tester.pumpWidget(
      MirsamBootstrap(
        contentRepository: _Content(library),
        progressRepository: MemoryProgressRepository(ReadingProgress(gradeId: 'g1')),
        profileRepository: MemoryExamProfileRepository(),
        savedExamStoreLoader: () async => store,
      ),
    );
    await tester.pumpAndSettle();
    final app = AppScope.read(tester.element(find.byType(HomeScreen)));
    final draft = ExamComposerState(
      units: library.unitsOf('g1'),
      drawings: library.drawings,
      gradeLabel: 'الأول المتوسط',
    )..setSchoolName('آخر تعديل');
    addTearDown(draft.dispose);
    app.savedExams.save(draft.toDraft(), gradeId: 'g1');
    expect(app.savedExams.isSaving, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    store.release.complete();
    await app.savedExams.flush();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(app.savedExams.isDurable, isTrue);
    expect(store.read().single.draft['schoolName'], 'آخر تعديل');
    expect(tester.takeException(), isNull);
  });
}

class _Content implements ContentRepository {
  _Content(this.library);
  final Library library;
  @override
  Future<Library> load() async => library;
}

class _BrokenContent implements ContentRepository {
  @override
  Future<Library> load() async => throw StateError('Missing required content');
}

class _UnavailableProfile implements ExamProfileRepository {
  @override
  Future<ExamProfile> load() async => throw StateError('Broken optional profile');
  @override
  Future<void> save(ExamProfile profile) async {}
}

class _PendingStore extends MemorySavedExamStore {
  final release = Completer<void>();
  @override
  Future<void> write(List<SavedExamPaper> papers) async {
    await release.future;
    await super.write(papers);
  }
}
