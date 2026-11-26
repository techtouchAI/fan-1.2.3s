import 'package:flutter/material.dart';

import '../../core/theme/dimens.dart';
import '../../core/utils/arabic_text.dart';
import '../../core/widgets/app_page.dart';
import '../../domain/models/library.dart';
import '../state/app_state.dart';
import '../widgets/teacher_profile_panel.dart';

/// First-launch gate and grade switcher: the learner or teacher picks one of
/// the three intermediate grades, and any typed teacher/school info is saved
/// automatically even if they tap a grade card directly.
class GradePickerScreen extends StatefulWidget {
  const GradePickerScreen({super.key});

  @override
  State<GradePickerScreen> createState() => _GradePickerScreenState();
}

class _GradePickerScreenState extends State<GradePickerScreen> {
  String _draftTeacher = '';
  String _draftSchool = '';
  bool _draftSeeded = false;

  Future<void> _selectGrade(BuildContext context, AppState state, String gradeId) async {
    if (_draftSeeded) {
      final nextTeacher = _draftTeacher.trim();
      final nextSchool = _draftSchool.trim();
      final current = state.teacherProfile;
      if (nextTeacher != current.teacherName || nextSchool != current.schoolName) {
        await state.updateTeacherProfile(
          current.copyWith(
            teacherName: nextTeacher,
            schoolName: nextSchool,
          ),
        );
      }
    }
    await state.setGrade(gradeId);
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final grades = state.gradeSections;
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      appBar: canPop
          ? AppBar(
              title: const Text('تغيير الصف الدراسي'),
            )
          : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
          children: <Widget>[
            AppPage(
              maxWidth: 640,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(height: canPop ? AppSpacing.lg : AppSpacing.xxl),
                  Row(
                    children: <Widget>[
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                        ),
                        alignment: Alignment.center,
                        child: Icon(Icons.palette, color: scheme.onPrimary, size: 28),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'مِرسم',
                          style: theme.textTheme.headlineLarge?.copyWith(fontSize: 32),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'اختر صفّك الدراسي',
                    style: theme.textTheme.displayMedium?.copyWith(fontSize: 26),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'سيقتصر التطبيق على وحدات الصف الذي تختاره وموضوعاته وأسئلته ولوحاته '
                    'ومصطلحاته، مع المدخل العام والدروس التطبيقية ومفردات الأنشطة المسرحية. '
                    'يمكنك تغيير الصف لاحقًا من الشاشة الرئيسية أو صفحة الإعدادات.',
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.7),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  for (final ContentSection grade in grades) ...<Widget>[
                    _GradeCard(
                      section: grade,
                      selected: state.gradeId == grade.id,
                      onSelect: () => _selectGrade(context, state, grade.id),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  TeacherProfilePanel(
                    onDraftChanged: (String teacher, String school) {
                      _draftSeeded = true;
                      _draftTeacher = teacher;
                      _draftSchool = school;
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'التربية الفنية • المرحلة المتوسطة • يعمل دون إنترنت',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradeCard extends StatelessWidget {
  const _GradeCard({
    required this.section,
    required this.selected,
    required this.onSelect,
  });

  final ContentSection section;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final units = state.library.unitsOf(section.id);
    final topics = units.fold<int>(
      0,
      (int sum, LearningUnit unit) => sum + unit.topics.length,
    );

    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.35)
          : scheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        key: ValueKey<String>('grade-card-${section.id}'),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onSelect,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.6 : 1.0,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: selected ? scheme.primary : scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                alignment: Alignment.center,
                child: Icon(
                  selected ? Icons.check_rounded : Icons.school_outlined,
                  color: selected ? scheme.onPrimary : scheme.onPrimaryContainer,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      section.title,
                      style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${toArabicDigits('${units.length}')} وحدات • '
                      '${toArabicDigits('$topics')} موضوعًا',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.arrow_back_ios_new, size: 16, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
