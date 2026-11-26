/// The teacher profile remembered between sessions: it pre-fills the header and
/// layout preferences of the next exam paper so that only the questions change.
library;

import '../models/exam_paper.dart';

class ExamProfile {
  const ExamProfile({
    this.schoolName = '',
    this.gradeLabel = '',
    this.sectionName = '',
    this.teacherName = '',
    this.directorateLine = '',
    this.typography = const ExamPaperTypography(),
    this.margins = ExamPageMargins.standard,
  });

  final String schoolName;
  final String gradeLabel;
  final String sectionName;
  final String teacherName;
  final String directorateLine;
  final ExamPaperTypography typography;
  final ExamPageMargins margins;

  bool get isEmpty =>
      schoolName.trim().isEmpty &&
      gradeLabel.trim().isEmpty &&
      sectionName.trim().isEmpty &&
      teacherName.trim().isEmpty &&
      directorateLine.trim().isEmpty;

  factory ExamProfile.fromJson(Map<String, dynamic> json) {
    return ExamProfile(
      schoolName: json['schoolName'] is String ? json['schoolName'] as String : '',
      gradeLabel: json['gradeLabel'] is String ? json['gradeLabel'] as String : '',
      sectionName: json['sectionName'] is String ? json['sectionName'] as String : '',
      teacherName: json['teacherName'] is String ? json['teacherName'] as String : '',
      directorateLine:
          json['directorateLine'] is String ? json['directorateLine'] as String : '',
      typography: ExamPaperTypography(
        font: _fontFromName(json['font'] is String ? json['font'] as String : null),
        headerFontSize: _sizeFromJson(
          json['headerFontSize'],
          ExamPaperTypography.defaultHeaderFontSize,
        ),
        bodyFontSize: _sizeFromJson(
          json['bodyFontSize'],
          ExamPaperTypography.defaultBodyFontSize,
        ),
        headingFontSize: _sizeFromJson(
          json['headingFontSize'],
          ExamPaperTypography.defaultHeadingFontSize,
        ),
        lineSpacingPercent: _spacingFromJson(
          json['lineSpacingPercent'],
          ExamPaperTypography.defaultLineSpacingPercent,
        ),
      ),
      margins: json['margins'] is Map
          ? ExamPageMargins.fromJson(Map<String, dynamic>.from(json['margins'] as Map))
          : ExamPageMargins.standard,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schoolName': schoolName,
      'gradeLabel': gradeLabel,
      'sectionName': sectionName,
      'teacherName': teacherName,
      if (directorateLine.isNotEmpty) 'directorateLine': directorateLine,
      'font': typography.font.name,
      'headerFontSize': typography.headerFontSize,
      'bodyFontSize': typography.bodyFontSize,
      'headingFontSize': typography.headingFontSize,
      'lineSpacingPercent': typography.lineSpacingPercent,
      'margins': margins.toJson(),
    };
  }

  ExamProfile copyWith({
    String? schoolName,
    String? gradeLabel,
    String? sectionName,
    String? teacherName,
    String? directorateLine,
    ExamPaperTypography? typography,
    ExamPageMargins? margins,
  }) {
    return ExamProfile(
      schoolName: schoolName ?? this.schoolName,
      gradeLabel: gradeLabel ?? this.gradeLabel,
      sectionName: sectionName ?? this.sectionName,
      teacherName: teacherName ?? this.teacherName,
      directorateLine: directorateLine ?? this.directorateLine,
      typography: typography ?? this.typography,
      margins: margins ?? this.margins,
    );
  }

  static ExamPaperFont _fontFromName(String? name) {
    for (final ExamPaperFont font in ExamPaperFont.values) {
      if (font.name == name) {
        return font;
      }
    }
    return ExamPaperFont.traditionalArabic;
  }

  static int _sizeFromJson(Object? value, int fallback) {
    final size = value is int ? value : int.tryParse('${value ?? ''}');
    return ExamPaperTypography.isValidFontSize(size) ? size! : fallback;
  }

  static int _spacingFromJson(Object? value, int fallback) {
    final percent = value is int ? value : int.tryParse('${value ?? ''}');
    return ExamPaperTypography.isValidLineSpacing(percent) ? percent! : fallback;
  }
}

/// Persistence contract of the exam profile.
abstract interface class ExamProfileRepository {
  Future<ExamProfile> load();

  Future<void> save(ExamProfile profile);
}
