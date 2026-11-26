import '../../domain/models/library.dart';

/// Parse supplemental composer questions while checking their provenance and
/// identities. A broken asset must never silently introduce an ungraded or
/// unsupported question into an exam.
Map<String, List<Question>> parseCuratedQuestionBank(
  Map<String, dynamic> bank,
  Map<String, dynamic> curriculum,
) {
  if (bank['version'] != 1 || bank['questions'] is! List || curriculum['units'] is! List) {
    throw const FormatException('Invalid curated question bank');
  }
  final units = <String, Map<String, dynamic>>{};
  for (final value in curriculum['units'] as List) {
    final unit = value as Map<String, dynamic>;
    units[unit['id'] as String] = unit;
  }
  final result = <String, List<Question>>{};
  final ids = <String>{};
  for (final value in bank['questions'] as List) {
    if (value is! Map<String, dynamic>) throw const FormatException('Invalid bank question');
    final unitId = value['unitId'];
    final topicId = value['topicId'];
    final id = value['id'];
    final prompt = value['prompt'];
    final support = value['answerSupport'];
    if (unitId is! String || topicId is! String || id is! String || id.isEmpty ||
        prompt is! String || prompt.trim().isEmpty || support is! String || support.isEmpty ||
        !id.startsWith('curated-') || !ids.add('$unitId:$id')) {
      throw const FormatException('Invalid bank question identity or text');
    }
    final unit = units[unitId];
    if (unit == null || unit['topics'] is! List) throw const FormatException('Unknown bank unit');
    final topics = (unit['topics'] as List).whereType<Map<String, dynamic>>();
    final matching = topics.where((topic) => topic['id'] == topicId).toList();
    if (matching.length != 1 || matching.single['bullets'] is! List ||
        !(matching.single['bullets'] as List).contains(support)) {
      throw const FormatException('Bank evidence does not match its topic');
    }
    final kind = value['kind'];
    if (kind == 'trueFalse') {
      if (value['answer'] != false) throw const FormatException('Invalid false statement');
    } else if (kind == 'choice') {
      final choices = value['options'];
      final answer = value['answerIndex'];
      if (choices is! List || choices.length < 2 ||
          choices.any((choice) => choice is! String || choice.trim().isEmpty) ||
          choices.toSet().length != choices.length ||
          answer is! int || answer < 0 || answer >= choices.length) {
        throw const FormatException('Invalid bank choices');
      }
    } else {
      throw const FormatException('Unknown bank question kind');
    }
    result.putIfAbsent(unitId, () => <Question>[]).add(Question.fromJson(value));
  }
  return <String, List<Question>>{
    for (final entry in result.entries) entry.key: List<Question>.unmodifiable(entry.value),
  };
}
