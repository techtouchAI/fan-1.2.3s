import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirsam/core/theme/app_colors.dart';
import 'package:mirsam/core/theme/app_theme.dart';
import 'package:mirsam/core/theme/dimens.dart';
import 'package:mirsam/core/widgets/app_page.dart';
import 'package:mirsam/core/widgets/section_header.dart';
import 'package:mirsam/core/widgets/meta_pill.dart';
import 'package:mirsam/presentation/screens/quiz_picker_screen.dart';
import 'package:mirsam/presentation/screens/quiz_screen.dart';
import 'package:mirsam/presentation/screens/search_screen.dart';
import 'package:mirsam/presentation/screens/settings_screen.dart';

import 'overflow_utils.dart';
import 'test_support.dart';

void main() {
  setUpAll(ensureLibrary);

  test('reference palette, reading measure and card geometry in both modes', () {
    expect(AppLayout.railBreakpoint, 840);
    expect(AppLayout.pageMaxWidth, 1140);
    expect(AppLayout.readingMaxWidth, 920);
    expect(AppRadii.lg, 16);
    for (final theme in <ThemeData>[AppTheme.light(), AppTheme.dark()]) {
      final dark = theme.brightness == Brightness.dark;
      expect(theme.colorScheme.primary, dark ? AppColors.terracottaLight : AppColors.terracotta);
      expect(theme.colorScheme.secondary, dark ? AppColors.tealLight : AppColors.deepTeal);
      expect(theme.scaffoldBackgroundColor, dark ? AppColors.night : AppColors.paper);
      expect(theme.textTheme.bodyLarge!.fontSize, 16);
      expect(theme.textTheme.bodyLarge!.height, 1.75);
      final shape = theme.cardTheme.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(16));
    }
  });

  test('font preference remains supported instead of hardcoding the reference font', () {
    for (final family in <String>[
      'Almarai',
      'Cairo',
      'Tajawal',
      'IBMPlexSansArabic',
      'NotoKufiArabic',
    ]) {
      for (final theme in <ThemeData>[
        AppTheme.light(bodyFont: family),
        AppTheme.dark(bodyFont: family),
      ]) {
        expect(theme.textTheme.bodyLarge!.fontFamily, family);
        expect(theme.textTheme.titleLarge!.fontFamily, family);
        expect(theme.textTheme.displaySmall!.fontFamily, 'Amiri');
      }
    }
  });

  for (final width in <double>[390, 839, 840, 1600]) {
    testWidgets('reference destinations and settings reachable at $width', (tester) async {
      await pumpApplication(tester, size: Size(width, 1000));
      expect(find.byType(width >= 840 ? NavigationRail : NavigationBar), findsOneWidget);
      // Search must not mount or autofocus until selected.
      expect(find.byType(SearchScreen, skipOffstage: false), findsNothing);
      await tapDestination(tester, 'البحث');
      expect(find.byType(SearchScreen), findsOneWidget);
      await tapDestination(tester, 'الاختبار');
      expect(find.byType(QuizPickerScreen), findsOneWidget);
      await tapDestination(tester, 'الرئيسية');
      await openSettings(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(findFlexOverflows(tester), isEmpty);
    });
  }

  testWidgets('quiz entry uses only active grade and opens the existing quiz', (tester) async {
    final state = await pumpScreen(tester, const QuizPickerScreen());
    final units = state.visibleUnits.where((unit) => unit.questions.isNotEmpty).toList();
    expect(find.byType(ListTile), findsNWidgets(units.length));
    await tester.tap(find.text(units.first.title));
    await tester.pumpAndSettle();
    expect(tester.widget<QuizScreen>(find.byType(QuizScreen)).unitId, units.first.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long metadata wraps inside a constrained card without shrinking text', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpScreen(
      tester,
      const Center(
        child: SizedBox(
          width: 174,
          child: MetaPill(label: 'التذوق الفني وتاريخ الفن', icon: Icons.menu_book_outlined),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(findFlexOverflows(tester), isEmpty);
  });

  testWidgets('page measure and mobile padding follow the reference', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppPage(
            child: SizedBox(key: ValueKey<String>('measure'), height: 20, width: double.infinity),
          ),
        ),
      ),
    );
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final padding = width >= 720 ? AppSpacing.xl : AppSpacing.lg;
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('measure'))).width,
      (width > AppLayout.pageMaxWidth ? AppLayout.pageMaxWidth : width) - padding * 2,
    );
  });

  testWidgets('long section actions cannot displace an Arabic heading', (tester) async {
    await pumpScreen(
      tester,
      const Scaffold(
        body: AppPage(
          child: SectionHeader(
            title: 'عنوان قسم طويل للقراءة والمراجعة',
            subtitle: 'وصف القسم',
            trailing: Text('إجراء طويل جداً لعرض المحتوى ومتابعة القراءة'),
          ),
        ),
      ),
      size: const Size(360, 640),
    );
    expect(tester.takeException(), isNull);
    expect(findFlexOverflows(tester), isEmpty);
  });
}
