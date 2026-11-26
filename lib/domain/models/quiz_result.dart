/// One completed interactive round, distinct from a unit's best practice score.
class QuizResult {
  const QuizResult({
    required this.gradeId,
    required this.scopeLabel,
    required this.correct,
    required this.total,
    required this.completedAt,
  });
  final String gradeId;
  final String scopeLabel;
  final int correct;
  final int total;
  final DateTime completedAt;
  Map<String, dynamic> toJson() => <String, dynamic>{
    'gradeId': gradeId,
    'scopeLabel': scopeLabel,
    'correct': correct,
    'total': total,
    'completedAt': completedAt.toIso8601String(),
  };
  static QuizResult? tryRead(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final total = raw['total'];
    final correct = raw['correct'];
    final date = DateTime.tryParse('${raw['completedAt']}');
    if (total is! int ||
        correct is! int ||
        total <= 0 ||
        correct < 0 ||
        correct > total ||
        date == null ||
        raw['gradeId'] is! String ||
        raw['scopeLabel'] is! String)
      return null;
    return QuizResult(
      gradeId: raw['gradeId'] as String,
      scopeLabel: raw['scopeLabel'] as String,
      correct: correct,
      total: total,
      completedAt: date,
    );
  }
}
