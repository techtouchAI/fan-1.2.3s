import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/saved_exam.dart';

/// A load result retains unreadable records. A later successful edit must not
/// erase damaged or future-format work belonging to the teacher.
class SavedExamArchive {
  SavedExamArchive({
    required this.papers,
    this.recoveryRecords = const [],
    this.warnings = const [],
    this.readOnly = false,
  });
  final List<SavedExamPaper> papers;
  final List<dynamic> recoveryRecords;
  final List<String> warnings;
  final bool readOnly;

  factory SavedExamArchive.decode(Object? raw) {
    if (raw == null || raw == '') return SavedExamArchive(papers: const []);
    if (raw is! String)
      return SavedExamArchive(
        papers: const [],
        readOnly: true,
        warnings: const ['نوع مخزن الأوراق غير صالح؛ حُفظ الأصل ولم يُستبدل.'],
      );
    Object? root;
    try {
      root = jsonDecode(raw);
    } on FormatException {
      return SavedExamArchive(
        papers: const [],
        readOnly: true,
        warnings: const ['ملف الأوراق غير قابل للقراءة؛ حُفظ الأصل ولم يُستبدل.'],
      );
    }
    if (root is! Map<String, dynamic> ||
        root['papers'] is! List ||
        (root.containsKey('recoveryRecords') && root['recoveryRecords'] is! List) ||
        (root['version'] != null && root['version'] != 1)) {
      return SavedExamArchive(
        papers: const [],
        readOnly: true,
        warnings: const ['إصدار مخزن الأوراق غير مدعوم؛ لم تتغير البيانات الأصلية.'],
      );
    }
    final papers = <SavedExamPaper>[];
    final recovery = <dynamic>[
      if (root['recoveryRecords'] is List) ...root['recoveryRecords'] as List,
    ];
    final ids = <String>{};
    for (final row in root['papers'] as List) {
      try {
        final paper = SavedExamPaper.fromJson(Map<String, dynamic>.from(row as Map));
        if (paper.id.isEmpty || paper.revision < 1 || !ids.add(paper.id)) {
          throw const FormatException('Invalid or duplicate record identity');
        }
        papers.add(paper);
      } on FormatException {
        recovery.add(row);
      } on TypeError {
        recovery.add(row);
      }
    }
    return SavedExamArchive(
      papers: List.unmodifiable(papers),
      recoveryRecords: List.unmodifiable(recovery),
      warnings: recovery.isEmpty
          ? const []
          : ['حُفظت ${recovery.length} سجلات غير قابلة للفتح في قسم استعادة منفصل؛ لم تُحذف.'],
    );
  }

  String encode(List<SavedExamPaper> papers) => jsonEncode(<String, dynamic>{
    'version': 1,
    'papers': papers.map((p) => p.toJson()).toList(),
    if (recoveryRecords.isNotEmpty) 'recoveryRecords': recoveryRecords,
  });
}

abstract class SavedExamStore {
  List<SavedExamPaper> read();
  Future<void> write(List<SavedExamPaper> papers);
  List<String> get loadWarnings => const [];
  bool get isReadOnly => false;

  static Future<SavedExamStore> open() async =>
      SharedPrefsSavedExamStore(await SharedPreferences.getInstance());
  static String encode(List<SavedExamPaper> papers) =>
      SavedExamArchive(papers: const []).encode(papers);
  static List<SavedExamPaper> decode(String? raw) => SavedExamArchive.decode(raw).papers;
}

class SharedPrefsSavedExamStore extends SavedExamStore {
  SharedPrefsSavedExamStore(this._prefs);
  static const String storageKey = 'mirsam.saved-exams.v1';
  final SharedPreferences _prefs;
  SavedExamArchive get _archive => SavedExamArchive.decode(_prefs.get(storageKey));
  @override
  List<String> get loadWarnings => _archive.warnings;
  @override
  bool get isReadOnly => _archive.readOnly;
  @override
  List<SavedExamPaper> read() => _archive.papers;
  @override
  Future<void> write(List<SavedExamPaper> papers) async {
    if (isReadOnly) throw StateError('The original archive is protected from overwriting');
    if (!await _prefs.setString(storageKey, _archive.encode(papers))) {
      throw StateError('Saved exams could not be written to local storage');
    }
  }
}

class MemorySavedExamStore extends SavedExamStore {
  MemorySavedExamStore([List<SavedExamPaper> initial = const []])
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

/// Opening the native store failed. Allow reading the curriculum and exporting
/// a new paper, but never pretend a volatile fallback is durable storage.
class UnavailableSavedExamStore extends SavedExamStore {
  UnavailableSavedExamStore(this.warning);
  final String warning;
  @override
  bool get isReadOnly => true;
  @override
  List<String> get loadWarnings => <String>[warning];
  @override
  List<SavedExamPaper> read() => const <SavedExamPaper>[];
  @override
  Future<void> write(List<SavedExamPaper> papers) => Future<void>.error(StateError(warning));
}
