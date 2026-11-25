import 'package:flutter/material.dart';
import '../../../core/theme/dimens.dart';
import '../../../core/utils/arabic_text.dart';
import '../../../domain/models/exam_paper.dart';
import '../../../domain/models/library.dart';
import '../../../domain/services/exam_paper_formatter.dart';
import '../../state/exam_composer_state.dart';

/// Searchable, scoped, multi-select bank. Local selection is committed only on
/// Apply, so dismissing a sheet never changes the paper.
Future<void> showExamBankPicker(
  BuildContext context,
  ExamComposerState state,
  QuestionKind kind,
  VoidCallback onApplied,
) async {
  final result = await showModalBottomSheet<({Set<String> ids, bool replace})>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _BankPicker(state: state, kind: kind),
  );
  if (result != null) {
    state.selectItems(kind, result.ids, replace: result.replace);
    onApplied();
  }
}

class _BankPicker extends StatefulWidget {
  const _BankPicker({required this.state, required this.kind});
  final ExamComposerState state;
  final QuestionKind kind;
  @override
  State<_BankPicker> createState() => _BankPickerState();
}

class _BankPickerState extends State<_BankPicker> {
  String _query = '';
  String? _unit;
  bool _replace = false;
  bool _onlySelected = false;
  final Set<String> _picked = <String>{};
  @override
  Widget build(BuildContext context) {
    final all = widget.state.optionsOf(widget.kind);
    final units = <String, String>{for (final option in all) option.unitId: option.unitTitle};
    final query = normalizeArabic(_query);
    final visible = all
        .where(
          (option) =>
              (_unit == null || option.unitId == _unit) &&
              (!_onlySelected || widget.state.isSelected(widget.kind, option.id)) &&
              normalizeArabic(
                '${option.question.prompt} ${option.question.options.join(' ')} ${option.unitTitle}',
              ).contains(query),
        )
        .toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.9,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'بنك الأسئلة — ${theoryKindLabel(widget.kind)}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'إغلاق',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            TextField(
              key: const ValueKey<String>('bank-search'),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'ابحث في السؤال أو الخيارات أو الوحدة',
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: _unit ?? 'all',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'نطاق البنك'),
              items: <DropdownMenuItem<String>>[
                const DropdownMenuItem(value: 'all', child: Text('جميع الوحدات')),
                for (final unit in units.entries)
                  DropdownMenuItem(
                    value: unit.key,
                    child: Text(unit.value, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) => setState(() => _unit = value == 'all' ? null : value),
            ),
            Wrap(
              spacing: AppSpacing.sm,
              children: <Widget>[
                FilterChip(
                  label: const Text('المحددة في الورقة فقط'),
                  selected: _onlySelected,
                  onSelected: (value) => setState(() => _onlySelected = value),
                ),
                TextButton(
                  onPressed: () => setState(() => _picked.addAll(visible.map((e) => e.id))),
                  child: const Text('تحديد النتائج'),
                ),
                TextButton(
                  onPressed: () => setState(_picked.clear),
                  child: const Text('مسح التحديد'),
                ),
              ],
            ),
            Expanded(
              child: visible.isEmpty
                  ? const Center(child: Text('لا توجد نتائج مطابقة. جرّب نطاقاً أو عبارة أخرى.'))
                  : ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final option = visible[index];
                        return CheckboxListTile(
                          value: _picked.contains(option.id),
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(option.question.prompt),
                          subtitle: Text(
                            '${option.unitTitle}${option.question.options.isEmpty ? '' : '\n${option.question.options.join(' / ')}'}',
                          ),
                          secondary: widget.state.isSelected(widget.kind, option.id)
                              ? const Icon(Icons.check_circle_outline)
                              : null,
                          onChanged: (value) => setState(() {
                            value == true ? _picked.add(option.id) : _picked.remove(option.id);
                          }),
                        );
                      },
                    ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('استبدال محتوى السؤال بدلاً من الإضافة'),
              value: _replace,
              onChanged: (value) => setState(() => _replace = value),
            ),
            FilledButton.icon(
              key: const ValueKey<String>('bank-apply'),
              onPressed: _picked.isEmpty
                  ? null
                  : () => Navigator.pop(context, (ids: Set<String>.of(_picked), replace: _replace)),
              icon: const Icon(Icons.library_add),
              label: Text(
                '${_replace ? 'استبدال' : 'إضافة'} ${toArabicDigits('${_picked.length}')} فقرة',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> editExamItem(
  BuildContext context,
  ExamComposerState state,
  ExamTheoryItem item,
) async {
  final result = await showDialog<ExamTheoryItem>(
    context: context,
    builder: (_) => _EditItemDialog(item: item),
  );
  if (result != null) state.editItem(result);
}

class _EditItemDialog extends StatefulWidget {
  const _EditItemDialog({required this.item});
  final ExamTheoryItem item;
  @override
  State<_EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends State<_EditItemDialog> {
  late final TextEditingController _prompt = TextEditingController(text: widget.item.prompt);
  late final TextEditingController _options = TextEditingController(
    text: widget.item.options.join('\n'),
  );
  @override
  void dispose() {
    _prompt.dispose();
    _options.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('تحرير الفقرة في هذه الورقة فقط'),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              key: const ValueKey<String>('edit-item-prompt'),
              controller: _prompt,
              maxLines: null,
              decoration: const InputDecoration(labelText: 'نص الفقرة'),
            ),
            if (widget.item.kind == QuestionKind.choice) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _options,
                maxLines: null,
                decoration: const InputDecoration(labelText: 'الخيارات (كل خيار في سطر)'),
              ),
            ],
            const Text('لن يتغير نص المنهج أو إجابات الاختبار؛ التعديل خاص بورقة الامتحان.'),
          ],
        ),
      ),
    ),
    actions: <Widget>[
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
      FilledButton(
        onPressed: () {
          if (_prompt.text.trim().isEmpty) return;
          Navigator.pop(
            context,
            ExamTheoryItem(
              id: widget.item.id,
              kind: widget.item.kind,
              prompt: _prompt.text.trim(),
              options: _options.text.split('\n').where((e) => e.trim().isNotEmpty).toList(),
            ),
          );
        },
        child: const Text('حفظ التعديل'),
      ),
    ],
  );
}
