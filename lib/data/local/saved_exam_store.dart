import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/saved_exam.dart';

/// Local persistence for the teacher's saved exam papers.
abstract class SavedExamStore {
  List<SavedExamPaper> read();
  Future<void> write(List<SavedExamPaper> papers);

  static Future<SavedExamStore> open() async {
    final prefs = await SharedPreferences.getInstance();
    return SharedPrefsSavedExamStore(prefs);
  }

  /// Serialises [papers] as a versioned JSON envelope.
  static String encode(List<SavedExamPaper> papers) => jsonEncode(<String, dynamic>{
    'version': 1,
    'papers': papers.map((p) => p.toJson()).toList(growable: false),
  });

  /// Decodes [encode]'s output. A damaged record is skipped on its own, so one
  /// bad entry never costs the teacher every other saved paper.
  static List<SavedExamPaper> decode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const <SavedExamPaper>[];
    }
    Object? root;
    try {
      root = jsonDecode(raw);
    } on FormatException catch (error) {
      debugPrint('Saved exams could not be decoded: $error');
      return const <SavedExamPaper>[];
    }
    final entries = root is Map<String, dynamic> ? root['papers'] : null;
    if (entries is! List<dynamic>) {
      return const <SavedExamPaper>[];
    }
    final papers = <SavedExamPaper>[];
    final seenIds = <String>{};
    for (final entry in entries) {
      try {
        final paper = SavedExamPaper.fromJson(entry as Map<String, dynamic>);
        if (seenIds.add(paper.id)) {
          papers.add(paper);
        }
      } catch (error) {
        // Skipped deliberately; see the method documentation.
        debugPrint('Skipped a damaged saved exam: $error');
      }
    }
    return List<SavedExamPaper>.unmodifiable(papers);
  }
}

class SharedPrefsSavedExamStore implements SavedExamStore {
  SharedPrefsSavedExamStore(this._prefs);

  static const String storageKey = 'mirsam.saved-exams.v1';

  final SharedPreferences _prefs;

  @override
  List<SavedExamPaper> read() => SavedExamStore.decode(_prefs.getString(storageKey));

  @override
  Future<void> write(List<SavedExamPaper> papers) async {
    final saved = await _prefs.setString(storageKey, SavedExamStore.encode(papers));
    if (!saved) {
      throw StateError('Saved exams could not be written to local storage.');
    }
  }
}

/// In-memory store used by tests and as the default for [AppState].
///
/// It round-trips through JSON like the real store, so tests exercise the
/// serialisation that ships.
class MemorySavedExamStore implements SavedExamStore {
  MemorySavedExamStore([List<SavedExamPaper> initial = const <SavedExamPaper>[]])
    : _raw = SavedExamStore.encode(initial);

  String _raw;
  int writeCount = 0;

  @override
  List<SavedExamPaper> read() => SavedExamStore.decode(_raw);

  @override
  Future<void> write(List<SavedExamPaper> papers) async {
    writeCount++;
    _raw = SavedExamStore.encode(papers);
  }
}
