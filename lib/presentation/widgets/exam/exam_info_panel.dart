import 'package:flutter/material.dart';

import '../../../core/theme/dimens.dart';
import '../../../domain/models/exam_paper.dart';
import '../../state/exam_composer_state.dart';
import 'exam_composer_controllers.dart';
import 'exam_panel_parts.dart';

/// Header, exam metadata, teacher signature, and customizable official header
/// options (directorate, duration, note, score-table toggle).
class ExamInfoPanel extends StatelessWidget {
  const ExamInfoPanel({
    super.key,
    required this.state,
    required this.controllers,
  });

  final ExamComposerState state;
  final ExamComposerControllers controllers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cfg = state.headerConfig;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ExamPanelCard(
          title: 'المدرسة والصف',
          subtitle: 'تُطبع في أعلى الورقة كما في النموذج الرسمي.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextField(
                key: const ValueKey<String>('exam-school'),
                controller: controllers.school,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'اسم المدرسة',
                  hintText: 'متوسطة …',
                  border: OutlineInputBorder(),
                ),
                onChanged: state.setSchoolName,
              ),
              const SizedBox(height: AppSpacing.md),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final grade = TextField(
                    key: const ValueKey<String>('exam-grade'),
                    controller: controllers.grade,
                    decoration: const InputDecoration(
                      labelText: 'الصف',
                      hintText: 'الأول المتوسط',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: state.setGradeLabel,
                  );
                  final section = TextField(
                    key: const ValueKey<String>('exam-section'),
                    controller: controllers.section,
                    decoration: const InputDecoration(
                      labelText: 'الشعبة',
                      hintText: 'أ',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: state.setSectionName,
                  );
                  if (constraints.maxWidth >= 480) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(child: grade),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: section),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      grade,
                      const SizedBox(height: AppSpacing.md),
                      section,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ExamPanelCard(
          title: 'نوع الامتحان',
          subtitle: 'الشطر الأول من عنوان الورقة، مع دعم الفصول والامتحانات الشهرية.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  for (final ExamTerm term in ExamTerm.values)
                    ChoiceChip(
                      key: ValueKey<String>('exam-term-${term.name}'),
                      label: Text(term.label),
                      selected: state.term == term,
                      onSelected: (_) => state.setTerm(term),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  for (final ExamRound round in ExamRound.values)
                    ChoiceChip(
                      key: ValueKey<String>('exam-round-${round.name}'),
                      label: Text(round.label),
                      selected: state.round == round,
                      onSelected: (_) => state.setRound(round),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const ValueKey<String>('exam-year'),
                controller: controllers.year,
                decoration: const InputDecoration(
                  labelText: 'السنة الدراسية',
                  border: OutlineInputBorder(),
                ),
                onChanged: state.setAcademicYear,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'السنة مأخوذة من تاريخ الجهاز تلقائياً، ويمكن تعديلها.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ExamPanelCard(
          title: 'اسم المدرس',
          subtitle: 'يُطبع في أسفل الورقة، ويُحفظ لملء الامتحان القادم تلقائياً.',
          child: TextField(
            key: const ValueKey<String>('exam-teacher'),
            controller: controllers.teacher,
            decoration: const InputDecoration(
              labelText: 'اسم المدرس',
              border: OutlineInputBorder(),
            ),
            onChanged: state.setTeacherName,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ExamPanelCard(
          title: 'تخصيص الترويسة الرسمية وجدول الدرجات',
          subtitle: 'خيارات إضافية لتطابق القالب المعتمد في مديريتك ومدرستك.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final dirField = TextField(
                    key: const ValueKey<String>('exam-directorate'),
                    controller: controllers.directorate,
                    decoration: const InputDecoration(
                      labelText: 'المديرية / الجهة الأعلى (اختياري)',
                      hintText: 'المديرية العامة لتربية …',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (String v) =>
                        state.updateHeaderConfig(cfg.copyWith(directorateLine: v)),
                  );
                  final durField = TextField(
                    key: const ValueKey<String>('exam-duration'),
                    controller: controllers.examDuration,
                    decoration: const InputDecoration(
                      labelText: 'زمن الامتحان (اختياري)',
                      hintText: 'ساعتان / ساعة ونصف',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (String v) =>
                        state.updateHeaderConfig(cfg.copyWith(examDuration: v)),
                  );
                  if (constraints.maxWidth >= 520) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(flex: 3, child: dirField),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(flex: 2, child: durField),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      dirField,
                      const SizedBox(height: AppSpacing.md),
                      durField,
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const ValueKey<String>('exam-custom-title'),
                controller: controllers.customExamTitle,
                decoration: const InputDecoration(
                  labelText: 'عنوان مخصص للامتحان (اختياري)',
                  hintText: 'اتركه فارغاً لاستخدام العنوان التلقائي أعلاه',
                  border: OutlineInputBorder(),
                ),
                onChanged: (String v) =>
                    state.updateHeaderConfig(cfg.copyWith(customExamTitle: v)),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const ValueKey<String>('exam-paper-note'),
                controller: controllers.paperNote,
                decoration: const InputDecoration(
                  labelText: 'ملاحظة أعلى الأسئلة (اختياري)',
                  hintText: 'مثال: ملاحظة: الإجابة على الورقة نفسها',
                  border: OutlineInputBorder(),
                ),
                onChanged: (String v) =>
                    state.updateHeaderConfig(cfg.copyWith(paperNote: v)),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const ValueKey<String>('exam-closing-wish'),
                controller: controllers.closingWish,
                decoration: const InputDecoration(
                  labelText: 'عبارة التمنيات الختامية',
                  border: OutlineInputBorder(),
                ),
                onChanged: (String v) =>
                    state.updateHeaderConfig(cfg.copyWith(closingWish: v)),
              ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile.adaptive(
                key: const ValueKey<String>('exam-toggle-score-table'),
                contentPadding: EdgeInsets.zero,
                title: const Text('إظهار جدول الدرجات والمصحح والمدقق'),
                subtitle: const Text('مناسب للامتحانات النهائية ونصف السنة؛ يمكنك إخفاؤه للامتحان الشهري.'),
                value: cfg.showScoreTable,
                onChanged: (bool v) =>
                    state.updateHeaderConfig(cfg.copyWith(showScoreTable: v)),
              ),
              SwitchListTile.adaptive(
                key: const ValueKey<String>('exam-toggle-student-fields'),
                contentPadding: EdgeInsets.zero,
                title: const Text('إظهار حقلي الاسم والرقم الامتحاني في الترويسة'),
                value: cfg.showStudentFields,
                onChanged: (bool v) =>
                    state.updateHeaderConfig(cfg.copyWith(showStudentFields: v)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
