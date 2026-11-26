/// Shared formatting, layout blocks, and text rendering used by the Word
/// exporter, the A4 live preview, the review panel, and the tests.
library;

import '../models/exam_paper.dart';
import '../models/library.dart';

/// One documented question offered by the composer, with its unit title.
class ExamQuestionOption {
  const ExamQuestionOption({
    required this.question,
    required this.unitId,
    required this.unitTitle,
  });

  final Question question;
  final String unitId;
  final String unitTitle;

  String get id => '$unitId:${question.id}';

  bool get isSupplemental =>
      question.id.startsWith('topic-') || question.id.startsWith('curated-');
  bool get isCurated => question.id.startsWith('curated-');
}

/// Visual role of a body block on the A4 sheet so `ExamLivePreview` renders the
/// exact hierarchy (bold section titles, bold question/branch headings, rules,
/// and two-column footer signoff) matching `ExamDocxBuilder`.
enum ExamBodyBlockRole {
  paperNote,
  sectionHeading,
  questionHeading,
  branchHeading,
  itemLine,
  spacer,
  separatorRule,
  footerSignoff,
}

class ExamBodyBlock {
  const ExamBodyBlock({
    required this.role,
    required this.text,
    this.secondaryText = '',
    this.indent = 0,
  });

  final ExamBodyBlockRole role;
  final String text;
  final String secondaryText;
  final double indent;
}

/// Exact three-column header lines shared by `ExamLivePreview` and `ExamDocxBuilder`.
class ExamHeaderColumns {
  const ExamHeaderColumns({
    required this.rightLines,
    required this.centerLines,
    required this.leftLines,
  });

  final List<String> rightLines;
  final List<String> centerLines;
  final List<String> leftLines;

  String get rightJoined => rightLines.join('\n');
  String get centerJoined => centerLines.join('\n');
  String get leftJoined => leftLines.join('\n');
}

ExamHeaderColumns examHeaderColumns(ExamPaper paper) {
  final info = paper.info;
  final cfg = paper.headerConfig;
  final rightLines = <String>[
    if (cfg.directorateLine.trim().isNotEmpty) cfg.directorateLine.trim(),
    cfg.effectiveAdministrationLabel,
    info.school,
  ];
  final centerLines = <String>[
    info.examTitleLineWith(cfg),
    info.yearLine,
    cfg.effectiveSubjectName,
  ];
  final leftLines = <String>[
    if (cfg.showStudentFields) 'الاسم :',
    info.classLine,
    if (cfg.showStudentFields) 'الرقم الامتحاني :',
    if (cfg.examDuration.trim().isNotEmpty) 'الزمن : ${cfg.examDuration.trim()}',
  ];
  return ExamHeaderColumns(
    rightLines: List<String>.unmodifiable(rightLines),
    centerLines: List<String>.unmodifiable(centerLines),
    leftLines: List<String>.unmodifiable(leftLines),
  );
}

/// Offered questions of every kind, in curriculum order.
List<ExamQuestionOption> examQuestionOptions(Iterable<LearningUnit> units) {
  final options = <ExamQuestionOption>[];
  final ordered = _orderedUnits(units);
  for (final LearningUnit unit in ordered) {
    for (final Question question in unit.questions) {
      options.add(
        ExamQuestionOption(question: question, unitId: unit.id, unitTitle: unit.title),
      );
    }
  }
  for (final unit in ordered) {
    for (final question in unit.bankQuestions) {
      options.add(
        ExamQuestionOption(question: question, unitId: unit.id, unitTitle: unit.title),
      );
    }
  }
  for (final unit in ordered) {
    for (final topic in unit.topics) {
      for (var i = 0; i < topic.bullets.length; i++) {
        final text = topic.bullets[i].trim();
        if (text.isEmpty) continue;
        options.add(
          ExamQuestionOption(
            unitId: unit.id,
            unitTitle: unit.title,
            question: Question(
              id: 'topic-${topic.id}-statement-$i',
              kind: QuestionKind.trueFalse,
              prompt: text,
              boolAnswer: true,
            ),
          ),
        );
      }
      final source = <String>[...topic.bullets, ...topic.listItems];
      if (source.any((text) => text.trim().isNotEmpty) && topic.title.trim().isNotEmpty) {
        options.add(
          ExamQuestionOption(
            unitId: unit.id,
            unitTitle: unit.title,
            question: Question(
              id: 'topic-${topic.id}-explain',
              kind: QuestionKind.open,
              prompt: 'أهم المعلومات الواردة في موضوع ${topic.title}.',
              textAnswer: source.join('\n'),
            ),
          ),
        );
      }
    }
  }
  return List<ExamQuestionOption>.unmodifiable(options);
}

List<LearningUnit> _orderedUnits(Iterable<LearningUnit> units) {
  final list = units.toList(growable: false);
  final sectionOrder = <String, int>{};
  for (final LearningUnit unit in list) {
    sectionOrder.putIfAbsent(unit.sectionId, () => sectionOrder.length);
  }
  final decorated = <_IndexedUnit>[
    for (var i = 0; i < list.length; i++) _IndexedUnit(list[i], i),
  ];
  decorated.sort((_IndexedUnit a, _IndexedUnit b) {
    final section = sectionOrder[a.unit.sectionId]!.compareTo(
      sectionOrder[b.unit.sectionId]!,
    );
    if (section != 0) {
      return section;
    }
    final order = a.unit.order.compareTo(b.unit.order);
    return order != 0 ? order : a.index.compareTo(b.index);
  });
  return <LearningUnit>[for (final _IndexedUnit item in decorated) item.unit];
}

class _IndexedUnit {
  const _IndexedUnit(this.unit, this.index);

  final LearningUnit unit;
  final int index;
}

/// Prepared drawing topics, in document order.
List<TopicDrawing> examDrawingOptions(Iterable<TopicDrawing> drawings) {
  final list = drawings.toList(growable: true)
    ..sort((TopicDrawing a, TopicDrawing b) {
      final order = a.order.compareTo(b.order);
      return order != 0 ? order : a.id.compareTo(b.id);
    });
  return List<TopicDrawing>.unmodifiable(list);
}

/// The text of one theoretical item, exactly as it appears on the paper.
String examTheoryItemText(ExamTheoryItem item) {
  final prompt = item.prompt.trim();
  switch (item.kind) {
    case QuestionKind.trueFalse:
      return '$prompt        (                )';
    case QuestionKind.choice:
      if (item.options.isEmpty) {
        return prompt;
      }
      return '$prompt   ( ${item.options.map((String option) => option.trim()).join('   -   ')} )';
    case QuestionKind.open:
      return prompt;
  }
}

/// Blank numbered answer lines of an enumeration or free question.
List<String> examNumberedBlankLines(int count) {
  return <String>[for (var i = 0; i < count; i++) '${i + 1}- ${'.' * 46}'];
}

List<String> examAnswerLines(ExamTheoryQuestion question) =>
    examNumberedBlankLines(question.answerLineCount);

/// One practical item line, including its mark, shared by preview and DOCX.
String examPracticalItemText(ExamPracticalQuestion question, int index) {
  return '${examQuestionNumber(index)}: ${question.prompt.trim()}   ( ${question.degree} درجة )';
}

/// Builds the semantic body block list shared by `ExamLivePreview` and plain-text export.
List<ExamBodyBlock> examBodyBlocks(ExamPaper paper) {
  final blocks = <ExamBodyBlock>[];
  final cfg = paper.headerConfig;

  if (cfg.paperNote.trim().isNotEmpty) {
    blocks.add(
      ExamBodyBlock(
        role: ExamBodyBlockRole.paperNote,
        text: cfg.paperNote.trim(),
      ),
    );
  }

  if (paper.hasTheory || paper.theory.isEmpty && paper.practical.isEmpty) {
    blocks.add(
      ExamBodyBlock(
        role: ExamBodyBlockRole.sectionHeading,
        text: paper.theoryHeadingLine,
      ),
    );
  }

  var theoryIndex = 0;
  for (final ExamTheoryQuestion question in paper.theory) {
    if (question.isEmpty) {
      continue;
    }
    blocks.add(
      ExamBodyBlock(
        role: ExamBodyBlockRole.questionHeading,
        text: examTheoryHeading(question, theoryIndex),
      ),
    );
    theoryIndex++;
    var itemIndex = 0;
    for (final ExamTheoryItem item in question.items) {
      itemIndex++;
      blocks.add(
        ExamBodyBlock(
          role: ExamBodyBlockRole.itemLine,
          text: '$itemIndex- ${examTheoryItemText(item)}',
        ),
      );
      if (item.kind == QuestionKind.open) {
        for (final String line in examAnswerLines(question)) {
          blocks.add(ExamBodyBlock(role: ExamBodyBlockRole.itemLine, text: line));
        }
      }
    }
    blocks.add(const ExamBodyBlock(role: ExamBodyBlockRole.spacer, text: ''));
  }

  for (final ExamFreeQuestion free in paper.activeFreeQuestions) {
    blocks.add(
      ExamBodyBlock(
        role: ExamBodyBlockRole.questionHeading,
        text: examFreeQuestionHeading(free, theoryIndex),
      ),
    );
    theoryIndex++;
    final directItems = free.nonEmptyItems;
    for (var i = 0; i < directItems.length; i++) {
      blocks.add(
        ExamBodyBlock(
          role: ExamBodyBlockRole.itemLine,
          text: '${i + 1}- ${directItems[i]}',
        ),
      );
    }
    for (final ExamQuestionBranch branch in free.activeBranches) {
      blocks.add(
        ExamBodyBlock(
          role: ExamBodyBlockRole.branchHeading,
          text: examBranchHeading(branch),
          indent: 12,
        ),
      );
      final branchItems = branch.nonEmptyItems;
      for (var i = 0; i < branchItems.length; i++) {
        blocks.add(
          ExamBodyBlock(
            role: ExamBodyBlockRole.itemLine,
            text: '${i + 1}- ${branchItems[i]}',
            indent: 20,
          ),
        );
      }
    }
    if (free.answerLineCount > 0) {
      for (final String line in examNumberedBlankLines(free.answerLineCount)) {
        blocks.add(ExamBodyBlock(role: ExamBodyBlockRole.itemLine, text: line));
      }
    }
    blocks.add(const ExamBodyBlock(role: ExamBodyBlockRole.spacer, text: ''));
  }

  if (paper.hasPractical || paper.practical.isEmpty && !paper.hasTheory) {
    blocks.add(
      ExamBodyBlock(
        role: ExamBodyBlockRole.sectionHeading,
        text: paper.practicalHeadingLine,
      ),
    );
  }
  for (var i = 0; i < paper.practical.length; i++) {
    final ExamPracticalQuestion question = paper.practical[i];
    blocks.add(
      ExamBodyBlock(
        role: ExamBodyBlockRole.itemLine,
        text: examPracticalItemText(question, i),
      ),
    );
  }

  blocks
    ..add(
      const ExamBodyBlock(
        role: ExamBodyBlockRole.separatorRule,
        text: '______________________________________________________',
      ),
    )
    ..add(
      ExamBodyBlock(
        role: ExamBodyBlockRole.footerSignoff,
        text: cfg.effectiveClosingWish,
        secondaryText: <String>[
          cfg.effectiveTeacherTitle,
          if (paper.info.teacherName.trim().isNotEmpty)
            paper.info.teacherName.trim(),
        ].join('\n'),
      ),
    );

  return List<ExamBodyBlock>.unmodifiable(blocks);
}

/// The whole paper as readable text: used by the review panel and plain-text copy.
String examPaperAsPlainText(ExamPaper paper) {
  final buffer = StringBuffer();
  final cols = examHeaderColumns(paper);
  for (final line in cols.rightLines) {
    buffer.writeln(line);
  }
  for (final line in cols.centerLines) {
    buffer.writeln(line);
  }
  for (final line in cols.leftLines) {
    buffer.writeln(line);
  }
  buffer
    ..writeln()
    ..write(examPaperBodyAsPlainText(paper));
  return buffer.toString();
}

/// Body only, matching the exact ordering of `examBodyBlocks` and `ExamDocxBuilder`.
String examPaperBodyAsPlainText(ExamPaper paper) {
  final buffer = StringBuffer();
  final cfg = paper.headerConfig;
  if (cfg.paperNote.trim().isNotEmpty) {
    buffer.writeln(cfg.paperNote.trim());
  }
  buffer.writeln(paper.theoryHeadingLine);

  var theoryIndex = 0;
  for (final ExamTheoryQuestion question in paper.theory) {
    if (question.isEmpty) {
      continue;
    }
    buffer.writeln(examTheoryHeading(question, theoryIndex));
    theoryIndex++;
    var itemIndex = 0;
    for (final ExamTheoryItem item in question.items) {
      itemIndex++;
      buffer.writeln('$itemIndex- ${examTheoryItemText(item)}');
      if (item.kind == QuestionKind.open) {
        for (final String line in examAnswerLines(question)) {
          buffer.writeln(line);
        }
      }
    }
    buffer.writeln();
  }

  for (final ExamFreeQuestion free in paper.activeFreeQuestions) {
    buffer.writeln(examFreeQuestionHeading(free, theoryIndex));
    theoryIndex++;
    final directItems = free.nonEmptyItems;
    for (var i = 0; i < directItems.length; i++) {
      buffer.writeln('${i + 1}- ${directItems[i]}');
    }
    for (final ExamQuestionBranch branch in free.activeBranches) {
      buffer.writeln(examBranchHeading(branch));
      final branchItems = branch.nonEmptyItems;
      for (var i = 0; i < branchItems.length; i++) {
        buffer.writeln('${i + 1}- ${branchItems[i]}');
      }
    }
    if (free.answerLineCount > 0) {
      for (final String line in examNumberedBlankLines(free.answerLineCount)) {
        buffer.writeln(line);
      }
    }
    buffer.writeln();
  }

  buffer.writeln(paper.practicalHeadingLine);
  for (var i = 0; i < paper.practical.length; i++) {
    buffer.writeln(examPracticalItemText(paper.practical[i], i));
  }
  buffer
    ..writeln()
    ..writeln(cfg.effectiveClosingWish)
    ..writeln(cfg.effectiveTeacherTitle)
    ..writeln(paper.info.teacherName.trim());
  return buffer.toString();
}

/// `س1: <instruction>   ( 6 درجة )`
String examTheoryHeading(ExamTheoryQuestion question, int index) {
  return '${examQuestionTitle(question, index)}   ( ${question.degree} درجة )';
}

/// File name of the exported document, safe on Android and Windows.
String examPaperFileName(ExamPaper paper) {
  final info = paper.info;
  final grade = info.gradeLabel.trim().isEmpty ? 'امتحان' : info.gradeLabel.trim();
  final raw = 'امتحان ${info.term.label} - $grade - ${info.academicYear.trim()}';
  return '${sanitizeExamFileName(raw)}.docx';
}

String sanitizeExamFileName(String name) {
  final cleaned = name
      .replaceAll(RegExp(r'[\\/:*?"<>|\u0000-\u001f]'), '-')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceAll(RegExp(r'^[.\s]+|[.\s]+$'), '');
  return cleaned.isEmpty ? 'mirsam-exam' : cleaned;
}

String examGradeLabel(String gradeTitle) {
  final title = gradeTitle.trim();
  if (title.startsWith('الصف ')) {
    return title.substring('الصف '.length).trim();
  }
  return title;
}
