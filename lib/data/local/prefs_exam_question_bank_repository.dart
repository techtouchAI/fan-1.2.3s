import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/exam_question_bank.dart';
import '../../domain/repositories/exam_question_bank_repository.dart';

/// Legacy JSON lists remain readable. Unreadable rows are retained on write;
/// a corrupt root is protected rather than replaced by an empty collection.
class PrefsExamQuestionBankRepository implements ExamQuestionBankRepository {
  const PrefsExamQuestionBankRepository();
  static const String storageKey = 'mirsam.exam-question-bank.v1';

  /// Kept for API compatibility; user work is no longer silently truncated.
  static const int maxEntries = 20;

  static List<dynamic> _rows(Object? raw) {
    if (raw == null || raw == '') return <dynamic>[];
    if (raw is! String) throw const FormatException('Invalid group archive');
    final value = jsonDecode(raw);
    if (value is! List) throw const FormatException('Invalid group archive');
    return value;
  }

  static ExamQuestionBankEntry _entry(dynamic row) {
    if (row is! Map<String, dynamic>) throw const FormatException('Invalid group');
    return ExamQuestionBankEntry.fromJson(row);
  }

  @override
  Future<List<ExamQuestionBankEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    List<dynamic> rows;
    try {
      rows = _rows(prefs.get(storageKey));
    } on FormatException {
      return <ExamQuestionBankEntry>[];
    }
    final entries = <ExamQuestionBankEntry>[];
    for (final row in rows) {
      try {
        entries.add(_entry(row));
      } on FormatException {
        // Kept in the original archive and carried forward by save().
      } on TypeError {
        // Older data with invalid nested types is isolated to this row.
      }
    }
    return entries;
  }

  @override
  Future<void> save(List<ExamQuestionBankEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    // Re-read at write time so a previous load is never required for recovery.
    final recovery = <dynamic>[];
    for (final row in _rows(prefs.get(storageKey))) {
      try {
        _entry(row);
      } on FormatException {
        recovery.add(row);
      } on TypeError {
        recovery.add(row);
      }
    }
    final saved = await prefs.setString(
      storageKey,
      jsonEncode(<dynamic>[for (final entry in entries) entry.toJson(), ...recovery]),
    );
    if (!saved) throw StateError('Could not persist question groups');
  }
}
