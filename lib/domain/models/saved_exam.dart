import 'dart:convert';
import 'exam_draft_snapshot.dart';

/// A versioned, deep-copied draft. Incomplete forms are saved as well as papers.
class SavedExamPaper {
  SavedExamPaper({
    required this.id,
    required Map<String, dynamic> draft,
    required this.gradeId,
    required this.createdAt,
    required this.updatedAt,
    this.customTitle = '',
    this.revision = 1,
  }) : _encodedDraft = jsonEncode(ExamDraftSnapshot.decode(draft).toJson());

  factory SavedExamPaper.fromJson(Map<String, dynamic> json) => SavedExamPaper(
    id: json['id'] as String,
    draft: Map<String, dynamic>.from(json['draft'] as Map),
    gradeId: json['gradeId'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    customTitle: json['customTitle'] as String? ?? '',
    revision: json['revision'] as int? ?? 1,
  );

  final String id;
  final String gradeId;
  final String _encodedDraft;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String customTitle;
  final int revision;
  Map<String, dynamic> get draft => jsonDecode(_encodedDraft) as Map<String, dynamic>;

  String get displayTitle {
    if (customTitle.trim().isNotEmpty) return customTitle;
    final prefix = switch (draft['term']) {
      'endOfYear' => 'امتحان آخر السنة',
      'firstSemester' => 'امتحان الفصل الأول',
      'secondSemester' => 'امتحان الفصل الثاني',
      'monthly' => 'امتحان شهري',
      _ => 'ورقة أسئلة',
    };
    return '$prefix — ${draft['gradeLabel'] ?? ''}';
  }

  SavedExamPaper copyWith({
    Map<String, dynamic>? draft,
    DateTime? updatedAt,
    String? customTitle,
    int? revision,
  }) => SavedExamPaper(
    id: id,
    gradeId: gradeId,
    draft: draft ?? this.draft,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    customTitle: customTitle ?? this.customTitle,
    revision: revision ?? this.revision,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'gradeId': gradeId,
    'draft': draft,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'customTitle': customTitle,
    'revision': revision,
  };
}
