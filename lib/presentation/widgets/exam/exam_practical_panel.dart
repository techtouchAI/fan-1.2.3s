import 'package:flutter/material.dart';

import '../../../core/theme/dimens.dart';
import '../../../core/utils/arabic_text.dart';
import '../../../domain/models/library.dart';
import '../../state/exam_composer_state.dart';
import 'exam_composer_controllers.dart';
import 'exam_panel_parts.dart';

/// Fourth step: practical drawing questions (1..5 slots), each chosen from the
/// curriculum drawings or written freely.
class ExamPracticalPanel extends StatelessWidget {
  const ExamPracticalPanel({
    super.key,
    required this.state,
    required this.controllers,
    this.drawings,
  });

  final ExamComposerState state;
  final ExamComposerControllers controllers;
  final List<TopicDrawing>? drawings;

  List<TopicDrawing> get _drawings => drawings ?? state.drawings;

  @override
  Widget build(BuildContext context) {
    controllers.ensurePracticalControllerCount(state);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ExamPanelCard(
          title: 'عنوان المادة العملية',
          subtitle:
              'يُطبع: نصك، ثم ____________ والدرجات. إجمالي العملي '
              '${toArabicDigits('${state.practicalDegree ?? 0}')} درجة.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextField(
                key: const ValueKey<String>('exam-practical-header'),
                controller: controllers.practicalHeader,
                maxLines: null,
                decoration: const InputDecoration(
                  labelText: 'نص العنوان',
                  border: OutlineInputBorder(),
                ),
                onChanged: state.setPracticalHeader,
              ),
              const SizedBox(height: AppSpacing.md),
              ExamNumberField(
                fieldKey: const ValueKey<String>('exam-practical-total'),
                label: 'درجة القسم العملي',
                controller: controllers.practicalDegree,
                onChanged: () => state.setPracticalDegree(
                  parseIntegerDigits(controllers.practicalDegree.text),
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < state.practical.length; i++) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          _slot(context, i),
        ],
        if (state.practical.length < ExamComposerState.maxPracticalSlots) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              key: const ValueKey<String>('exam-add-practical-slot'),
              onPressed: () {
                state.addPracticalSlot();
                controllers.syncFrom(state);
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('إضافة سؤال عملي'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _slot(BuildContext context, int index) {
    final slot = state.practical[index];
    final availableDrawings = _drawings;
    TopicDrawing? selectedDrawing;
    if (slot.drawingId != null) {
      for (final TopicDrawing drawing in availableDrawings) {
        if (drawing.id == slot.drawingId) {
          selectedDrawing = drawing;
          break;
        }
      }
    }
    return ExamPanelCard(
      title: 'السؤال العملي ${toArabicDigits('${index + 1}')}',
      subtitle: index == 0
          ? 'اختر رسماً من رسومات المنهج أو اكتب نصاً مخصصاً.'
          : 'اختياري؛ يُحذف من الورقة إذا تُرك فارغاً.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (state.practical.length > 1 && index >= 3)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: IconButton(
                key: ValueKey<String>('exam-remove-practical-$index'),
                tooltip: 'حذف الخانة العملية',
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () {
                  state.removePracticalSlot(index);
                  controllers.syncFrom(state);
                },
              ),
            ),
          DropdownButtonFormField<String?>(
            key: ValueKey<String>('exam-drawing-$index'),
            initialValue: selectedDrawing?.id,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'من رسومات المنهج',
              border: OutlineInputBorder(),
            ),
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('كتابة حرة أو بدون سؤال'),
              ),
              for (final TopicDrawing drawing in availableDrawings)
                DropdownMenuItem<String?>(
                  value: drawing.id,
                  child: Text(
                    '${drawing.title} — ${drawing.unitTitle}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (String? id) => _pickDrawing(index, id),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: ValueKey<String>('exam-practical-$index'),
            controller: controllers.practicalPrompts[index],
            maxLines: null,
            decoration: const InputDecoration(
              labelText: 'نص السؤال العملي',
              hintText: 'رسم موضوع عن …',
              border: OutlineInputBorder(),
            ),
            onChanged: (String value) => state.setPracticalPrompt(index, value),
          ),
          const SizedBox(height: AppSpacing.md),
          ExamNumberField(
            fieldKey: ValueKey<String>('exam-practical-degree-$index'),
            label: 'درجة السؤال (إن وُجدت)',
            controller: controllers.practicalDegrees[index],
            onChanged: () {
              final value = parseIntegerDigits(
                controllers.practicalDegrees[index].text,
              );
              if (value != null) {
                state.setPracticalItemDegree(index, value);
              }
            },
          ),
        ],
      ),
    );
  }

  void _pickDrawing(int index, String? id) {
    if (id == null) {
      state.selectPracticalDrawing(index, null);
      controllers.practicalPrompts[index].text = '';
      return;
    }
    for (final TopicDrawing drawing in _drawings) {
      if (drawing.id == id) {
        state.selectPracticalDrawing(index, drawing);
        controllers.practicalPrompts[index].text = state.practical[index].prompt;
        return;
      }
    }
  }
}
