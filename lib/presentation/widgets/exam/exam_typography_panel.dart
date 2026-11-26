import 'package:flutter/material.dart';

import '../../../core/theme/dimens.dart';
import '../../../core/utils/arabic_text.dart';
import '../../../domain/models/exam_paper.dart';
import '../../state/exam_composer_state.dart';
import 'exam_composer_controllers.dart';
import 'exam_panel_parts.dart';

/// Typography, line-spacing, and A4 page margin controls for the exam paper.
class ExamTypographyPanel extends StatelessWidget {
  const ExamTypographyPanel({
    super.key,
    required this.state,
    required this.controllers,
  });

  final ExamComposerState state;
  final ExamComposerControllers controllers;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ExamPanelCard(
          title: 'نوع الخط وحجمه',
          subtitle:
              'تُطبَّق على معاينة ورقة A4 وملف Word المصدَّر، ولا تغيّر خط قراءة التطبيق.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              DropdownButtonFormField<ExamPaperFont>(
                key: const ValueKey<String>('exam-font'),
                initialValue: state.font,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'نوع الخط',
                  border: OutlineInputBorder(),
                ),
                items: <DropdownMenuItem<ExamPaperFont>>[
                  for (final ExamPaperFont font in ExamPaperFont.values)
                    DropdownMenuItem<ExamPaperFont>(
                      value: font,
                      child: Text(font.label, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (ExamPaperFont? font) {
                  if (font != null) {
                    state.setFont(font);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              _sizes(),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _spacing(Theme.of(context)),
        const SizedBox(height: AppSpacing.lg),
        _marginsCard(),
        const SizedBox(height: AppSpacing.lg),
        _preview(context),
      ],
    );
  }

  Widget _sizes() {
    final fields = <Widget>[
      ExamNumberField(
        fieldKey: const ValueKey<String>('exam-header-size'),
        label: 'حجم خط الترويسة',
        controller: controllers.headerSize,
        unit: 'نقطة',
        min: ExamPaperTypography.minFontSize,
        max: ExamPaperTypography.maxFontSize,
        onChanged: () => state.setHeaderFontSize(_sizeOf(controllers.headerSize)),
      ),
      ExamNumberField(
        fieldKey: const ValueKey<String>('exam-body-size'),
        label: 'حجم خط الأسئلة',
        controller: controllers.bodySize,
        unit: 'نقطة',
        min: ExamPaperTypography.minFontSize,
        max: ExamPaperTypography.maxFontSize,
        onChanged: () => state.setBodyFontSize(_sizeOf(controllers.bodySize)),
      ),
      ExamNumberField(
        fieldKey: const ValueKey<String>('exam-heading-size'),
        label: 'حجم خط العناوين',
        controller: controllers.headingSize,
        unit: 'نقطة',
        min: ExamPaperTypography.minFontSize,
        max: ExamPaperTypography.maxFontSize,
        onChanged: () => state.setHeadingFontSize(_sizeOf(controllers.headingSize)),
      ),
    ];
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth >= 560) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (var i = 0; i < fields.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: AppSpacing.md),
                Expanded(child: fields[i]),
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (var i = 0; i < fields.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: AppSpacing.md),
              fields[i],
            ],
          ],
        );
      },
    );
  }

  Widget _spacing(ThemeData theme) {
    final percent = parseIntegerDigits(controllers.lineSpacing.text);
    final valid = ExamPaperTypography.isValidLineSpacing(percent);
    final current = valid ? percent! : ExamPaperTypography.defaultLineSpacingPercent;
    return ExamPanelCard(
      title: 'تباعد الأسطر',
      subtitle: 'قلّل النسبة لتقليل الفراغ بين الأسطر واستيعاب أسئلة أكثر في الصفحة.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _spacingRow(current, valid, theme),
          Slider(
            key: const ValueKey<String>('exam-line-spacing-slider'),
            value: current.toDouble(),
            min: ExamPaperTypography.minLineSpacingPercent.toDouble(),
            max: ExamPaperTypography.maxLineSpacingPercent.toDouble(),
            divisions:
                ExamPaperTypography.maxLineSpacingPercent -
                ExamPaperTypography.minLineSpacingPercent,
            label: '${toArabicDigits('$current')}٪',
            onChanged: (double value) {
              final next = value.round();
              controllers.lineSpacing.text = '$next';
              state.setLineSpacingPercent(next);
            },
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const ValueKey<String>('exam-line-spacing-reset'),
              onPressed:
                  state.lineSpacingPercent ==
                      ExamPaperTypography.officialLineSpacingPercent
                  ? null
                  : () {
                      controllers.lineSpacing.text =
                          '${ExamPaperTypography.officialLineSpacingPercent}';
                      state.resetLineSpacing();
                    },
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('استعادة التباعد الرسمي'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _spacingRow(int current, bool valid, ThemeData theme) {
    final label = Text(
      valid
          ? 'التباعد الحالي ${toArabicDigits('$current')}٪ من الأصل'
          : 'أدخل نسبة بين '
                '${toArabicDigits('${ExamPaperTypography.minLineSpacingPercent}')} و'
                ' ${toArabicDigits('${ExamPaperTypography.maxLineSpacingPercent}')}',
      key: const ValueKey<String>('exam-spacing-label'),
      style: theme.textTheme.labelLarge?.copyWith(
        color: valid ? null : theme.colorScheme.error,
      ),
    );
    final field = ExamNumberField(
      fieldKey: const ValueKey<String>('exam-line-spacing'),
      label: 'النسبة ٪',
      controller: controllers.lineSpacing,
      min: ExamPaperTypography.minLineSpacingPercent,
      max: ExamPaperTypography.maxLineSpacingPercent,
      onChanged: () => state.setLineSpacingPercent(
        parseIntegerDigits(controllers.lineSpacing.text),
      ),
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth >= 420) {
          return Row(
            children: <Widget>[
              Expanded(child: label),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(width: 130, child: field),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            label,
            const SizedBox(height: AppSpacing.md),
            field,
          ],
        );
      },
    );
  }

  Widget _marginsCard() {
    final preset = state.margins.presetName;
    return ExamPanelCard(
      title: 'هوامش صفحة A4',
      subtitle: 'تُطبَّق بنفس الأبعاد على معاينة A4 وعلى ملف Word المصدَّر.',
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: <Widget>[
          ChoiceChip(
            key: const ValueKey<String>('exam-margins-compact'),
            label: const Text('ضيق (مساحة قصوى)'),
            selected: preset == 'compact',
            onSelected: (_) => state.setMargins(ExamPageMargins.compact),
          ),
          ChoiceChip(
            key: const ValueKey<String>('exam-margins-standard'),
            label: const Text('قياسي رسمي'),
            selected: preset == 'standard',
            onSelected: (_) => state.setMargins(ExamPageMargins.standard),
          ),
          ChoiceChip(
            key: const ValueKey<String>('exam-margins-comfortable'),
            label: const Text('واسع ومريح'),
            selected: preset == 'comfortable',
            onSelected: (_) => state.setMargins(ExamPageMargins.comfortable),
          ),
        ],
      ),
    );
  }

  Widget _preview(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final typography = state.typography ?? const ExamPaperTypography();
    final previewFont = typography.font.previewFamily;
    return ExamPanelCard(
      title: 'معاينة الأحجام والخط',
      subtitle: 'عينة سريعة للأحجام وتباعد الأسطر قبل فتح معاينة ورقة A4 الكاملة.',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'اسئلة امتحانات ${state.term.label}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: previewFont,
                fontSize: typography.headerFontSize.toDouble(),
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'المادة النظرية / اجب عن سؤالين فقط',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: previewFont,
                fontSize: typography.headingFontSize.toDouble(),
                fontWeight: FontWeight.bold,
                height: _previewHeight(typography),
              ),
            ),
            Text(
              '1- ضع علامة صح امام العبارة الصحيحة',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: previewFont,
                fontSize: typography.bodyFontSize.toDouble(),
                height: _previewHeight(typography),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static int? _sizeOf(TextEditingController controller) =>
      parseIntegerDigits(controller.text);

  static double _previewHeight(ExamPaperTypography typography) =>
      typography.lineTwips / ExamPaperTypography.baseLineTwips;
}
