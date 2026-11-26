import 'package:flutter/material.dart';

import '../../../domain/models/exam_paper.dart';
import '../../../domain/models/library.dart';
import '../../state/exam_composer_state.dart';

/// Text controllers of the composer, owned by the screen so typed values
/// survive moving between steps or toggling the A4 preview.
class ExamComposerControllers {
  ExamComposerControllers(ExamComposerState state)
    : school = TextEditingController(text: state.schoolName),
      grade = TextEditingController(text: state.gradeLabel),
      section = TextEditingController(text: state.sectionName),
      year = TextEditingController(text: state.academicYear),
      teacher = TextEditingController(text: state.teacherName),
      directorate = TextEditingController(
        text: state.headerConfig.directorateLine,
      ),
      customExamTitle = TextEditingController(
        text: state.headerConfig.customExamTitle,
      ),
      examDuration = TextEditingController(
        text: state.headerConfig.examDuration,
      ),
      paperNote = TextEditingController(text: state.headerConfig.paperNote),
      closingWish = TextEditingController(text: state.headerConfig.closingWish),
      headerSize = TextEditingController(text: '${state.headerFontSize ?? ''}'),
      bodySize = TextEditingController(text: '${state.bodyFontSize ?? ''}'),
      headingSize = TextEditingController(text: '${state.headingFontSize ?? ''}'),
      lineSpacing = TextEditingController(
        text: '${state.lineSpacingPercent ?? ''}',
      ),
      theoryDegree = TextEditingController(text: '${state.theoryDegree ?? ''}'),
      practicalDegree = TextEditingController(
        text: '${state.practicalDegree ?? ''}',
      ),
      theoryHeader = TextEditingController(text: state.theoryHeader),
      practicalHeader = TextEditingController(text: state.practicalHeader),
      answerLines = TextEditingController(
        text: '${state.answerLineCountOf(QuestionKind.open)}',
      ),
      practicalPrompts = <TextEditingController>[
        for (final ExamPracticalQuestion question in state.practical)
          TextEditingController(text: question.prompt),
      ],
      practicalDegrees = <TextEditingController>[
        for (final ExamPracticalQuestion question in state.practical)
          TextEditingController(text: '${question.degree}'),
      ] {
    for (final QuestionKind kind in ExamTheoryQuestion.kinds) {
      instructions[kind] = TextEditingController(text: state.instructionOf(kind));
      degrees[kind] = TextEditingController(text: '${state.degreeOf(kind) ?? ''}');
    }
  }

  final TextEditingController school;
  final TextEditingController grade;
  final TextEditingController section;
  final TextEditingController year;
  final TextEditingController teacher;
  final TextEditingController directorate;
  final TextEditingController customExamTitle;
  final TextEditingController examDuration;
  final TextEditingController paperNote;
  final TextEditingController closingWish;
  final TextEditingController headerSize;
  final TextEditingController bodySize;
  final TextEditingController headingSize;
  final TextEditingController lineSpacing;
  final TextEditingController theoryDegree;
  final TextEditingController practicalDegree;
  final TextEditingController theoryHeader;
  final TextEditingController practicalHeader;
  final TextEditingController answerLines;
  final List<TextEditingController> practicalPrompts;
  final List<TextEditingController> practicalDegrees;
  final Map<QuestionKind, TextEditingController> instructions =
      <QuestionKind, TextEditingController>{};
  final Map<QuestionKind, TextEditingController> degrees =
      <QuestionKind, TextEditingController>{};

  void ensurePracticalControllerCount(ExamComposerState state) {
    while (practicalPrompts.length < state.practical.length) {
      final idx = practicalPrompts.length;
      practicalPrompts.add(
        TextEditingController(text: state.practical[idx].prompt),
      );
      practicalDegrees.add(
        TextEditingController(text: '${state.practical[idx].degree}'),
      );
    }
    while (practicalPrompts.length > state.practical.length) {
      practicalPrompts.removeLast().dispose();
      practicalDegrees.removeLast().dispose();
    }
  }

  void syncFrom(ExamComposerState state) {
    school.text = state.schoolName;
    grade.text = state.gradeLabel;
    section.text = state.sectionName;
    year.text = state.academicYear;
    teacher.text = state.teacherName;
    directorate.text = state.headerConfig.directorateLine;
    customExamTitle.text = state.headerConfig.customExamTitle;
    examDuration.text = state.headerConfig.examDuration;
    paperNote.text = state.headerConfig.paperNote;
    closingWish.text = state.headerConfig.closingWish;
    headerSize.text = '${state.headerFontSize ?? ''}';
    bodySize.text = '${state.bodyFontSize ?? ''}';
    headingSize.text = '${state.headingFontSize ?? ''}';
    lineSpacing.text = '${state.lineSpacingPercent ?? ''}';
    theoryDegree.text = '${state.theoryDegree ?? ''}';
    practicalDegree.text = '${state.practicalDegree ?? ''}';
    theoryHeader.text = state.theoryHeader;
    practicalHeader.text = state.practicalHeader;
    answerLines.text = '${state.answerLineCountOf(QuestionKind.open)}';
    for (final QuestionKind kind in ExamTheoryQuestion.kinds) {
      instructions[kind]?.text = state.instructionOf(kind);
      degrees[kind]?.text = '${state.degreeOf(kind) ?? ''}';
    }
    ensurePracticalControllerCount(state);
    for (var i = 0; i < practicalPrompts.length; i++) {
      practicalPrompts[i].text = state.practical[i].prompt;
      practicalDegrees[i].text = '${state.practical[i].degree}';
    }
  }

  void dispose() {
    school.dispose();
    grade.dispose();
    section.dispose();
    year.dispose();
    teacher.dispose();
    directorate.dispose();
    customExamTitle.dispose();
    examDuration.dispose();
    paperNote.dispose();
    closingWish.dispose();
    headerSize.dispose();
    bodySize.dispose();
    headingSize.dispose();
    lineSpacing.dispose();
    theoryDegree.dispose();
    practicalDegree.dispose();
    theoryHeader.dispose();
    practicalHeader.dispose();
    answerLines.dispose();
    for (final TextEditingController controller in practicalPrompts) {
      controller.dispose();
    }
    for (final TextEditingController controller in practicalDegrees) {
      controller.dispose();
    }
    for (final TextEditingController controller in instructions.values) {
      controller.dispose();
    }
    for (final TextEditingController controller in degrees.values) {
      controller.dispose();
    }
  }
}
