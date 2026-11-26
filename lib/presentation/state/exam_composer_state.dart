import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../domain/models/exam_draft_snapshot.dart';
import '../../domain/models/exam_paper.dart';
import '../../domain/models/exam_question_bank.dart';
import '../../domain/models/library.dart';
import '../../domain/repositories/exam_profile_repository.dart';
import '../../domain/services/exam_paper_formatter.dart';

/// Mutable draft of the exam paper while the teacher writes it.
class ExamComposerState extends ChangeNotifier {
  ExamComposerState({
    required Iterable<LearningUnit> units,
    required Iterable<TopicDrawing> drawings,
    required String gradeLabel,
    DateTime? now,
    ExamProfile profile = const ExamProfile(),
  }) : options = examQuestionOptions(units),
       drawings = examDrawingOptions(drawings),
       _now = now ?? DateTime.now() {
    this.gradeLabel = gradeLabel;
    schoolName = profile.schoolName;
    sectionName = profile.sectionName;
    teacherName = profile.teacherName;
    headerConfig = ExamHeaderConfig(directorateLine: profile.directorateLine);
    margins = profile.margins;
    academicYear = academicYearLabel(_now);
    final savedTypography = profile.typography;
    font = savedTypography.font;
    headerFontSize = savedTypography.headerFontSize;
    bodyFontSize = savedTypography.bodyFontSize;
    headingFontSize = savedTypography.headingFontSize;
    lineSpacingPercent = savedTypography.lineSpacingPercent;
    for (final QuestionKind kind in ExamTheoryQuestion.kinds) {
      _selected[kind] = <String>{};
      _instructions[kind] = defaultTheoryInstruction(kind, 0);
      _answerLines[kind] = ExamTheoryQuestion.defaultAnswerLineCount;
      _customizedInstructions[kind] = false;
    }
    _degrees[QuestionKind.trueFalse] = defaultTheoryQuestionDegree;
    _degrees[QuestionKind.choice] = defaultTheoryQuestionDegree;
    _degrees[QuestionKind.open] = defaultTheoryQuestionDegree;
    practical = <ExamPracticalQuestion>[
      for (var i = 0; i < practicalSlotCount; i++)
        const ExamPracticalQuestion(prompt: '', degree: defaultPracticalDegree),
    ];
  }

  static const int practicalSlotCount = 3;
  static const int maxPracticalSlots = 5;
  static const int defaultPracticalDegree = 35;

  static const int defaultTheoryDegree = 30;
  static const int defaultTheoryQuestionDegree = 15;
  static const int defaultTheoryQuestionCount = 2;
  static const int defaultPracticalTotal = 70;

  final List<ExamQuestionOption> options;
  final List<TopicDrawing> drawings;
  final DateTime _now;

  // --------------------------------------------------- typography & margins ---

  ExamPaperFont font = ExamPaperFont.traditionalArabic;
  int? headerFontSize = ExamPaperTypography.defaultHeaderFontSize;
  int? bodyFontSize = ExamPaperTypography.defaultBodyFontSize;
  int? headingFontSize = ExamPaperTypography.defaultHeadingFontSize;
  int? lineSpacingPercent = ExamPaperTypography.defaultLineSpacingPercent;
  ExamPageMargins margins = ExamPageMargins.standard;

  ExamPaperTypography? get typography {
    final header = headerFontSize;
    final body = bodyFontSize;
    final heading = headingFontSize;
    final spacing = lineSpacingPercent;
    if (!ExamPaperTypography.isValidFontSize(header) ||
        !ExamPaperTypography.isValidFontSize(body) ||
        !ExamPaperTypography.isValidFontSize(heading) ||
        !ExamPaperTypography.isValidLineSpacing(spacing)) {
      return null;
    }
    return ExamPaperTypography(
      font: font,
      headerFontSize: header!,
      bodyFontSize: body!,
      headingFontSize: heading!,
      lineSpacingPercent: spacing!,
    );
  }

  void setFont(ExamPaperFont value) {
    if (font == value) return;
    font = value;
    notifyListeners();
  }

  void setHeaderFontSize(int? value) {
    if (headerFontSize == value) return;
    headerFontSize = value;
    notifyListeners();
  }

  void setBodyFontSize(int? value) {
    if (bodyFontSize == value) return;
    bodyFontSize = value;
    notifyListeners();
  }

  void setHeadingFontSize(int? value) {
    if (headingFontSize == value) return;
    headingFontSize = value;
    notifyListeners();
  }

  void setLineSpacingPercent(int? value) {
    if (lineSpacingPercent == value) return;
    lineSpacingPercent = value;
    notifyListeners();
  }

  void resetLineSpacing() =>
      setLineSpacingPercent(ExamPaperTypography.officialLineSpacingPercent);

  void setMargins(ExamPageMargins value) {
    if (margins == value) return;
    margins = value;
    notifyListeners();
  }

  // -------------------------------------------------------- info & header ---

  String schoolName = '';
  String gradeLabel = '';
  String sectionName = '';
  String teacherName = '';
  String academicYear = '';
  ExamTerm term = ExamTerm.midYear;
  ExamRound round = ExamRound.first;
  ExamHeaderConfig headerConfig = ExamHeaderConfig.defaults;

  String get suggestedAcademicYear => academicYearLabel(_now);

  void setSchoolName(String value) {
    schoolName = value;
    notifyListeners();
  }

  void setGradeLabel(String value) {
    gradeLabel = value;
    notifyListeners();
  }

  void setSectionName(String value) {
    sectionName = value;
    notifyListeners();
  }

  void setTeacherName(String value) {
    teacherName = value;
    notifyListeners();
  }

  void setAcademicYear(String value) {
    academicYear = value;
    notifyListeners();
  }

  void setTerm(ExamTerm value) {
    if (term == value) return;
    term = value;
    notifyListeners();
  }

  void setRound(ExamRound value) {
    if (round == value) return;
    round = value;
    notifyListeners();
  }

  void updateHeaderConfig(ExamHeaderConfig value) {
    headerConfig = value;
    notifyListeners();
  }

  void resetHeaderConfig() {
    headerConfig = ExamHeaderConfig.defaults;
    notifyListeners();
  }

  // ---------------------------------------------------------------- theory ---

  final Map<QuestionKind, Set<String>> _selected = <QuestionKind, Set<String>>{};
  final Map<QuestionKind, int?> _degrees = <QuestionKind, int?>{};
  final Map<QuestionKind, String> _instructions = <QuestionKind, String>{};
  final Map<QuestionKind, int> _answerLines = <QuestionKind, int>{};
  final Map<QuestionKind, bool> _customizedInstructions = <QuestionKind, bool>{};

  int? theoryDegree = defaultTheoryDegree;
  int? practicalDegree = defaultPracticalTotal;

  String theoryHeader = ExamPaper.defaultTheoryHeader;
  String practicalHeader = ExamPaper.defaultPracticalHeader;

  List<ExamQuestionOption> optionsOf(QuestionKind kind) => <ExamQuestionOption>[
    for (final ExamQuestionOption option in options)
      if (option.question.kind == kind) option,
  ];

  Set<String> selectionOf(QuestionKind kind) =>
      Set<String>.unmodifiable(_selected[kind] ?? const <String>{});

  bool isSelected(QuestionKind kind, String id) =>
      (_selected[kind] ?? const <String>{}).contains(id);

  bool isInstructionCustomized(QuestionKind kind) =>
      _customizedInstructions[kind] ?? false;

  String instructionOf(QuestionKind kind) =>
      _instructions[kind] ??
      defaultTheoryInstruction(kind, selectionOf(kind).length);

  int? degreeOf(QuestionKind kind) => _degrees[kind];

  int answerLineCountOf(QuestionKind kind) =>
      _answerLines[kind] ?? ExamTheoryQuestion.defaultAnswerLineCount;

  void toggleItem(QuestionKind kind, String id) {
    final selection = _selected.putIfAbsent(kind, () => <String>{});
    if (!selection.remove(id)) {
      selection.add(id);
    }
    if (!isInstructionCustomized(kind)) {
      _instructions[kind] = defaultTheoryInstruction(kind, selection.length);
    }
    notifyListeners();
  }

  int _customCounter = 0;

  String _nextCustomItemId(QuestionKind kind) {
    while (true) {
      _customCounter++;
      final candidate = 'custom:${kind.name}:$_customCounter';
      if (!_frozenItems.containsKey(candidate)) {
        return candidate;
      }
    }
  }

  /// Adds a teacher-written statement, multiple-choice item, or open prompt
  /// directly to the paper's theoretical question group and selects it.
  String addCustomItem(
    QuestionKind kind, {
    required String prompt,
    List<String> options = const <String>[],
  }) {
    final trimmed = prompt.trim();
    final id = _nextCustomItemId(kind);
    final cleanOptions = kind == QuestionKind.choice
        ? List<String>.unmodifiable(
            options.map((s) => s.trim()).where((s) => s.isNotEmpty),
          )
        : const <String>[];
    final item = ExamTheoryItem(
      id: id,
      kind: kind,
      prompt: trimmed,
      options: cleanOptions,
    );
    _frozenItems[id] = item;
    final selection = _selected.putIfAbsent(kind, () => <String>{})..add(id);
    if (!isInstructionCustomized(kind)) {
      _instructions[kind] = defaultTheoryInstruction(kind, selection.length);
    }
    notifyListeners();
    return id;
  }

  /// Removes a teacher-written custom item from the draft.
  void removeCustomItem(String id) {
    if (!id.startsWith('custom:')) return;
    final removed = _frozenItems.remove(id);
    _itemOverrides.remove(id);
    for (final kind in ExamTheoryQuestion.kinds) {
      final sel = _selected[kind];
      if (sel != null && sel.remove(id) && !isInstructionCustomized(kind)) {
        _instructions[kind] = defaultTheoryInstruction(kind, sel.length);
      }
    }
    if (removed != null) {
      notifyListeners();
    }
  }

  List<ExamTheoryItem> customItemsOf(QuestionKind kind) => <ExamTheoryItem>[
    for (final ExamTheoryItem item in _frozenItems.values)
      if (item.kind == kind && item.isCustom) _itemOverrides[item.id] ?? item,
  ];

  void setDegree(QuestionKind kind, int? degree) {
    _degrees[kind] = degree;
    notifyListeners();
  }

  void setInstruction(
    QuestionKind kind,
    String instruction, {
    bool customized = true,
  }) {
    _instructions[kind] = instruction;
    _customizedInstructions[kind] = customized;
    notifyListeners();
  }

  void setAnswerLineCount(QuestionKind kind, int? count) {
    final safe = (count ?? ExamTheoryQuestion.defaultAnswerLineCount).clamp(
      1,
      ExamTheoryQuestion.maxAnswerLineCount,
    );
    _answerLines[kind] = safe;
    notifyListeners();
  }

  void setTheoryDegree(int? degree) {
    theoryDegree = degree;
    notifyListeners();
  }

  void setPracticalDegree(int? degree) {
    practicalDegree = degree;
    notifyListeners();
  }

  void setTheoryHeader(String value) {
    if (theoryHeader == value) return;
    theoryHeader = value;
    notifyListeners();
  }

  void setPracticalHeader(String value) {
    if (practicalHeader == value) return;
    practicalHeader = value;
    notifyListeners();
  }

  void resetHeaders() {
    theoryHeader = ExamPaper.defaultTheoryHeader;
    practicalHeader = ExamPaper.defaultPracticalHeader;
    notifyListeners();
  }

  List<ExamTheoryItem> selectedItems(QuestionKind kind) {
    final selection = _selected[kind] ?? const <String>{};
    final items = <String, ExamTheoryItem>{
      for (final item in _frozenItems.values)
        if (item.kind == kind && selection.contains(item.id))
          item.id: _itemOverrides[item.id] ?? item,
      for (final option in options)
        if (option.question.kind == kind &&
            selection.contains(option.id) &&
            !_frozenItems.containsKey(option.id))
          option.id:
              _itemOverrides[option.id] ??
              ExamTheoryItem.fromQuestion(option.question, id: option.id),
    };
    return List<ExamTheoryItem>.unmodifiable(items.values);
  }

  Set<String> get unresolvedSourceIds {
    return <String>{
      for (final entry in _selected.entries)
        for (final id in entry.value)
          if (_frozenItems.containsKey(id)
              ? _frozenItems[id]!.kind != entry.key
              : !options.any((o) => o.id == id && o.question.kind == entry.key))
            id,
    };
  }

  final List<String> restorationWarnings = <String>[];
  void discardUnresolvedItems() {
    final missing = unresolvedSourceIds;
    for (final ids in _selected.values) {
      ids.removeAll(missing);
    }
    notifyListeners();
  }

  ExamTheoryQuestion theoryOf(QuestionKind kind) {
    final items = selectedItems(kind);
    return ExamTheoryQuestion(
      kind: kind,
      instruction: isInstructionCustomized(kind)
          ? instructionOf(kind)
          : defaultTheoryInstruction(kind, items.length),
      degree: _degrees[kind] ?? ExamPaper.minDegree,
      items: List<ExamTheoryItem>.unmodifiable(items),
      answerLineCount: answerLineCountOf(kind),
    );
  }

  List<ExamTheoryQuestion> get theoryQuestions => <ExamTheoryQuestion>[
    for (final QuestionKind kind in ExamTheoryQuestion.kinds) theoryOf(kind),
  ];

  int get theoryItemCount => ExamTheoryQuestion.kinds.fold<int>(
    0,
    (int sum, QuestionKind kind) => sum + selectedItems(kind).length,
  );

  // --------------------------------------------------------- free questions ---

  final List<ExamFreeQuestion> _freeQuestions = <ExamFreeQuestion>[];
  int _freeCounter = 0;

  List<ExamFreeQuestion> get freeQuestions =>
      List<ExamFreeQuestion>.unmodifiable(_freeQuestions);

  String _nextFreeId() {
    while (true) {
      _freeCounter++;
      final id = 'free-$_freeCounter';
      if (_freeQuestions.every((q) => q.id != id)) {
        return id;
      }
    }
  }

  String addFreeQuestion({
    String title = '',
    int degree = ExamFreeQuestion.defaultDegree,
    String choiceNote = '',
    List<String> items = const <String>[''],
    List<ExamQuestionBranch> branches = const <ExamQuestionBranch>[],
    int answerLineCount = 0,
  }) {
    final id = _nextFreeId();
    _freeQuestions.add(
      ExamFreeQuestion(
        id: id,
        title: title,
        degree: degree,
        choiceNote: choiceNote,
        items: List<String>.unmodifiable(items),
        branches: List<ExamQuestionBranch>.unmodifiable(branches),
        answerLineCount: answerLineCount,
      ),
    );
    notifyListeners();
    return id;
  }

  /// Adds one of the common Iraqi exam templates with a single tap.
  String addTemplateFreeQuestion(String templateKey) {
    switch (templateKey) {
      case 'definitions':
        return addFreeQuestion(
          title: 'عرف ما يأتي :',
          choiceNote: 'لثلاث فقط',
          items: const <String>['', '', '', ''],
        );
      case 'blanks':
        return addFreeQuestion(
          title: 'املأ الفراغات الآتية بما يناسبها :',
          items: const <String>[
            '...........................',
            '...........................',
            '...........................',
          ],
        );
      case 'reasons':
        return addFreeQuestion(
          title: 'علل ما يأتي تعليلاً فنياً دقيقاً :',
          items: const <String>['', ''],
        );
      case 'compare':
        return addFreeQuestion(
          title: 'قارن بين كل مما يأتي :',
          items: const <String>[''],
          answerLineCount: 2,
        );
      case 'branches':
        return addFreeQuestion(
          title: 'أجب عن أحد الفرعين (أ) أو (ب) :',
          choiceNote: 'ترك فرع واحد',
          items: const <String>[],
          branches: const <ExamQuestionBranch>[
            ExamQuestionBranch(label: 'أ', prompt: 'عرف ما يأتي :', items: <String>['', '']),
            ExamQuestionBranch(label: 'ب', prompt: 'عدد ما يأتي :', items: <String>['', '']),
          ],
        );
      default:
        return addFreeQuestion(title: 'أجب عما يأتي :', items: const <String>['']);
    }
  }

  void updateFreeQuestion(int index, ExamFreeQuestion updated) {
    if (index < 0 || index >= _freeQuestions.length) return;
    _freeQuestions[index] = updated;
    notifyListeners();
  }

  void removeFreeQuestion(int index) {
    if (index < 0 || index >= _freeQuestions.length) return;
    _freeQuestions.removeAt(index);
    notifyListeners();
  }

  void moveFreeQuestion(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= _freeQuestions.length ||
        newIndex < 0 ||
        newIndex >= _freeQuestions.length ||
        oldIndex == newIndex) {
      return;
    }
    final moved = _freeQuestions.removeAt(oldIndex);
    _freeQuestions.insert(newIndex, moved);
    notifyListeners();
  }

  // ------------------------------------------------------------- practical ---

  late List<ExamPracticalQuestion> practical;

  void addPracticalSlot() {
    if (practical.length >= maxPracticalSlots) return;
    practical = <ExamPracticalQuestion>[
      ...practical,
      const ExamPracticalQuestion(prompt: '', degree: defaultPracticalDegree),
    ];
    notifyListeners();
  }

  void removePracticalSlot(int index) {
    if (practical.length <= 1 || index < 0 || index >= practical.length) return;
    final next = List<ExamPracticalQuestion>.of(practical)..removeAt(index);
    practical = next;
    notifyListeners();
  }

  void selectDrawing(int index, TopicDrawing? drawing) {
    if (index < 0 || index >= practical.length) return;
    if (drawing == null) {
      practical[index] = ExamPracticalQuestion(
        prompt: '',
        degree: practical[index].degree,
      );
    } else {
      practical[index] = ExamPracticalQuestion(
        prompt: defaultPracticalPrompt(drawing.title),
        degree: practical[index].degree,
        drawingId: drawing.id,
        drawingTitle: drawing.title,
      );
    }
    notifyListeners();
  }

  void setPracticalPrompt(int index, String prompt) {
    if (index < 0 || index >= practical.length) return;
    practical[index] = practical[index].copyWith(prompt: prompt);
    notifyListeners();
  }

  void setPracticalSlotDegree(int index, int? degree) {
    if (index < 0 || index >= practical.length) return;
    practical[index] = practical[index].copyWith(
      degree: degree ?? ExamPaper.minDegree,
    );
    notifyListeners();
  }

  int get practicalCount =>
      practical.where((ExamPracticalQuestion question) => !question.isEmpty).length;

  // ----------------------------------------------------------------- paper ---

  ExamPaper buildPaperWith(ExamPaperTypography paperTypography) {
    return ExamPaper(
      info: ExamPaperInfo(
        schoolName: schoolName,
        gradeLabel: gradeLabel,
        sectionName: sectionName,
        term: term,
        round: round,
        academicYear: academicYear,
        teacherName: teacherName,
      ),
      typography: paperTypography,
      theory: <ExamTheoryQuestion>[
        for (final ExamTheoryQuestion question in theoryQuestions)
          if (!question.isEmpty) question,
      ],
      practical: <ExamPracticalQuestion>[
        for (final ExamPracticalQuestion question in practical)
          if (!question.isEmpty) question,
      ],
      theoryDegree: theoryDegree ?? -1,
      practicalDegree: practicalDegree ?? -1,
      theoryHeader: theoryHeader,
      practicalHeader: practicalHeader,
      freeQuestions: List<ExamFreeQuestion>.unmodifiable(_freeQuestions),
      headerConfig: headerConfig,
      margins: margins,
    );
  }

  ExamPaper? get paper {
    if (unresolvedSourceIds.isNotEmpty) return null;
    final current = typography;
    if (current == null) return null;
    final built = buildPaperWith(current);
    return built.isComplete ? built : null;
  }

  List<String> get issues {
    if (unresolvedSourceIds.isNotEmpty) {
      return <String>[
        'تعذّر استعادة نصوص ${unresolvedSourceIds.length} فقرة من مسودة قديمة؛ راجعها أو أزل المراجع المفقودة صراحةً.',
      ];
    }
    final current = typography;
    if (current == null) {
      if (!ExamPaperTypography.isValidLineSpacing(lineSpacingPercent)) {
        if (ExamPaperTypography.isValidFontSize(headerFontSize) &&
            ExamPaperTypography.isValidFontSize(bodyFontSize) &&
            ExamPaperTypography.isValidFontSize(headingFontSize)) {
          return const <String>[ExamPaper.invalidLineSpacing];
        }
      }
      return const <String>[ExamPaper.invalidFontSizes];
    }
    return buildPaperWith(current).issues;
  }

  final Map<String, ExamTheoryItem> _frozenItems = <String, ExamTheoryItem>{};
  final Map<String, ExamTheoryItem> _itemOverrides = <String, ExamTheoryItem>{};

  void editItem(ExamTheoryItem item) {
    if (!options.any((option) => option.id == item.id && option.question.kind == item.kind) &&
        _frozenItems[item.id]?.kind != item.kind) {
      return;
    }
    _itemOverrides[item.id] = ExamTheoryItem(
      id: item.id,
      kind: item.kind,
      prompt: item.prompt,
      options: List<String>.unmodifiable(item.options),
    );
    notifyListeners();
  }

  void selectItems(QuestionKind kind, Iterable<String> ids, {bool replace = false}) {
    final known = optionsOf(kind).map((option) => option.id).toSet();
    final selection = _selected.putIfAbsent(kind, () => <String>{});
    if (replace) selection.clear();
    selection.addAll(
      ids.where((id) => known.contains(id) || _frozenItems[id]?.kind == kind),
    );
    if (!isInstructionCustomized(kind)) {
      _instructions[kind] = defaultTheoryInstruction(kind, selection.length);
    }
    notifyListeners();
  }

  void generateBalancedExam({Set<String>? unitIds, Random? random, int perKind = 5}) {
    final rng = random ?? Random();
    _itemOverrides.clear();
    _frozenItems.clear();
    for (final kind in ExamTheoryQuestion.kinds) {
      final pool =
          optionsOf(kind)
              .where((option) => unitIds == null || unitIds.contains(option.unitId))
              .toList()
            ..shuffle(rng);
      _selected[kind] = pool.take(perKind).map((option) => option.id).toSet();
      _customizedInstructions[kind] = false;
      _instructions[kind] = defaultTheoryInstruction(kind, _selected[kind]!.length);
    }
    final pool =
        drawings.where((drawing) => unitIds == null || unitIds.contains(drawing.unitId)).toList()
          ..shuffle(rng);
    for (var i = 0; i < practical.length; i++) {
      if (i < pool.length) {
        practical[i] = ExamPracticalQuestion(
          prompt: defaultPracticalPrompt(pool[i].title),
          degree: practical[i].degree,
          drawingId: pool[i].id,
          drawingTitle: pool[i].title,
        );
      } else {
        practical[i] = ExamPracticalQuestion(prompt: '', degree: practical[i].degree);
      }
    }
    notifyListeners();
  }

  Map<String, dynamic> toDraft() => <String, dynamic>{
    'version': ExamDraftSnapshot.currentVersion,
    if (restorationWarnings.isNotEmpty)
      'restorationWarnings': List<String>.of(restorationWarnings),
    'schoolName': schoolName,
    'gradeLabel': gradeLabel,
    'sectionName': sectionName,
    'teacherName': teacherName,
    'academicYear': academicYear,
    'term': term.name,
    'round': round.name,
    'font': font.name,
    'headerFontSize': headerFontSize,
    'bodyFontSize': bodyFontSize,
    'headingFontSize': headingFontSize,
    'lineSpacingPercent': lineSpacingPercent,
    'theoryDegree': theoryDegree,
    'practicalDegree': practicalDegree,
    'theoryHeader': theoryHeader,
    'practicalHeader': practicalHeader,
    'headerConfig': headerConfig.toJson(),
    'margins': margins.toJson(),
    'freeQuestions': <Map<String, dynamic>>[
      for (final ExamFreeQuestion fq in _freeQuestions) fq.toJson(),
    ],
    'items': <Map<String, dynamic>>[
      for (final item in <String, ExamTheoryItem>{
        for (final kind in ExamTheoryQuestion.kinds)
          for (final item in selectedItems(kind)) item.id: item,
        for (final item in _frozenItems.values)
          if (!isSelected(item.kind, item.id)) item.id: _itemOverrides[item.id] ?? item,
        for (final item in _itemOverrides.values)
          if (!isSelected(item.kind, item.id)) item.id: item,
      }.values)
        <String, dynamic>{
          'id': item.id,
          'kind': item.kind.name,
          'prompt': item.prompt,
          'options': List<String>.of(item.options),
        },
    ],
    'unresolvedSourceIds': unresolvedSourceIds.toList(),
    'selection': <String, dynamic>{
      for (final kind in ExamTheoryQuestion.kinds) kind.name: selectionOf(kind).toList(),
    },
    'instructions': <String, dynamic>{
      for (final kind in ExamTheoryQuestion.kinds) kind.name: instructionOf(kind),
    },
    'degrees': <String, dynamic>{
      for (final kind in ExamTheoryQuestion.kinds) kind.name: degreeOf(kind),
    },
    'customized': <String, dynamic>{
      for (final kind in ExamTheoryQuestion.kinds)
        kind.name: isInstructionCustomized(kind),
    },
    'answerLines': <String, dynamic>{
      for (final kind in ExamTheoryQuestion.kinds) kind.name: answerLineCountOf(kind),
    },
    'practical': <dynamic>[
      for (final q in practical)
        <String, dynamic>{
          'prompt': q.prompt,
          'degree': q.degree,
          'drawingId': q.drawingId,
          'drawingTitle': q.drawingTitle,
        },
    ],
    'overrides': <dynamic>[
      for (final item in _itemOverrides.values)
        <String, dynamic>{
          'id': item.id,
          'kind': item.kind.name,
          'prompt': item.prompt,
          'options': item.options,
        },
    ],
  };

  void restoreDraft(Map<String, dynamic> rawDraft) {
    final snapshot = ExamDraftSnapshot.decode(rawDraft);
    final draft = snapshot.toJson();
    final frozen = <String, ExamTheoryItem>{};
    for (final raw in (draft['items'] as List? ?? const <dynamic>[])) {
      final item = raw as Map;
      frozen[item['id'] as String] = ExamTheoryItem(
        id: item['id'] as String,
        kind: QuestionKind.values.firstWhere((v) => v.name == item['kind']),
        prompt: item['prompt'] as String,
        options: List<String>.unmodifiable(
          item['options'] as List? ?? const <String>[],
        ),
      );
    }
    _frozenItems
      ..clear()
      ..addAll(frozen);
    restorationWarnings
      ..clear()
      ..addAll(List<String>.from(draft['restorationWarnings'] as List? ?? const []));
    if (snapshot.version == 1) {
      restorationWarnings.add(
        'مسودة قديمة: استُعيدت النصوص المتاحة من المنهج الحالي؛ لم تكن النسخة القديمة تحفظ نصاً مستقلاً لكل سؤال.',
      );
    }
    String text(String key, String fallback) =>
        draft[key] is String ? draft[key] as String : fallback;
    int? number(String key, int? fallback) =>
        draft.containsKey(key) ? (draft[key] as num?)?.toInt() : fallback;
    Map<String, dynamic> map(String key) => draft[key] is Map
        ? Map<String, dynamic>.from(draft[key] as Map)
        : <String, dynamic>{};

    schoolName = text('schoolName', schoolName);
    gradeLabel = text('gradeLabel', gradeLabel);
    sectionName = text('sectionName', sectionName);
    teacherName = text('teacherName', teacherName);
    academicYear = text('academicYear', academicYear);
    term = ExamTerm.values.where((v) => v.name == draft['term']).firstOrNull ?? term;
    round = ExamRound.values.where((v) => v.name == draft['round']).firstOrNull ?? round;
    font = ExamPaperFont.values.where((v) => v.name == draft['font']).firstOrNull ?? font;
    headerFontSize = number('headerFontSize', headerFontSize);
    bodyFontSize = number('bodyFontSize', bodyFontSize);
    headingFontSize = number('headingFontSize', headingFontSize);
    lineSpacingPercent = number('lineSpacingPercent', lineSpacingPercent);
    theoryDegree = number('theoryDegree', theoryDegree);
    practicalDegree = number('practicalDegree', practicalDegree);
    theoryHeader = text('theoryHeader', theoryHeader);
    practicalHeader = text('practicalHeader', practicalHeader);

    if (draft['headerConfig'] is Map) {
      headerConfig = ExamHeaderConfig.fromJson(
        Map<String, dynamic>.from(draft['headerConfig'] as Map),
      );
    } else {
      headerConfig = ExamHeaderConfig.defaults;
    }

    if (draft['margins'] is Map) {
      margins = ExamPageMargins.fromJson(
        Map<String, dynamic>.from(draft['margins'] as Map),
      );
    } else {
      margins = ExamPageMargins.standard;
    }

    _freeQuestions.clear();
    final rawFree = draft['freeQuestions'];
    if (rawFree is List) {
      for (final dynamic item in rawFree) {
        if (item is Map) {
          _freeQuestions.add(
            ExamFreeQuestion.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    for (final kind in ExamTheoryQuestion.kinds) {
      final ids = map('selection')[kind.name];
      _selected[kind] = ids is List ? ids.whereType<String>().toSet() : <String>{};
      _instructions[kind] =
          map('instructions')[kind.name] as String? ??
          defaultTheoryInstruction(kind, _selected[kind]!.length);
      _degrees[kind] = (map('degrees')[kind.name] as num?)?.toInt();
      _customizedInstructions[kind] = map('customized')[kind.name] == true;
      _answerLines[kind] =
          ((map('answerLines')[kind.name] as num?)?.toInt() ??
                  ExamTheoryQuestion.defaultAnswerLineCount)
              .clamp(1, ExamTheoryQuestion.maxAnswerLineCount);
    }

    final slots = draft['practical'];
    if (slots is List) {
      final slotCount = max(practicalSlotCount, min(maxPracticalSlots, slots.length));
      practical = List<ExamPracticalQuestion>.generate(
        slotCount,
        (_) => const ExamPracticalQuestion(prompt: '', degree: defaultPracticalDegree),
      );
      for (var i = 0; i < practical.length && i < slots.length; i++) {
        final q = Map<String, dynamic>.from(slots[i] as Map);
        practical[i] = ExamPracticalQuestion(
          prompt: q['prompt'] as String? ?? '',
          degree: (q['degree'] as num?)?.toInt() ?? 0,
          drawingId: q['drawingId'] as String?,
          drawingTitle: q['drawingTitle'] as String?,
        );
      }
    } else {
      practical = List<ExamPracticalQuestion>.generate(
        practicalSlotCount,
        (_) => const ExamPracticalQuestion(prompt: '', degree: defaultPracticalDegree),
      );
    }

    _itemOverrides.clear();
    final overrides = draft['overrides'];
    if (overrides is List) {
      for (final raw in overrides.whereType<Map>()) {
        final id = raw['id'] as String;
        final kind = QuestionKind.values.firstWhere((v) => v.name == raw['kind']);
        _itemOverrides[id] = ExamTheoryItem(
          id: id,
          kind: kind,
          prompt: raw['prompt'] as String,
          options: List<String>.unmodifiable(
            raw['options'] as List? ?? const <String>[],
          ),
        );
      }
    }
    for (final option in options) {
      if (isSelected(option.question.kind, option.id)) {
        _frozenItems.putIfAbsent(
          option.id,
          () =>
              _itemOverrides[option.id] ??
              ExamTheoryItem.fromQuestion(option.question, id: option.id),
        );
      }
    }
    for (final item in _itemOverrides.values) {
      _frozenItems.putIfAbsent(item.id, () => item);
    }
    for (final kind in ExamTheoryQuestion.kinds) {
      for (final item in selectedItems(kind)) {
        _frozenItems.putIfAbsent(item.id, () => item);
      }
    }
    notifyListeners();
  }

  // ----------------------------------------------------------- question bank ---

  ExamQuestionBankEntry toBankEntry({
    required String id,
    required String title,
    DateTime? savedAt,
  }) {
    return ExamQuestionBankEntry(
      id: id,
      title: title,
      savedAt: savedAt ?? DateTime.now(),
      contentSnapshot: ExamDraftSnapshot.decode(toDraft()),
      selection: <String, List<String>>{
        for (final QuestionKind kind in ExamTheoryQuestion.kinds)
          if (selectionOf(kind).isNotEmpty)
            kind.name: selectionOf(kind).toList(growable: false),
      },
      practicalPrompts: <String>[
        for (final ExamPracticalQuestion question in practical)
          if (!question.isEmpty) question.prompt.trim(),
      ],
      theoryDegree: theoryDegree ?? ExamQuestionBankEntry.defaultTheoryDegree,
      practicalDegree:
          practicalDegree ?? ExamQuestionBankEntry.defaultPracticalDegree,
      theoryHeader: theoryHeader,
      practicalHeader: practicalHeader,
    );
  }

  void applyBankEntry(ExamQuestionBankEntry entry) {
    if (entry.contentDraft != null) {
      final merged = toDraft();
      final content = entry.contentDraft!;
      final known = options.map((option) => option.id).toSet();
      final selected = content['selection'] as Map? ?? const {};
      final hasForeignCurriculumId = selected.values
          .expand((ids) => ids as List)
          .any((id) => id is String && !id.startsWith('custom:') && !known.contains(id));
      if (hasForeignCurriculumId) {
        throw const FormatException(
          'هذه المجموعة تتضمن أسئلة من صف آخر أو منهج غير متاح؛ لم تتغير الورقة.',
        );
      }
      for (final key in <String>[
        'items',
        'selection',
        'unresolvedSourceIds',
        'instructions',
        'degrees',
        'customized',
        'answerLines',
        'freeQuestions',
        'practical',
        'overrides',
        'theoryDegree',
        'practicalDegree',
        'theoryHeader',
        'practicalHeader',
      ]) {
        if (content.containsKey(key)) merged[key] = content[key];
      }
      restoreDraft(merged);
      return;
    }
    if (entry.practicalPrompts.length > maxPracticalSlots) {
      throw const FormatException(
        'المجموعة تتجاوز عدد الفقرات العملية المدعوم؛ لم تتغير الورقة.',
      );
    }
    restorationWarnings
      ..clear()
      ..add(
        'مجموعة قديمة: استُعيدت الاختيارات من المنهج الحالي؛ لم تكن هذه المجموعة تحفظ النصوص والتعديلات مستقلةً.',
      );
    _itemOverrides.clear();
    _frozenItems.clear();
    _freeQuestions.clear();
    for (final QuestionKind kind in ExamTheoryQuestion.kinds) {
      _selected[kind] = <String>{
        ...entry.selection[kind.name] ?? const <String>[],
      };
      _customizedInstructions[kind] = false;
      _instructions[kind] = defaultTheoryInstruction(kind, _selected[kind]!.length);
      _degrees[kind] = defaultTheoryQuestionDegree;
      _answerLines[kind] = ExamTheoryQuestion.defaultAnswerLineCount;
    }
    for (var i = 0; i < practical.length; i++) {
      final prompt = i < entry.practicalPrompts.length ? entry.practicalPrompts[i] : '';
      practical[i] = ExamPracticalQuestion(prompt: prompt, degree: practical[i].degree);
    }
    theoryDegree = entry.theoryDegree;
    practicalDegree = entry.practicalDegree;
    theoryHeader = entry.theoryHeader;
    practicalHeader = entry.practicalHeader;
    notifyListeners();
  }

  ExamProfile toProfile() {
    final current = typography ?? const ExamPaperTypography();
    return ExamProfile(
      schoolName: schoolName,
      gradeLabel: gradeLabel,
      sectionName: sectionName,
      teacherName: teacherName,
      directorateLine: headerConfig.directorateLine,
      typography: current,
      margins: margins,
    );
  }
}
