/// Local reading state of the learner. Pure Dart so it can be tested without
/// Flutter bindings and serialised to `shared_preferences`.
library;

import 'quiz_result.dart';

enum AppThemeMode {
  system,
  light,
  dark;

  static AppThemeMode parse(String? value) {
    switch (value) {
      case 'light':
        return AppThemeMode.light;
      case 'dark':
        return AppThemeMode.dark;
      default:
        return AppThemeMode.system;
    }
  }
}

/// The selectable typefaces. All of them are bundled in the package, so
/// switching never needs a network connection.
enum AppFont {
  almarai('Almarai', 'المراعي'),
  cairo('Cairo', 'القاهرة'),
  tajawal('Tajawal', 'تجوال'),
  plex('IBMPlexSansArabic', 'IBM بلكس'),
  kufi('NotoKufiArabic', 'كوفي نوتو');

  const AppFont(this.family, this.label);

  /// The `family` name declared in `pubspec.yaml`.
  final String family;

  /// Arabic name shown in the settings page.
  final String label;

  static AppFont parse(String? value) {
    for (final font in AppFont.values) {
      if (font.name == value) {
        return font;
      }
    }
    return AppFont.almarai;
  }
}

/// The application text size starts at 80 %, as requested for the project.
const double defaultTextScale = 0.8;

/// Documents saved before the default became 80 % carry no settings version and
/// keep whatever size they were saved with, which is always 100 % for a fresh
/// install. Bumping this marker makes the new default apply once; a size the
/// teacher picks afterwards is stored with the marker and is never overridden.
const int readingProgressVersion = 2;

class ReadingProgress {
  ReadingProgress({
    Set<String>? favorites,
    Set<String>? readUnits,
    this.lastUnitId,
    Map<String, double>? scrollOffsets,
    Map<String, int>? quizScores,
    List<QuizResult>? quizHistory,
    this.themeMode = AppThemeMode.system,
    this.textScale = defaultTextScale,
    this.gradeId,
    this.font = AppFont.almarai,
  }) : favorites = favorites ?? <String>{},
       readUnits = readUnits ?? <String>{},
       scrollOffsets = scrollOffsets ?? <String, double>{},
       quizScores = quizScores ?? <String, int>{},
       quizHistory = quizHistory ?? <QuizResult>[];

  final Set<String> favorites;
  final Set<String> readUnits;
  String? lastUnitId;
  final Map<String, double> scrollOffsets;
  final Map<String, int> quizScores;
  final List<QuizResult> quizHistory;
  AppThemeMode themeMode;
  double textScale;

  /// The grade chosen on first launch (`g1`, `g2`, `g3`); null shows the picker.
  String? gradeId;

  /// Typeface chosen in the settings page.
  AppFont font;

  bool isFavorite(String id) => favorites.contains(id);
  bool isRead(String id) => readUnits.contains(id);

  int get readCount => readUnits.length;

  ReadingProgress copy() {
    return ReadingProgress(
      favorites: Set<String>.from(favorites),
      readUnits: Set<String>.from(readUnits),
      lastUnitId: lastUnitId,
      scrollOffsets: Map<String, double>.from(scrollOffsets),
      quizScores: Map<String, int>.from(quizScores),
      quizHistory: List<QuizResult>.of(quizHistory),
      themeMode: themeMode,
      textScale: textScale,
      gradeId: gradeId,
      font: font,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'version': readingProgressVersion,
      'favorites': favorites.toList(),
      'readUnits': readUnits.toList(),
      'lastUnitId': lastUnitId,
      'scrollOffsets': scrollOffsets,
      'quizScores': quizScores,
      'quizHistory': quizHistory.map((score) => score.toJson()).toList(),
      'themeMode': themeMode.name,
      'textScale': textScale,
      'gradeId': gradeId,
      'font': font.name,
    };
  }

  static ReadingProgress fromJson(Map<String, dynamic> json) {
    final savedScale = (json['textScale'] as num?)?.toDouble() ?? defaultTextScale;
    final version = (json['version'] as num?)?.toInt() ?? 0;
    return ReadingProgress(
      favorites: _stringSet(json['favorites']),
      readUnits: _stringSet(json['readUnits']),
      lastUnitId: json['lastUnitId'] as String?,
      scrollOffsets: _doubleMap(json['scrollOffsets']),
      quizScores: _intMap(json['quizScores']),
      quizHistory: (json['quizHistory'] is List ? json['quizHistory'] as List : const <dynamic>[])
          .map(QuizResult.tryRead)
          .whereType<QuizResult>()
          .take(100)
          .toList(),
      themeMode: AppThemeMode.parse(json['themeMode'] as String?),
      // An unversioned document was written when the application started at
      // 100 %, so it is migrated to the new starting size exactly once.
      textScale: version >= readingProgressVersion ? savedScale : defaultTextScale,
      gradeId: json['gradeId'] as String?,
      font: AppFont.parse(json['font'] as String?),
    );
  }

  static Set<String> _stringSet(Object? value) {
    if (value is! List) {
      return <String>{};
    }
    return value.whereType<String>().toSet();
  }

  static Map<String, double> _doubleMap(Object? value) {
    if (value is! Map) {
      return <String, double>{};
    }
    final result = <String, double>{};
    value.forEach((key, item) {
      if (key is String && item is num) {
        result[key] = item.toDouble();
      }
    });
    return result;
  }

  static Map<String, int> _intMap(Object? value) {
    if (value is! Map) {
      return <String, int>{};
    }
    final result = <String, int>{};
    value.forEach((key, item) {
      if (key is String && item is num) {
        result[key] = item.toInt();
      }
    });
    return result;
  }
}
