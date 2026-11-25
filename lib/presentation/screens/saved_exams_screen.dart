import 'package:flutter/material.dart';

import '../../core/theme/dimens.dart';
import '../../core/utils/arabic_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/local/exam_document_exporter.dart';
import '../../data/local/docx/exam_docx_builder.dart';
import '../../domain/services/exam_paper_formatter.dart';
import '../state/exam_composer_state.dart';
import '../../domain/models/saved_exam.dart';
import '../state/app_state.dart';
import '../state/saved_exam_library.dart';
import 'exam_composer_screen.dart';

/// «أسئلتي المحفوظة»: every exam paper the teacher created, autosaved by the
/// composer, newest first.
class SavedExamsScreen extends StatelessWidget {
  const SavedExamsScreen({super.key, this.onExport});

  /// Overrides the Word exporter (used by tests); defaults to the real one.
  final ExamDocumentExport? onExport;

  @override
  Widget build(BuildContext context) {
    final library = AppScope.of(context).savedExams;
    return Scaffold(
      appBar: AppBar(title: const Text('أسئلتي المحفوظة')),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey<String>('saved-exams-new'),
        onPressed: () => _openComposer(context),
        icon: const Icon(Icons.add),
        label: const Text('ورقة أسئلة جديدة'),
      ),
      body: ListenableBuilder(
        listenable: library,
        builder: (BuildContext context, _) {
          final papers = library.papers
              .where((paper) => paper.gradeId == AppScope.of(context).gradeId)
              .toList();
          if (papers.isEmpty) {
            return EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'لا توجد أسئلة محفوظة بعد',
              message: library.loadWarnings.isNotEmpty
                  ? library.loadWarnings.join('\n')
                  : 'كل ورقة أسئلة تنشئها أو تعدّلها في مولّد الأسئلة تُحفظ هنا تلقائياً مع آخر تعديل.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(
              top: AppSpacing.md,
              // Clear the floating action button.
              bottom: AppSpacing.xxl * 2.5,
            ),
            itemCount: papers.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (BuildContext context, int index) => AppPage(
              maxWidth: AppLayout.readingMaxWidth,
              child: _SavedExamCard(
                saved: papers[index],
                onOpen: () => _openComposer(context, papers[index].id),
                onAction: (action) => _handleAction(context, library, papers[index], action),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openComposer(BuildContext context, [String? savedId]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExamComposerScreen(savedExamId: savedId, exportDocument: onExport),
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    SavedExamLibrary library,
    SavedExamPaper saved,
    _SavedExamAction action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (library.isReadOnly &&
        action != _SavedExamAction.open &&
        action != _SavedExamAction.export) {
      messenger.showSnackBar(
        const SnackBar(content: Text('المخزن محمي من التغيير للحفاظ على البيانات الأصلية.')),
      );
      return;
    }
    switch (action) {
      case _SavedExamAction.open:
        _openComposer(context, saved.id);
      case _SavedExamAction.export:
        await _export(context, messenger, saved);
      case _SavedExamAction.duplicate:
        library.duplicate(saved.id);
        messenger.showSnackBar(const SnackBar(content: Text('تم إنشاء نسخة مستقلة من الورقة.')));
      case _SavedExamAction.rename:
        final title = await _askForTitle(context, saved);
        if (title != null) {
          library.rename(saved.id, title);
        }
      case _SavedExamAction.delete:
        if (await _confirmDelete(context, saved)) {
          library.delete(saved.id);
          messenger.showSnackBar(SnackBar(content: Text('تم حذف «${saved.displayTitle}».')));
        }
    }
  }

  Future<void> _export(
    BuildContext context,
    ScaffoldMessengerState messenger,
    SavedExamPaper saved,
  ) async {
    final app = AppScope.read(context);
    final composer = ExamComposerState(
      units: app.library.unitsOf(saved.gradeId),
      drawings: app.library.drawings.where(
        (d) => app.library.unitById(d.unitId)?.sectionId == saved.gradeId,
      ),
      gradeLabel: '',
    );
    try {
      composer.restoreDraft(saved.draft);
      final paper = composer.paper;
      if (paper == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('الورقة غير مكتملة؛ افتحها لإكمال البيانات قبل التصدير.')),
        );
        return;
      }
      final outcome = await (onExport ?? ExamDocumentExporter.export)(
        ExamDocxBuilder.build(paper),
        examPaperFileName(paper),
      );
      messenger.showSnackBar(SnackBar(content: Text(outcome.message)));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('تعذّر تصدير ملف Word: $error')));
    } finally {
      composer.dispose();
    }
  }

  Future<String?> _askForTitle(BuildContext context, SavedExamPaper saved) {
    return showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: saved.customTitle),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, SavedExamPaper saved) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('حذف الورقة المحفوظة؟'),
        content: Text('سيُحذف «${saved.displayTitle}» نهائياً من هذا الجهاز.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            key: const ValueKey<String>('saved-exam-confirm-delete'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}

enum _SavedExamAction { open, export, duplicate, rename, delete }

class _SavedExamCard extends StatelessWidget {
  const _SavedExamCard({required this.saved, required this.onOpen, required this.onAction});

  final SavedExamPaper saved;
  final VoidCallback onOpen;
  final ValueChanged<_SavedExamAction> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final draft = saved.draft;
    final details = <String>[
      if ('${draft['schoolName'] ?? ''}'.trim().isNotEmpty) '${draft['schoolName']}',
      'النظري ${draft['theoryDegree'] ?? '—'} • العملي ${draft['practicalDegree'] ?? '—'}',
    ].join(' • ');

    return Material(
      key: ValueKey<String>('saved-exam-${saved.id}'),
      color: scheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.description_outlined, color: scheme.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(saved.displayTitle, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(details, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 2),
                    Text(
                      'آخر حفظ تلقائي: ${formatSavedTimestamp(saved.updatedAt)}'
                      ' • النسخة ${toArabicDigits('${saved.revision}')}',
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_SavedExamAction>(
                key: ValueKey<String>('saved-exam-menu-${saved.id}'),
                tooltip: 'خيارات الورقة',
                onSelected: onAction,
                itemBuilder: (_) => const <PopupMenuEntry<_SavedExamAction>>[
                  PopupMenuItem<_SavedExamAction>(
                    value: _SavedExamAction.open,
                    child: _MenuRow(Icons.edit_outlined, 'فتح وتعديل'),
                  ),
                  PopupMenuItem<_SavedExamAction>(
                    value: _SavedExamAction.export,
                    child: _MenuRow(Icons.download_outlined, 'تصدير Word (.docx)'),
                  ),
                  PopupMenuItem<_SavedExamAction>(
                    value: _SavedExamAction.duplicate,
                    child: _MenuRow(Icons.copy_outlined, 'إنشاء نسخة'),
                  ),
                  PopupMenuItem<_SavedExamAction>(
                    value: _SavedExamAction.rename,
                    child: _MenuRow(Icons.drive_file_rename_outline, 'إعادة التسمية'),
                  ),
                  PopupMenuItem<_SavedExamAction>(
                    value: _SavedExamAction.delete,
                    child: _MenuRow(Icons.delete_outline, 'حذف'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Icon(icon, size: 20),
      const SizedBox(width: AppSpacing.sm),
      Flexible(child: Text(label)),
    ],
  );
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إعادة تسمية الورقة'),
      content: TextField(
        key: const ValueKey<String>('saved-exam-title-field'),
        controller: _text,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'اسم الورقة',
          helperText: 'اتركه فارغاً لاستعمال عنوان الامتحان والدور',
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        FilledButton(
          key: const ValueKey<String>('saved-exam-title-save'),
          onPressed: () => Navigator.of(context).pop(_text.text),
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

/// `٢٠٢٦/١١/٢٣ — ٠٩:٠٥` in local time with Arabic-Indic digits.
String formatSavedTimestamp(DateTime moment) {
  final local = moment.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return toArabicDigits(
    '${local.year}/${two(local.month)}/${two(local.day)} — '
    '${two(local.hour)}:${two(local.minute)}',
  );
}
