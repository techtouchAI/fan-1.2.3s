import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mirsam/core/theme/app_theme.dart';
import 'package:mirsam/presentation/screens/drawing_viewer_screen.dart';
import 'package:mirsam/presentation/screens/drawings_screen.dart';
import 'package:mirsam/presentation/screens/exam_composer_screen.dart';
import 'package:mirsam/presentation/screens/favorites_screen.dart';
import 'package:mirsam/presentation/screens/glossary_screen.dart';
import 'package:mirsam/presentation/screens/grade_picker_screen.dart';
import 'package:mirsam/presentation/screens/home_screen.dart';
import 'package:mirsam/presentation/screens/index_screen.dart';
import 'package:mirsam/presentation/screens/lesson_screen.dart';
import 'package:mirsam/presentation/screens/lessons_screen.dart';
import 'package:mirsam/presentation/screens/plate_viewer_screen.dart';
import 'package:mirsam/presentation/screens/plates_screen.dart';
import 'package:mirsam/presentation/screens/question_print_screen.dart';
import 'package:mirsam/presentation/screens/quiz_picker_screen.dart';
import 'package:mirsam/presentation/screens/quiz_screen.dart';
import 'package:mirsam/presentation/screens/search_screen.dart';
import 'package:mirsam/presentation/screens/saved_exams_screen.dart';
import 'package:mirsam/presentation/screens/settings_screen.dart';
import 'package:mirsam/presentation/screens/unit_screen.dart';

import 'overflow_utils.dart';
import 'test_support.dart';

/// All presentation surfaces share the reference system, not only the dashboard.
void main() {
  setUpAll(ensureLibrary);
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));
  const screens = <String, Widget>{
    'drawing_viewer': DrawingViewerScreen(drawingId: 'drawing-01'),
    'drawings': DrawingsScreen(),
    'exam_composer': ExamComposerScreen(),
    'favorites': FavoritesScreen(embedded: true),
    'glossary': GlossaryScreen(),
    'grade_picker': GradePickerScreen(),
    'home': HomeScreen(),
    'index': IndexScreen(),
    'lesson': LessonScreen(lessonId: 'lesson-light'),
    'lessons': LessonsScreen(),
    'plate_viewer': PlateViewerScreen(plateId: 'plate-01'),
    'plates': PlatesScreen(),
    'question_print': QuestionPrintScreen(),
    'quiz_picker': QuizPickerScreen(),
    'quiz': QuizScreen(unitId: 'g1-u1'),
    'search': SearchScreen(),
    'saved_exams': SavedExamsScreen(),
    'settings': SettingsScreen(),
    'unit': UnitScreen(unitId: 'g1-u2'),
  };
  for (final size in <Size>[const Size(360, 800), const Size(1440, 1100)]) {
    for (final dark in <bool>[false, true]) {
      for (final entry in screens.entries) {
        testWidgets('${entry.key}: ${size.width}px, dark=$dark, zoom=120%', (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = 1.2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await pumpScreen(
            tester,
            entry.value,
            size: size,
            theme: dark ? AppTheme.dark() : AppTheme.light(),
          );
          await tester.pumpAndSettle();
          final error = tester.takeException();
          final overflows = findFlexOverflows(tester);
          if (error != null || overflows.isNotEmpty) {
            reportLayoutDiagnostic('${entry.key} ${size.width}px dark=$dark: $error $overflows');
          }
          expect(error, isNull);
          expect(overflows, isEmpty);
        });
      }
    }
  }
}
