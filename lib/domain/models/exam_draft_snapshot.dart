import 'dart:convert';

/// Validated persistence boundary, distinct from a *complete* printable paper.
/// Null/unfinished numbers are valid drafts; wrong JSON types are not.
/// - V1 contains source references.
/// - V2 freezes the selected text.
/// - V3 adds `headerConfig`, `margins`, and `freeQuestions` (with `branches`).
class ExamDraftSnapshot {
  ExamDraftSnapshot._(this._json);
  static const int currentVersion = 3;
  final String _json;

  Map<String, dynamic> toJson() => jsonDecode(_json) as Map<String, dynamic>;
  int get version => toJson()['version'] as int? ?? 1;

  factory ExamDraftSnapshot.decode(Map<String, dynamic> value) {
    final version = value['version'] ?? 1;
    if (version is! int || version < 1 || version > currentVersion) {
      throw const FormatException('Unsupported exam draft version');
    }
    void field(Map map, String key, bool Function(Object?) accepts) {
      if (map.containsKey(key) && !accepts(map[key])) {
        throw FormatException('Invalid draft field: $key');
      }
    }

    bool text(Object? v) => v is String;
    bool boolean(Object? v) => v is bool;
    bool integer(Object? v) => v == null || v is int;
    bool strings(Object? v) => v is List && v.every((s) => s is String);
    Map object(Object? v, String name) {
      if (v is! Map || v.keys.any((key) => key is! String)) {
        throw FormatException('Invalid draft object: $name');
      }
      return v;
    }

    const kinds = <String>{'trueFalse', 'choice', 'open'};
    for (final key in <String>[
      'schoolName',
      'gradeLabel',
      'sectionName',
      'teacherName',
      'academicYear',
      'term',
      'round',
      'font',
      'theoryHeader',
      'practicalHeader',
    ]) {
      field(value, key, text);
    }
    for (final key in <String>[
      'headerFontSize',
      'bodyFontSize',
      'headingFontSize',
      'lineSpacingPercent',
      'theoryDegree',
      'practicalDegree',
    ]) {
      field(value, key, integer);
    }
    for (final key in <String>[
      'selection',
      'instructions',
      'degrees',
      'customized',
      'answerLines',
    ]) {
      if (!value.containsKey(key)) continue;
      final map = object(value[key], key);
      for (final entry in map.entries) {
        if (!kinds.contains(entry.key)) {
          throw FormatException('Unknown question kind: ${entry.key}');
        }
        switch (key) {
          case 'selection':
            field(map, entry.key as String, strings);
          case 'instructions':
            field(map, entry.key as String, text);
          case 'customized':
            field(map, entry.key as String, boolean);
          default:
            field(map, entry.key as String, integer);
        }
      }
    }
    field(value, 'restorationWarnings', strings);
    const enums = <String, Set<String>>{
      'term': {
        'firstSemester',
        'midYear',
        'secondSemester',
        'endOfYear',
        'monthly',
      },
      'round': {'first', 'second', 'third'},
      'font': {
        'traditionalArabic',
        'simplifiedArabic',
        'sakkalMajalla',
        'arial',
        'timesNewRoman',
        'amiri',
        'cairo',
        'tajawal',
        'almarai',
      },
    };
    for (final entry in enums.entries) {
      if (value.containsKey(entry.key) && !entry.value.contains(value[entry.key])) {
        throw FormatException('Unsupported draft value: ${entry.key}');
      }
    }
    if (value.containsKey('practical')) {
      final slots = value['practical'];
      if (slots is! List || slots.length > 5) {
        throw const FormatException('Invalid practical slots');
      }
      for (final raw in slots) {
        final slot = object(raw, 'practical');
        field(slot, 'prompt', text);
        field(slot, 'degree', integer);
        field(slot, 'drawingId', (v) => v == null || v is String);
        field(slot, 'drawingTitle', (v) => v == null || v is String);
      }
    }
    if (value.containsKey('headerConfig')) {
      final cfg = object(value['headerConfig'], 'headerConfig');
      for (final key in <String>[
        'directorateLine',
        'administrationLabel',
        'subjectName',
        'customExamTitle',
        'examDuration',
        'paperNote',
        'closingWish',
        'teacherTitle',
      ]) {
        field(cfg, key, text);
      }
      field(cfg, 'showStudentFields', boolean);
      field(cfg, 'showScoreTable', boolean);
    }
    if (value.containsKey('margins')) {
      final m = object(value['margins'], 'margins');
      for (final key in <String>[
        'topTwips',
        'rightTwips',
        'bottomTwips',
        'leftTwips',
      ]) {
        field(m, key, integer);
      }
    }
    if (value.containsKey('freeQuestions')) {
      final freeList = value['freeQuestions'];
      if (freeList is! List || freeList.length > 20) {
        throw const FormatException('Invalid freeQuestions');
      }
      final seenFree = <String>{};
      for (final raw in freeList) {
        final fq = object(raw, 'freeQuestions');
        if (fq['id'] is! String ||
            (fq['id'] as String).isEmpty ||
            !seenFree.add(fq['id'] as String)) {
          throw const FormatException('Invalid freeQuestion id');
        }
        field(fq, 'title', text);
        field(fq, 'degree', integer);
        field(fq, 'choiceNote', text);
        field(fq, 'items', strings);
        field(fq, 'answerLineCount', integer);
        if (fq.containsKey('branches')) {
          final branches = fq['branches'];
          if (branches is! List || branches.length > 6) {
            throw const FormatException('Invalid freeQuestion branches');
          }
          for (final rawBranch in branches) {
            final branch = object(rawBranch, 'branch');
            field(branch, 'label', text);
            field(branch, 'prompt', text);
            field(branch, 'items', strings);
            field(branch, 'degree', integer);
          }
        }
      }
    }

    final frozen = <String, String>{};
    for (final key in <String>['items', 'overrides']) {
      if (!value.containsKey(key)) continue;
      final items = value[key];
      if (items is! List) throw FormatException('Invalid $key');
      final seen = <String>{};
      for (final raw in items) {
        final item = object(raw, key);
        if (item['id'] is! String ||
            (item['id'] as String).isEmpty ||
            !seen.add(item['id'] as String) ||
            !kinds.contains(item['kind']) ||
            item['prompt'] is! String) {
          throw FormatException('Invalid item in $key');
        }
        field(item, 'options', strings);
        if (key == 'items') frozen[item['id'] as String] = item['kind'] as String;
      }
    }
    for (final raw in value['overrides'] as List? ?? const []) {
      final item = raw as Map;
      if (frozen.containsKey(item['id']) && frozen[item['id']] != item['kind']) {
        throw const FormatException('Conflicting frozen item kind');
      }
    }
    field(value, 'unresolvedSourceIds', strings);
    if (version >= 2) {
      if (value['items'] is! List) throw const FormatException('Missing frozen items');
      final selection = value['selection'] as Map? ?? const {};
      final unresolved = (value['unresolvedSourceIds'] as List? ?? const []).toSet();
      for (final entry in selection.entries) {
        for (final id in entry.value as List) {
          if ((frozen.containsKey(id) && frozen[id] != entry.key) ||
              (!frozen.containsKey(id) && !unresolved.contains(id))) {
            throw const FormatException('A selected item has no frozen content');
          }
        }
      }
    }
    return ExamDraftSnapshot._(jsonEncode(value));
  }
}
