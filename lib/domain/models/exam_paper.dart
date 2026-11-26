/// Models of the exam paper written in the application and exported to a Word
/// file or A4 PNG sheets.
///
/// The document structure follows the official Iraqi middle-school art exam
/// layout (`الاول.docx`) while supporting customizable header lines, page
/// margins, custom bank items, and free-form questions with branches (أ / ب).
library;

import '../../core/utils/arabic_text.dart';
import 'library.dart';

/// Word-safe Arabic typefaces offered for the exported document, paired with
/// their bundled Flutter preview font family.
enum ExamPaperFont {
  traditionalArabic('Traditional Arabic', 'تقليدي', 'Amiri'),
  simplifiedArabic('Simplified Arabic', 'مبسّط', 'Tajawal'),
  sakkalMajalla('Sakkal Majalla', 'سكّال مجلّة', 'Amiri'),
  arial('Arial', 'آريال', 'Almarai'),
  timesNewRoman('Times New Roman', 'تايمز نيو رومان', 'Amiri'),
  amiri('Amiri', 'أميري', 'Amiri'),
  cairo('Cairo', 'القاهرة', 'Cairo'),
  tajawal('Tajawal', 'تجوال', 'Tajawal'),
  almarai('Almarai', 'المراعي', 'Almarai');

  const ExamPaperFont(this.family, this.label, this.previewFamily);

  /// The family name written into the DOCX run properties.
  final String family;

  /// Arabic label in the composer.
  final String label;

  /// Bundled Flutter font family used in the live A4 preview.
  final String previewFamily;
}

/// Page margins of the A4 exam sheet in OpenXML twips (1 inch = 1440 twips,
/// 1 logical px at 794×1123 A4 = 15 twips).
class ExamPageMargins {
  const ExamPageMargins({
    this.topTwips = defaultTopTwips,
    this.rightTwips = defaultSideTwips,
    this.bottomTwips = defaultSideTwips,
    this.leftTwips = defaultSideTwips,
  });

  static const int defaultTopTwips = 426;
  static const int defaultSideTwips = 720;
  static const int minTwips = 240;
  static const int maxTwips = 1440;

  static const ExamPageMargins compact = ExamPageMargins(
    topTwips: 360,
    rightTwips: 510,
    bottomTwips: 510,
    leftTwips: 510,
  );

  static const ExamPageMargins standard = ExamPageMargins();

  static const ExamPageMargins comfortable = ExamPageMargins(
    topTwips: 720,
    rightTwips: 960,
    bottomTwips: 900,
    leftTwips: 960,
  );

  final int topTwips;
  final int rightTwips;
  final int bottomTwips;
  final int leftTwips;

  static bool isValidTwips(int? value) =>
      value != null && value >= minTwips && value <= maxTwips;

  bool get isValid =>
      isValidTwips(topTwips) &&
      isValidTwips(rightTwips) &&
      isValidTwips(bottomTwips) &&
      isValidTwips(leftTwips);

  double get topPx => topTwips / 15.0;
  double get rightPx => rightTwips / 15.0;
  double get bottomPx => bottomTwips / 15.0;
  double get leftPx => leftTwips / 15.0;

  String get presetName {
    if (this == compact) return 'compact';
    if (this == comfortable) return 'comfortable';
    if (this == standard) return 'standard';
    return 'custom';
  }

  ExamPageMargins copyWith({
    int? topTwips,
    int? rightTwips,
    int? bottomTwips,
    int? leftTwips,
  }) {
    return ExamPageMargins(
      topTwips: topTwips ?? this.topTwips,
      rightTwips: rightTwips ?? this.rightTwips,
      bottomTwips: bottomTwips ?? this.bottomTwips,
      leftTwips: leftTwips ?? this.leftTwips,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'topTwips': topTwips,
    'rightTwips': rightTwips,
    'bottomTwips': bottomTwips,
    'leftTwips': leftTwips,
  };

  factory ExamPageMargins.fromJson(Map<String, dynamic>? json) {
    if (json == null) return standard;
    int clampOrDefault(Object? raw, int fallback) {
      final parsed = raw is int ? raw : int.tryParse('${raw ?? ''}');
      if (parsed == null) return fallback;
      return parsed.clamp(minTwips, maxTwips);
    }

    return ExamPageMargins(
      topTwips: clampOrDefault(json['topTwips'], defaultTopTwips),
      rightTwips: clampOrDefault(json['rightTwips'], defaultSideTwips),
      bottomTwips: clampOrDefault(json['bottomTwips'], defaultSideTwips),
      leftTwips: clampOrDefault(json['leftTwips'], defaultSideTwips),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ExamPageMargins &&
      other.topTwips == topTwips &&
      other.rightTwips == rightTwips &&
      other.bottomTwips == bottomTwips &&
      other.leftTwips == leftTwips;

  @override
  int get hashCode => Object.hash(topTwips, rightTwips, bottomTwips, leftTwips);
}

/// Optional customization of the official three-column header, score table,
/// and closing signoff. Defaults match `الاول.docx` verbatim.
class ExamHeaderConfig {
  const ExamHeaderConfig({
    this.directorateLine = '',
    this.administrationLabel = defaultAdministrationLabel,
    this.subjectName = defaultSubjectName,
    this.customExamTitle = '',
    this.examDuration = '',
    this.paperNote = '',
    this.closingWish = defaultClosingWish,
    this.teacherTitle = defaultTeacherTitle,
    this.showStudentFields = true,
    this.showScoreTable = true,
  });

  static const String defaultAdministrationLabel = 'ادارة';
  static const String defaultSubjectName = 'التربية الفنية';
  static const String defaultClosingWish = 'تمنياتي لكم بالتوفيق والنجاح';
  static const String defaultTeacherTitle = 'مدرس المادة';

  static const ExamHeaderConfig defaults = ExamHeaderConfig();

  /// Optional top line above `ادارة` (e.g. `المديرية العامة لتربية بابل`).
  final String directorateLine;

  /// Label above the school name (`ادارة` by default).
  final String administrationLabel;

  /// Subject line printed in the center cell (`التربية الفنية` by default).
  final String subjectName;

  /// Optional custom exam title overriding `term.documentTitle`.
  final String customExamTitle;

  /// Optional exam duration printed in the left cell (`الزمن : ساعتان`).
  final String examDuration;

  /// Optional note printed centered below the header rule.
  final String paperNote;

  /// Closing wish printed in the footer (`تمنياتي لكم بالتوفيق والنجاح`).
  final String closingWish;

  /// Teacher role title printed above the teacher's name (`مدرس المادة`).
  final String teacherTitle;

  /// Whether `الاسم :` and `الرقم الامتحاني :` appear in the student column.
  final bool showStudentFields;

  /// Whether the 9-row correction/score table is printed under the header.
  final bool showScoreTable;

  String get effectiveAdministrationLabel =>
      administrationLabel.trim().isEmpty ? defaultAdministrationLabel : administrationLabel.trim();

  String get effectiveSubjectName =>
      subjectName.trim().isEmpty ? defaultSubjectName : subjectName.trim();

  String get effectiveClosingWish =>
      closingWish.trim().isEmpty ? defaultClosingWish : closingWish.trim();

  String get effectiveTeacherTitle =>
      teacherTitle.trim().isEmpty ? defaultTeacherTitle : teacherTitle.trim();

  ExamHeaderConfig copyWith({
    String? directorateLine,
    String? administrationLabel,
    String? subjectName,
    String? customExamTitle,
    String? examDuration,
    String? paperNote,
    String? closingWish,
    String? teacherTitle,
    bool? showStudentFields,
    bool? showScoreTable,
  }) {
    return ExamHeaderConfig(
      directorateLine: directorateLine ?? this.directorateLine,
      administrationLabel: administrationLabel ?? this.administrationLabel,
      subjectName: subjectName ?? this.subjectName,
      customExamTitle: customExamTitle ?? this.customExamTitle,
      examDuration: examDuration ?? this.examDuration,
      paperNote: paperNote ?? this.paperNote,
      closingWish: closingWish ?? this.closingWish,
      teacherTitle: teacherTitle ?? this.teacherTitle,
      showStudentFields: showStudentFields ?? this.showStudentFields,
      showScoreTable: showScoreTable ?? this.showScoreTable,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'directorateLine': directorateLine,
    'administrationLabel': administrationLabel,
    'subjectName': subjectName,
    'customExamTitle': customExamTitle,
    'examDuration': examDuration,
    'paperNote': paperNote,
    'closingWish': closingWish,
    'teacherTitle': teacherTitle,
    'showStudentFields': showStudentFields,
    'showScoreTable': showScoreTable,
  };

  factory ExamHeaderConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaults;
    String str(String key, String fallback) =>
        json[key] is String ? json[key] as String : fallback;
    bool flag(String key, bool fallback) =>
        json[key] is bool ? json[key] as bool : fallback;
    return ExamHeaderConfig(
      directorateLine: str('directorateLine', ''),
      administrationLabel: str('administrationLabel', defaultAdministrationLabel),
      subjectName: str('subjectName', defaultSubjectName),
      customExamTitle: str('customExamTitle', ''),
      examDuration: str('examDuration', ''),
      paperNote: str('paperNote', ''),
      closingWish: str('closingWish', defaultClosingWish),
      teacherTitle: str('teacherTitle', defaultTeacherTitle),
      showStudentFields: flag('showStudentFields', true),
      showScoreTable: flag('showScoreTable', true),
    );
  }
}

/// Typography of the exported paper, in points.
class ExamPaperTypography {
  const ExamPaperTypography({
    this.font = ExamPaperFont.traditionalArabic,
    this.headerFontSize = defaultHeaderFontSize,
    this.bodyFontSize = defaultBodyFontSize,
    this.headingFontSize = defaultHeadingFontSize,
    this.lineSpacingPercent = defaultLineSpacingPercent,
  });

  static const int defaultHeaderFontSize = 12;
  static const int defaultBodyFontSize = 14;
  static const int defaultHeadingFontSize = 16;
  static const int minFontSize = 8;
  static const int maxFontSize = 32;

  static const int officialLineSpacingPercent = 100;
  static const int defaultLineSpacingPercent = 55;
  static const int minLineSpacingPercent = 50;
  static const int maxLineSpacingPercent = 200;
  static const int baseLineTwips = 360;

  final ExamPaperFont font;
  final int headerFontSize;
  final int bodyFontSize;
  final int headingFontSize;
  final int lineSpacingPercent;

  static bool isValidFontSize(int? size) =>
      size != null && size >= minFontSize && size <= maxFontSize;

  static bool isValidLineSpacing(int? percent) =>
      percent != null &&
      percent >= minLineSpacingPercent &&
      percent <= maxLineSpacingPercent;

  bool get isValid =>
      isValidFontSize(headerFontSize) &&
      isValidFontSize(bodyFontSize) &&
      isValidFontSize(headingFontSize) &&
      isValidLineSpacing(lineSpacingPercent);

  int get headerHalfPoints => headerFontSize * 2;
  int get bodyHalfPoints => bodyFontSize * 2;
  int get headingHalfPoints => headingFontSize * 2;

  int get lineTwips => (baseLineTwips * lineSpacingPercent / 100).round();

  bool get usesDefaultLineSpacing =>
      lineSpacingPercent == officialLineSpacingPercent;

  int get ruleHalfPoints =>
      (headingFontSize + 2).clamp(minFontSize, maxFontSize) * 2;

  ExamPaperTypography copyWith({
    ExamPaperFont? font,
    int? headerFontSize,
    int? bodyFontSize,
    int? headingFontSize,
    int? lineSpacingPercent,
  }) {
    return ExamPaperTypography(
      font: font ?? this.font,
      headerFontSize: headerFontSize ?? this.headerFontSize,
      bodyFontSize: bodyFontSize ?? this.bodyFontSize,
      headingFontSize: headingFontSize ?? this.headingFontSize,
      lineSpacingPercent: lineSpacingPercent ?? this.lineSpacingPercent,
    );
  }
}

/// Which exam of the school year is being written.
enum ExamTerm {
  firstSemester('الفصل الأول', 'اسئلة امتحانات الفصل الأول'),
  midYear('نصف السنة', 'اسئلة امتحانات نصف السنة'),
  secondSemester('الفصل الثاني', 'اسئلة امتحانات الفصل الثاني'),
  endOfYear('آخر السنة', 'اسئلة امتحانات نهاية السنة'),
  monthly('شهري', 'اسئلة الامتحان الشهري');

  const ExamTerm(this.label, this.documentTitle);

  final String label;
  final String documentTitle;
}

/// The round of the exam, printed next to the exam title.
enum ExamRound {
  first('الدور الأول'),
  second('الدور الثاني'),
  third('الدور الثالث');

  const ExamRound(this.label);

  final String label;
}

/// The written fields of the header and of the closing line.
class ExamPaperInfo {
  const ExamPaperInfo({
    required this.schoolName,
    required this.gradeLabel,
    required this.sectionName,
    required this.term,
    required this.round,
    required this.academicYear,
    required this.teacherName,
  });

  final String schoolName;
  final String gradeLabel;
  final String sectionName;
  final ExamTerm term;
  final ExamRound round;
  final String academicYear;
  final String teacherName;

  String get school => schoolName.trim();

  String get classLine {
    final grade = gradeLabel.trim();
    final section = sectionName.trim();
    if (section.isEmpty) {
      return 'الصف : $grade / الشعبة :';
    }
    return 'الصف : $grade / الشعبة : $section';
  }

  String get examTitleLine => '${term.documentTitle} / ${round.label}';

  String examTitleLineWith(ExamHeaderConfig config) {
    final custom = config.customExamTitle.trim();
    if (custom.isNotEmpty) {
      return custom;
    }
    return examTitleLine;
  }

  String get yearLine => 'للعام الدراسي ${academicYear.trim()}';

  List<String> get missingFields {
    return <String>[
      if (school.isEmpty) missingSchool,
      if (gradeLabel.trim().isEmpty) missingGrade,
      if (academicYear.trim().isEmpty) missingYear,
      if (teacherName.trim().isEmpty) missingTeacher,
    ];
  }

  bool get isComplete => missingFields.isEmpty;

  ExamPaperInfo copyWith({
    String? schoolName,
    String? gradeLabel,
    String? sectionName,
    ExamTerm? term,
    ExamRound? round,
    String? academicYear,
    String? teacherName,
  }) {
    return ExamPaperInfo(
      schoolName: schoolName ?? this.schoolName,
      gradeLabel: gradeLabel ?? this.gradeLabel,
      sectionName: sectionName ?? this.sectionName,
      term: term ?? this.term,
      round: round ?? this.round,
      academicYear: academicYear ?? this.academicYear,
      teacherName: teacherName ?? this.teacherName,
    );
  }

  static const String missingSchool = 'أدخل اسم المدرسة';
  static const String missingGrade = 'أدخل الصف';
  static const String missingYear = 'أدخل السنة الدراسية';
  static const String missingTeacher = 'أدخل اسم المدرس';
}

/// One statement or question taken from curriculum or written as a custom item.
class ExamTheoryItem {
  const ExamTheoryItem({
    required this.id,
    required this.kind,
    required this.prompt,
    this.options = const <String>[],
  });

  final String id;
  final QuestionKind kind;
  final String prompt;
  final List<String> options;

  bool get isCustom => id.startsWith('custom:');

  factory ExamTheoryItem.fromQuestion(Question question, {String? id}) {
    return ExamTheoryItem(
      id: id ?? question.id,
      kind: question.kind,
      prompt: question.prompt,
      options: List<String>.unmodifiable(question.options),
    );
  }
}

/// One of the three structured theoretical question groups of the paper.
class ExamTheoryQuestion {
  const ExamTheoryQuestion({
    required this.kind,
    required this.instruction,
    required this.degree,
    required this.items,
    this.answerLineCount = defaultAnswerLineCount,
  });

  static const int defaultAnswerLineCount = 2;
  static const int maxAnswerLineCount = 6;

  final QuestionKind kind;
  final String instruction;
  final int degree;
  final List<ExamTheoryItem> items;
  final int answerLineCount;

  bool get isEmpty => items.isEmpty;

  ExamTheoryQuestion copyWith({
    String? instruction,
    int? degree,
    List<ExamTheoryItem>? items,
    int? answerLineCount,
  }) {
    return ExamTheoryQuestion(
      kind: kind,
      instruction: instruction ?? this.instruction,
      degree: degree ?? this.degree,
      items: items ?? this.items,
      answerLineCount: answerLineCount ?? this.answerLineCount,
    );
  }

  static const List<QuestionKind> kinds = <QuestionKind>[
    QuestionKind.trueFalse,
    QuestionKind.choice,
    QuestionKind.open,
  ];
}

/// A sub-branch (e.g. فرع أ / فرع ب / فرع ج) inside a free-form question.
class ExamQuestionBranch {
  const ExamQuestionBranch({
    required this.label,
    this.prompt = '',
    this.items = const <String>[],
    this.degree,
  });

  static const List<String> arabicBranchLabels = <String>['أ', 'ب', 'ج', 'د'];

  final String label;
  final String prompt;
  final List<String> items;
  final int? degree;

  List<String> get nonEmptyItems => <String>[
    for (final String item in items)
      if (item.trim().isNotEmpty) item.trim(),
  ];

  bool get hasContent => prompt.trim().isNotEmpty || nonEmptyItems.isNotEmpty;

  ExamQuestionBranch copyWith({
    String? label,
    String? prompt,
    List<String>? items,
    int? degree,
    bool clearDegree = false,
  }) {
    return ExamQuestionBranch(
      label: label ?? this.label,
      prompt: prompt ?? this.prompt,
      items: items ?? this.items,
      degree: clearDegree ? null : (degree ?? this.degree),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'label': label,
    'prompt': prompt,
    'items': List<String>.of(items),
    'degree': degree,
  };

  factory ExamQuestionBranch.fromJson(Map<String, dynamic> json) {
    return ExamQuestionBranch(
      label: json['label'] as String? ?? 'أ',
      prompt: json['prompt'] as String? ?? '',
      items: List<String>.unmodifiable(
        (json['items'] as List? ?? const <dynamic>[]).whereType<String>(),
      ),
      degree: (json['degree'] as num?)?.toInt(),
    );
  }
}

/// A teacher-authored free-form question (definitions, fill-in-the-blanks,
/// reasoning, comparisons, or multi-branch أ/ب questions with optional blank
/// answer lines).
class ExamFreeQuestion {
  const ExamFreeQuestion({
    required this.id,
    required this.title,
    this.degree = defaultDegree,
    this.choiceNote = '',
    this.items = const <String>[],
    this.branches = const <ExamQuestionBranch>[],
    this.answerLineCount = 0,
  });

  static const int defaultDegree = 15;
  static const int maxAnswerLines = 6;

  final String id;

  /// Main prompt/instruction, e.g. `عرف ما يأتي :` or `أجب عن أحد الفرعين :`.
  final String title;

  /// Question degree printed next to its heading.
  final int degree;

  /// Optional sub-instruction, e.g. `الإجابة عن خمس فقرات فقط`.
  final String choiceNote;

  /// Direct numbered items (`1- ...`, `2- ...`) when not split into branches.
  final List<String> items;

  /// Optional branches (`فرع أ`, `فرع ب`, ...).
  final List<ExamQuestionBranch> branches;

  /// Optional blank dotted answer lines printed under the question (`0..6`).
  final int answerLineCount;

  List<String> get nonEmptyItems => <String>[
    for (final String item in items)
      if (item.trim().isNotEmpty) item.trim(),
  ];

  List<ExamQuestionBranch> get activeBranches => <ExamQuestionBranch>[
    for (final ExamQuestionBranch branch in branches)
      if (branch.hasContent) branch,
  ];

  bool get hasContent =>
      title.trim().isNotEmpty ||
      nonEmptyItems.isNotEmpty ||
      activeBranches.isNotEmpty;

  ExamFreeQuestion copyWith({
    String? id,
    String? title,
    int? degree,
    String? choiceNote,
    List<String>? items,
    List<ExamQuestionBranch>? branches,
    int? answerLineCount,
  }) {
    return ExamFreeQuestion(
      id: id ?? this.id,
      title: title ?? this.title,
      degree: degree ?? this.degree,
      choiceNote: choiceNote ?? this.choiceNote,
      items: items ?? this.items,
      branches: branches ?? this.branches,
      answerLineCount: (answerLineCount ?? this.answerLineCount).clamp(
        0,
        maxAnswerLines,
      ),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'degree': degree,
    'choiceNote': choiceNote,
    'items': List<String>.of(items),
    'branches': <Map<String, dynamic>>[
      for (final ExamQuestionBranch b in branches) b.toJson(),
    ],
    'answerLineCount': answerLineCount,
  };

  factory ExamFreeQuestion.fromJson(Map<String, dynamic> json) {
    return ExamFreeQuestion(
      id: json['id'] as String? ?? 'free-1',
      title: json['title'] as String? ?? '',
      degree: (json['degree'] as num?)?.toInt() ?? defaultDegree,
      choiceNote: json['choiceNote'] as String? ?? '',
      items: List<String>.unmodifiable(
        (json['items'] as List? ?? const <dynamic>[]).whereType<String>(),
      ),
      branches: List<ExamQuestionBranch>.unmodifiable(<ExamQuestionBranch>[
        for (final dynamic raw in (json['branches'] as List? ?? const <dynamic>[]))
          if (raw is Map)
            ExamQuestionBranch.fromJson(Map<String, dynamic>.from(raw)),
      ]),
      answerLineCount: ((json['answerLineCount'] as num?)?.toInt() ?? 0).clamp(
        0,
        maxAnswerLines,
      ),
    );
  }
}

/// One question of the practical section.
class ExamPracticalQuestion {
  const ExamPracticalQuestion({
    required this.prompt,
    required this.degree,
    this.drawingId,
    this.drawingTitle,
  });

  final String prompt;
  final int degree;
  final String? drawingId;
  final String? drawingTitle;

  bool get isEmpty => prompt.trim().isEmpty;

  ExamPracticalQuestion copyWith({
    String? prompt,
    int? degree,
    String? drawingId,
    String? drawingTitle,
  }) {
    return ExamPracticalQuestion(
      prompt: prompt ?? this.prompt,
      degree: degree ?? this.degree,
      drawingId: drawingId ?? this.drawingId,
      drawingTitle: drawingTitle ?? this.drawingTitle,
    );
  }
}

/// A complete exam paper, ready to be previewed and exported.
class ExamPaper {
  const ExamPaper({
    required this.info,
    required this.typography,
    required this.theory,
    required this.practical,
    required this.theoryDegree,
    required this.practicalDegree,
    this.theoryHeader = defaultTheoryHeader,
    this.practicalHeader = defaultPracticalHeader,
    this.freeQuestions = const <ExamFreeQuestion>[],
    this.headerConfig = ExamHeaderConfig.defaults,
    this.margins = ExamPageMargins.standard,
  });

  static const String defaultTheoryHeader = 'المادة النظرية / اجب عن سؤالين فقط';
  static const String defaultPracticalHeader = 'المادة العملية : اجب عن سؤالين فقط';
  static const String degreeRule = '____________';

  static const int minDegree = 0;
  static const int maxDegree = 100;

  final ExamPaperInfo info;
  final ExamPaperTypography typography;
  final List<ExamTheoryQuestion> theory;
  final List<ExamPracticalQuestion> practical;
  final int theoryDegree;
  final int practicalDegree;
  final String theoryHeader;
  final String practicalHeader;
  final List<ExamFreeQuestion> freeQuestions;
  final ExamHeaderConfig headerConfig;
  final ExamPageMargins margins;

  String get theoryHeadingLine {
    final header = theoryHeader.trim();
    final buffer = StringBuffer()
      ..write(header.isEmpty ? defaultTheoryHeader : header)
      ..write(' $degreeRule( $theoryDegree درجة )');
    final perQuestion = theoryPerQuestionDegree;
    if (perQuestion != null) {
      buffer.write(' لكل سؤال ( $perQuestion درجة )');
    }
    return buffer.toString();
  }

  String get theoryHeadingText =>
      theoryHeader.trim().isEmpty ? defaultTheoryHeader : theoryHeader.trim();

  static const int askedTheoryQuestionCount = 2;

  int? get theoryPerQuestionDegree {
    if (theoryDegree <= 0) {
      return null;
    }
    final split = theoryDegree ~/ askedTheoryQuestionCount;
    return theoryDegree % askedTheoryQuestionCount == 0 ? split : null;
  }

  List<ExamFreeQuestion> get activeFreeQuestions => <ExamFreeQuestion>[
    for (final ExamFreeQuestion q in freeQuestions)
      if (q.hasContent) q,
  ];

  int get freeQuestionCount => activeFreeQuestions.length;

  int get theoryQuestionCount =>
      theory.where((ExamTheoryQuestion item) => !item.isEmpty).length +
      activeFreeQuestions.length;

  String get practicalHeadingLine {
    final header = practicalHeader.trim();
    final base = header.isEmpty ? defaultPracticalHeader : header;
    return '$base ( $practicalDegree درجة )';
  }

  List<ExamTheoryItem> get theoryItems => <ExamTheoryItem>[
    for (final ExamTheoryQuestion question in theory) ...question.items,
  ];

  int get theoryItemCount => theoryItems.length;

  int get practicalCount => practical.length;

  bool get hasTheory => theoryItemCount > 0 || activeFreeQuestions.isNotEmpty;

  bool get hasPractical => practical.isNotEmpty;

  int get questionCount => theoryQuestionCount + practical.length;

  ExamPaper copyWith({
    ExamPaperInfo? info,
    ExamPaperTypography? typography,
    List<ExamTheoryQuestion>? theory,
    List<ExamPracticalQuestion>? practical,
    int? theoryDegree,
    int? practicalDegree,
    String? theoryHeader,
    String? practicalHeader,
    List<ExamFreeQuestion>? freeQuestions,
    ExamHeaderConfig? headerConfig,
    ExamPageMargins? margins,
  }) {
    return ExamPaper(
      info: info ?? this.info,
      typography: typography ?? this.typography,
      theory: theory ?? this.theory,
      practical: practical ?? this.practical,
      theoryDegree: theoryDegree ?? this.theoryDegree,
      practicalDegree: practicalDegree ?? this.practicalDegree,
      theoryHeader: theoryHeader ?? this.theoryHeader,
      practicalHeader: practicalHeader ?? this.practicalHeader,
      freeQuestions: freeQuestions ?? this.freeQuestions,
      headerConfig: headerConfig ?? this.headerConfig,
      margins: margins ?? this.margins,
    );
  }

  static bool isValidDegree(int? degree) =>
      degree != null && degree >= minDegree && degree <= maxDegree;

  List<String> get issues {
    final issues = <String>[...info.missingFields];
    if (!typography.isValid) {
      issues.add(invalidFontSizes);
    }
    if (!ExamPaperTypography.isValidLineSpacing(typography.lineSpacingPercent)) {
      issues.add(invalidLineSpacing);
    }
    if (!margins.isValid) {
      issues.add(invalidMargins);
    }
    if (!hasTheory) {
      issues.add(noTheory);
    }
    if (!hasPractical) {
      issues.add(noPractical);
    }
    var badDegree = !isValidDegree(theoryDegree) || !isValidDegree(practicalDegree);
    for (final ExamTheoryQuestion question in theory) {
      if (!isValidDegree(question.degree)) {
        badDegree = true;
        break;
      }
    }
    for (final ExamFreeQuestion question in activeFreeQuestions) {
      if (!isValidDegree(question.degree)) {
        badDegree = true;
        break;
      }
      for (final ExamQuestionBranch branch in question.activeBranches) {
        if (branch.degree != null && !isValidDegree(branch.degree)) {
          badDegree = true;
          break;
        }
      }
    }
    for (final ExamPracticalQuestion question in practical) {
      if (!isValidDegree(question.degree)) {
        badDegree = true;
        break;
      }
    }
    if (badDegree) {
      issues.add(invalidDegrees);
    }
    return List<String>.unmodifiable(issues);
  }

  bool get isComplete => issues.isEmpty;

  static const String noTheory = 'اختر سؤالاً نظرياً واحداً على الأقل';
  static const String noPractical = 'أضف سؤالاً عملياً واحداً على الأقل';
  static const String invalidDegrees = 'أدخل درجات صحيحة بين ٠ و ١٠٠';
  static const String invalidFontSizes = 'أدخل أحجام خط صحيحة';
  static const String invalidMargins = 'أدخل هوامش صفحة صحيحة';
  static const String invalidLineSpacing =
      'أدخل نسبة تباعد أسطر بين ${ExamPaperTypography.minLineSpacingPercent} و'
      ' ${ExamPaperTypography.maxLineSpacingPercent}';
}

/// `س1`, `س2`, … with Western digits, as in the official paper.
String examQuestionNumber(int index) => 'س${index + 1}';

/// Title of one theoretical question, e.g. `س2: اختر الاجابة الصحيحة …`.
String examQuestionTitle(ExamTheoryQuestion question, int index) {
  final instruction = question.instruction.trim();
  final prefix = '${examQuestionNumber(index)}:';
  return instruction.isEmpty ? prefix : '$prefix $instruction';
}

/// Title of one free-form question, e.g. `س4: عرف ما يأتي :   ( 10 درجة )`.
String examFreeQuestionHeading(ExamFreeQuestion question, int index) {
  final title = question.title.trim();
  final note = question.choiceNote.trim();
  final prefix = '${examQuestionNumber(index)}:';
  final body = <String>[
    if (title.isNotEmpty) title,
    if (note.isNotEmpty) '($note)',
  ].join(' ');
  final head = body.isEmpty ? prefix : '$prefix $body';
  return '$head   ( ${question.degree} درجة )';
}

/// Heading of a branch inside a free-form question, e.g. `فرع (أ): تعاريف   ( 5 درجة )`.
String examBranchHeading(ExamQuestionBranch branch) {
  final label = branch.label.trim().isEmpty ? 'أ' : branch.label.trim();
  final prompt = branch.prompt.trim();
  final base = prompt.isEmpty ? 'فرع ($label):' : 'فرع ($label): $prompt';
  if (branch.degree != null) {
    return '$base   ( ${branch.degree} درجة )';
  }
  return base;
}

/// The instruction printed above the items of each kind.
String defaultTheoryInstruction(QuestionKind kind, int itemCount) {
  switch (kind) {
    case QuestionKind.trueFalse:
      final count = itemCount <= 0 ? '' : ' ل${_countWord(itemCount)} فقط';
      return 'ضع علامة صح امام العبارة الصحيحة وعلامة خطأ امام العبارة الخاطئة$count :';
    case QuestionKind.choice:
      return 'اختر الاجابة الصحيحة ما بين الاقواس :';
    case QuestionKind.open:
      return 'عدد ما يأتي :';
  }
}

/// Arabic label of a theoretical question kind.
String theoryKindLabel(QuestionKind kind) {
  switch (kind) {
    case QuestionKind.trueFalse:
      return 'الصح والخطأ';
    case QuestionKind.choice:
      return 'الاختيارات';
    case QuestionKind.open:
      return 'التعداد';
  }
}

String _countWord(int count) {
  const words = <int, String>{
    1: 'واحد',
    2: 'اثنين',
    3: 'ثلاث',
    4: 'أربع',
    5: 'خمس',
    6: 'ست',
    7: 'سبع',
    8: 'ثمان',
    9: 'تسع',
    10: 'عشر',
  };
  final word = words[count];
  return word ?? toArabicDigits('$count');
}

/// The default practical question of a prepared drawing topic.
String defaultPracticalPrompt(String drawingTitle) {
  final title = drawingTitle.trim();
  if (title.isEmpty) {
    return '';
  }
  return 'ارسم موضوع «$title» مستخدماً الواناً مناسبة ؟';
}

/// The academic year shown under the exam title (school year starts in September).
String academicYearLabel(DateTime now) {
  final year = now.month >= 9 ? now.year : now.year - 1;
  return '$year – ${year + 1}';
}
