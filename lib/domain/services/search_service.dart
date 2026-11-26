import '../../core/utils/arabic_text.dart';
import '../models/library.dart';

enum SearchHitType { unit, lesson, term, plate, drawing, topic, question }

/// Preserve legacy ranked OR searches in the service API. The search screen
/// defaults to allWords, matching the reference, and exposes both policies.
enum SearchMatchMode { anyWord, allWords }

/// A single search result, already prepared for display.
class SearchHit {
  const SearchHit({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.snippet,
    this.unitId,
    this.topicId,
    this.questionId,
  });

  final SearchHitType type;
  final String id;
  final String title;
  final String subtitle;
  final String snippet;
  final String? unitId;
  final String? topicId;
  final String? questionId;

  String get typeLabel {
    switch (type) {
      case SearchHitType.unit:
        return 'وحدة';
      case SearchHitType.lesson:
        return 'درس تطبيقي';
      case SearchHitType.term:
        return 'مصطلح';
      case SearchHitType.plate:
        return 'لوحة';
      case SearchHitType.drawing:
        return 'رسمة موضوع';
      case SearchHitType.topic:
        return 'موضوع';
      case SearchHitType.question:
        return 'سؤال';
    }
  }
}

/// Offline full-text search over the loaded library.
///
/// The index is built once at start-up from the same JSON that feeds the
/// reader, therefore a query can never return content that is not in the app.
class SearchService {
  SearchService(this.library, {this.unitFilter}) {
    _buildIndex();
  }

  final Library library;

  /// When set, only entries of these units (plus the shared lesson plans) are
  /// indexed — the grade picker uses it to keep the search inside one grade.
  final Set<String>? unitFilter;

  final List<_IndexEntry> _index = <_IndexEntry>[];

  void _buildIndex() {
    for (final unit in library.units) {
      if (unitFilter != null && !unitFilter!.contains(unit.id)) {
        continue;
      }
      _index.add(
        _IndexEntry(
          type: SearchHitType.unit,
          id: unit.id,
          title: unit.displayTitle,
          subtitle: unit.isIntroduction
              ? 'مدخل'
              : unit.isTheatre
              ? 'قسم مخصص'
              : unit.grade,
          haystack: normalizeArabic(unit.searchableText),
          text: unit.searchableText,
        ),
      );
      for (final topic in unit.topics) {
        _index.add(
          _IndexEntry(
            type: SearchHitType.topic,
            id: '${unit.id}:topic:${topic.id}',
            unitId: unit.id,
            topicId: topic.id,
            title: topic.title,
            subtitle: unit.displayTitle,
            haystack: normalizeArabic(
              '${unit.displayTitle} ${topic.plainText} ${topic.listTitle ?? ''}',
            ),
            text: topic.plainText,
          ),
        );
      }
      for (final question in unit.questions) {
        final text = <String>[
          question.prompt,
          ...question.options,
          question.documentedAnswerText,
          if (question.answerSupport != null) question.answerSupport!,
        ].join(' ');
        _index.add(
          _IndexEntry(
            type: SearchHitType.question,
            id: '${unit.id}:question:${question.id}',
            unitId: unit.id,
            questionId: question.id,
            title: question.prompt,
            subtitle: unit.displayTitle,
            haystack: normalizeArabic('${unit.displayTitle} $text'),
            text: text,
          ),
        );
      }
    }
    for (final lesson in library.lessons) {
      _index.add(
        _IndexEntry(
          type: SearchHitType.lesson,
          id: lesson.id,
          title: lesson.title,
          subtitle: 'دروس تطبيقية',
          haystack: normalizeArabic(lesson.searchableText),
          text: lesson.searchableText,
        ),
      );
    }
    for (final term in library.glossary) {
      if (unitFilter != null && !unitFilter!.contains(term.unitId)) {
        continue;
      }
      final unit = library.unitById(term.unitId);
      _index.add(
        _IndexEntry(
          type: SearchHitType.term,
          id: term.id,
          title: term.term,
          subtitle: unit?.displayTitle ?? 'مصطلح فني',
          haystack: normalizeArabic('${term.term} ${term.definition}'),
          text: term.definition,
        ),
      );
    }
    for (final drawing in library.drawings) {
      if (unitFilter != null && !unitFilter!.contains(drawing.unitId)) {
        continue;
      }
      _index.add(
        _IndexEntry(
          type: SearchHitType.drawing,
          id: drawing.id,
          title: drawing.title,
          subtitle: '${drawing.unitTitle} — ${drawing.topicTitle}',
          haystack: normalizeArabic(drawing.searchableText),
          text: '${drawing.title} — ${drawing.caption}',
        ),
      );
    }
    for (final plate in library.plates) {
      if (unitFilter != null && !unitFilter!.contains(plate.unitId)) {
        continue;
      }
      _index.add(
        _IndexEntry(
          type: SearchHitType.plate,
          id: plate.id,
          title: plate.title,
          subtitle: plate.grade,
          haystack: normalizeArabic('${plate.title} ${plate.caption} ${plate.grade}'),
          text: plate.caption,
        ),
      );
    }
  }

  int get indexSize => _index.length;

  List<SearchHit> search(
    String query, {
    int limit = 40,
    SearchHitType? type,
    SearchMatchMode matchMode = SearchMatchMode.anyWord,
  }) {
    final tokens = tokenizeQuery(query);
    if (tokens.isEmpty) {
      return const <SearchHit>[];
    }
    final scored = <_ScoredHit>[];
    for (final (ordinal, entry) in _index.indexed) {
      if (type != null && entry.type != type) continue;
      var matches = 0;
      for (final token in tokens) {
        if (entry.haystack.contains(token)) {
          matches++;
        }
      }
      if (matches == 0 || (matchMode == SearchMatchMode.allWords && matches != tokens.length)) {
        continue;
      }
      final titleMatch = tokens.any((token) => normalizeArabic(entry.title).contains(token));
      final score = matches * 10 + (titleMatch ? 25 : 0) + (matches == tokens.length ? 15 : 0);
      scored.add(_ScoredHit(entry: entry, score: score, ordinal: ordinal));
    }
    scored.sort((a, b) {
      final score = b.score.compareTo(a.score);
      return score != 0 ? score : a.ordinal.compareTo(b.ordinal);
    });
    return scored
        .take(limit)
        .map(
          (item) => SearchHit(
            type: item.entry.type,
            id: item.entry.id,
            title: item.entry.title,
            subtitle: item.entry.subtitle,
            snippet: snippetFor(item.entry.text, tokens),
            unitId: item.entry.unitId,
            topicId: item.entry.topicId,
            questionId: item.entry.questionId,
          ),
        )
        .toList(growable: false);
  }
}

class _IndexEntry {
  const _IndexEntry({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.haystack,
    required this.text,
    this.unitId,
    this.topicId,
    this.questionId,
  });

  final SearchHitType type;
  final String id;
  final String title;
  final String subtitle;
  final String haystack;
  final String text;
  final String? unitId;
  final String? topicId;
  final String? questionId;
}

class _ScoredHit {
  const _ScoredHit({required this.entry, required this.score, required this.ordinal});

  final _IndexEntry entry;
  final int score;
  final int ordinal;
}
