import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../data/local/saved_exam_store.dart';
import 'dart:convert';
import '../../domain/models/saved_exam.dart';

/// The teacher's saved exam papers ("أسئلتي المحفوظة"), newest first.
///
/// Changes apply in memory immediately; persistence is coalesced so a burst of
/// edits (one per keystroke) never queues more than one pending write and the
/// last state always reaches the store.
class SavedExamLibrary extends ChangeNotifier {
  SavedExamLibrary(this._store, {DateTime Function() clock = DateTime.now, Random? random})
    : _clock = clock,
      _random = random ?? Random() {
    _papers = List<SavedExamPaper>.of(_store.read())
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  final SavedExamStore _store;
  final DateTime Function() _clock;
  final Random _random;
  late List<SavedExamPaper> _papers;

  Future<void>? _pendingWrite;
  bool _dirty = false;
  Object? _lastWriteError;

  List<SavedExamPaper> get papers => List<SavedExamPaper>.unmodifiable(_papers);

  bool get isEmpty => _papers.isEmpty;

  /// The last persistence failure, cleared by the next successful write.
  Object? get lastWriteError => _lastWriteError;

  SavedExamPaper? byId(String id) {
    for (final paper in _papers) {
      if (paper.id == id) {
        return paper;
      }
    }
    return null;
  }

  /// Creates a record (when [id] is null or unknown) or stores a new version
  /// of an existing one, and moves it to the top of the list.
  SavedExamPaper save(Map<String, dynamic> draft, {String? id, required String gradeId}) {
    final existing = id == null ? null : byId(id);
    if (existing != null && jsonEncode(existing.draft) == jsonEncode(draft)) {
      return existing;
    }
    final now = _clock();
    final record = existing == null
        ? SavedExamPaper(
            id: id ?? _newId(now),
            draft: draft,
            gradeId: gradeId,
            createdAt: now,
            updatedAt: now,
          )
        : existing.copyWith(draft: draft, updatedAt: now, revision: existing.revision + 1);
    _papers
      ..removeWhere((p) => p.id == record.id)
      ..insert(0, record);
    _changed();
    return record;
  }

  /// Saves an independent copy, so the teacher can branch a finished paper.
  SavedExamPaper? duplicate(String id) {
    final source = byId(id);
    if (source == null) {
      return null;
    }
    final now = _clock();
    final copy = SavedExamPaper(
      id: _newId(now),
      draft: source.draft,
      gradeId: source.gradeId,
      createdAt: now,
      updatedAt: now,
      customTitle: '${source.displayTitle} (نسخة)',
    );
    _papers.insert(0, copy);
    _changed();
    return copy;
  }

  /// Renames a paper; an empty [title] restores the header-derived name.
  bool rename(String id, String title) {
    final index = _papers.indexWhere((p) => p.id == id);
    if (index < 0) {
      return false;
    }
    _papers[index] = _papers[index].copyWith(customTitle: title.trim());
    _changed();
    return true;
  }

  bool delete(String id) {
    final before = _papers.length;
    _papers.removeWhere((p) => p.id == id);
    if (_papers.length == before) {
      return false;
    }
    _changed();
    return true;
  }

  /// Completes once every change made so far has been written.
  Future<void> flush() => _pendingWrite ?? Future<void>.value();

  String _newId(DateTime now) {
    String candidate() =>
        'exam-${now.microsecondsSinceEpoch.toRadixString(36)}'
        '-${_random.nextInt(0x7fffffff).toRadixString(36)}';
    var id = candidate();
    while (byId(id) != null) {
      id = candidate();
    }
    return id;
  }

  void retry() {
    if (_lastWriteError != null) _changed();
  }

  void _changed() {
    notifyListeners();
    _dirty = true;
    _pendingWrite ??= _drainWrites();
  }

  Future<void> _drainWrites() async {
    try {
      while (_dirty) {
        _dirty = false;
        try {
          await _store.write(List<SavedExamPaper>.unmodifiable(_papers));
          _lastWriteError = null;
        } catch (error, stack) {
          _lastWriteError = error;
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'mirsam saved exams',
              context: ErrorDescription('while saving the exam papers'),
            ),
          );
        }
      }
    } finally {
      _pendingWrite = null;
      notifyListeners();
    }
  }
}
