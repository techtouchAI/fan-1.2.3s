import 'package:flutter/material.dart';
import '../../core/theme/dimens.dart';
import '../state/app_state.dart';

/// The same local teacher profile is used by onboarding, settings and Word.
class TeacherProfilePanel extends StatefulWidget {
  const TeacherProfilePanel({super.key, this.onDraftChanged});

  /// Optional listener so onboarding can auto-persist typed teacher/school
  /// values if the user taps a grade card before pressing Save.
  final void Function(String teacherName, String schoolName)? onDraftChanged;

  @override
  State<TeacherProfilePanel> createState() => _TeacherProfilePanelState();
}

class _TeacherProfilePanelState extends State<TeacherProfilePanel> {
  final _teacher = TextEditingController();
  final _school = TextEditingController();
  bool _initialized = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final profile = AppScope.read(context).teacherProfile;
    _teacher.text = profile.teacherName;
    _school.text = profile.schoolName;
    widget.onDraftChanged?.call(_teacher.text, _school.text);
  }

  @override
  void dispose() {
    _teacher.dispose();
    _school.dispose();
    super.dispose();
  }

  void _notifyDraft() {
    widget.onDraftChanged?.call(_teacher.text, _school.text);
  }

  Future<void> _save() async {
    final state = AppScope.read(context);
    setState(() => _saving = true);
    try {
      await state.updateTeacherProfile(
        state.teacherProfile.copyWith(
          teacherName: _teacher.text.trim(),
          schoolName: _school.text.trim(),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ بيانات المدرس والمدرسة.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر حفظ البيانات. حاول مرة أخرى.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'بيانات المدرس والمدرسة (لأوراق الامتحان Word)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Text(
            'اختياري؛ تُحفظ محلياً وتظهر تلقائياً في ترويسة وتوقيع أوراق الأسئلة.',
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey<String>('profile-teacher'),
            controller: _teacher,
            onChanged: (_) => _notifyDraft(),
            decoration: const InputDecoration(
              labelText: 'اسم مدرس المادة',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey<String>('profile-school'),
            controller: _school,
            onChanged: (_) => _notifyDraft(),
            decoration: const InputDecoration(
              labelText: 'اسم المدرسة',
              prefixIcon: Icon(Icons.school_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            key: const ValueKey<String>('save-teacher-profile'),
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'جاري الحفظ...' : 'حفظ بيانات المدرس'),
          ),
        ],
      ),
    ),
  );
}
