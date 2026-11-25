import 'package:flutter/material.dart';
import '../../../core/theme/dimens.dart';
import '../../state/exam_composer_state.dart';
import 'exam_panel_parts.dart';

/// Reference quick generation, scoped to the art units rather than Arabic parts.
class ExamGeneratorPanel extends StatefulWidget {
  const ExamGeneratorPanel({super.key, required this.state, required this.onGenerated});
  final ExamComposerState state;
  final VoidCallback onGenerated;
  @override
  State<ExamGeneratorPanel> createState() => _ExamGeneratorPanelState();
}

class _ExamGeneratorPanelState extends State<ExamGeneratorPanel> {
  final Set<String> _units = <String>{};
  int _count = 5;
  @override
  Widget build(BuildContext context) {
    final units = <String, String>{
      for (final option in widget.state.options) option.unitId: option.unitTitle,
    };
    return ExamPanelCard(
      title: 'توليد أسئلة ذكي وسريع',
      subtitle: 'اختر النطاق وعدد الفقرات لكل نوع. يُحافظ على ترتيب المنهج داخل الورقة النهائية.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              FilterChip(
                label: const Text('شامل لجميع الوحدات'),
                selected: _units.isEmpty,
                onSelected: (_) => setState(_units.clear),
              ),
              for (final entry in units.entries)
                FilterChip(
                  label: Text(entry.value),
                  selected: _units.contains(entry.key),
                  onSelected: (value) => setState(() {
                    value ? _units.add(entry.key) : _units.remove(entry.key);
                  }),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<int>(
            initialValue: _count,
            decoration: const InputDecoration(labelText: 'عدد الفقرات لكل نوع (حسب المتاح)'),
            items: <DropdownMenuItem<int>>[
              for (var i = 1; i <= 10; i++) DropdownMenuItem(value: i, child: Text('$i')),
            ],
            onChanged: (value) => setState(() => _count = value ?? 5),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.tonalIcon(
            key: const ValueKey<String>('generate-balanced-exam'),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('توليد ورقة أسئلة جديدة'),
            onPressed: () async {
              final replace =
                  widget.state.theoryItemCount == 0 ||
                  await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('استبدال الاختيار الحالي؟'),
                          content: const Text(
                            'ستتغير اختيارات الأسئلة فقط. تبقى البيانات والخط والدرجات محفوظة.',
                          ),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('إلغاء'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('توليد'),
                            ),
                          ],
                        ),
                      ) ==
                      true;
              if (!replace) return;
              widget.state.generateBalancedExam(
                unitIds: _units.isEmpty ? null : _units,
                perKind: _count,
              );
              widget.onGenerated();
            },
          ),
        ],
      ),
    );
  }
}
