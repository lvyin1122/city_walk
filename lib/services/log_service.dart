import 'package:mambo/services/auth_service.dart';
import 'package:mambo/services/graphql_service.dart';

/// A single location point in a tracking session.
class LogTrackingPoint {
  final double lat;
  final double lng;
  final String timestamp;

  LogTrackingPoint({
    required this.lat,
    required this.lng,
    required this.timestamp,
  });

  static LogTrackingPoint? tryParse(Object? json) {
    if (json is! Map) return null;
    final lat = _asDouble(json['lat']);
    final lng = _asDouble(json['lng']);
    if (lat == null || lng == null) return null;
    return LogTrackingPoint(
      lat: lat,
      lng: lng,
      timestamp: json['timestamp']?.toString() ?? '',
    );
  }
}

/// A tracking session: a list of points from one start/stop logging cycle.
class LogTrackingSession {
  final List<LogTrackingPoint> points;

  LogTrackingSession({required this.points});
}

/// Location tracking for a log (multiple sessions).
class LogTracking {
  final String logId;
  final List<LogTrackingSession> sessions;

  LogTracking({required this.logId, required this.sessions});

  /// Returns null when there is no session with at least one valid point.
  static LogTracking? tryParse(Object? json) {
    if (json is! Map) return null;
    final rawSessions = json['sessions'];
    final sessions = <LogTrackingSession>[
      if (rawSessions is List)
        for (final session in rawSessions)
          if (session is Map)
            LogTrackingSession(
              points: [
                if (session['points'] case final List points)
                  for (final point in points) ?LogTrackingPoint.tryParse(point),
              ],
            ),
    ]..removeWhere((session) => session.points.isEmpty);
    if (sessions.isEmpty) return null;
    return LogTracking(
      logId: json['logId']?.toString() ?? '',
      sessions: sessions,
    );
  }
}

/// One day of free-form records, with its reflection questions and answers.
class Log {
  final String id;
  final DateTime createdAt;
  final List<LogEntry> entries;
  final String overallQuestion;
  final List<String> quickReplies;
  final String followUpQuestion;
  final String overallAnswer;
  final String followUpAnswer;
  final String imageTagQuestion;
  final List<String> imageTagQuickReplies;
  final String imageTagAnswer;
  final LogTracking? tracking;
  final String? overallReflection;
  final String? overallAiSummary;
  final String? scrapbookImageUrl;

  Log({
    required this.id,
    required this.createdAt,
    required this.entries,
    this.overallQuestion = '',
    this.quickReplies = const [],
    this.followUpQuestion = '',
    this.overallAnswer = '',
    this.followUpAnswer = '',
    this.imageTagQuestion = '',
    this.imageTagQuickReplies = const [],
    this.imageTagAnswer = '',
    this.tracking,
    this.overallReflection,
    this.overallAiSummary,
    this.scrapbookImageUrl,
  });

  /// Parses a log as returned by the backend. Throws a [FormatException]
  /// when the log has no valid start time. Entries without a valid timestamp
  /// are skipped.
  factory Log.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final createdAt = DateTime.tryParse(json['startTimestamp']?.toString() ?? '');
    if (createdAt == null) {
      throw const FormatException('Invalid log: missing startTimestamp');
    }

    final rawEntries = json['logEntries'];
    final entries = <LogEntry>[
      if (rawEntries is List)
        for (final (index, entry) in rawEntries.indexed)
          ?LogEntry.tryParse(entry, id: '${id}_$index'),
    ];

    var overallQuestion = json['overallQuestion']?.toString() ?? '';
    var followUpQuestion = json['followUpQuestion']?.toString() ?? '';
    var overallAnswer = json['overallAnswer']?.toString() ?? '';
    var followUpAnswer = json['followUpAnswer']?.toString() ?? '';
    // Older logs carry their questions as a list instead.
    final legacy = json['reflectionQuestions'];
    if (overallQuestion.isEmpty && followUpQuestion.isEmpty && legacy is List) {
      if (legacy.isNotEmpty) {
        if (legacy[0] case final Map first) {
          overallQuestion = first['question']?.toString() ?? '';
          overallAnswer = first['answer']?.toString() ?? '';
        }
      }
      if (legacy.length > 1) {
        if (legacy[1] case final Map second) {
          followUpQuestion = second['question']?.toString() ?? '';
          followUpAnswer = second['answer']?.toString() ?? '';
        }
      }
    }

    return Log(
      id: id,
      createdAt: createdAt,
      entries: entries,
      overallQuestion: overallQuestion,
      quickReplies: _stringList(json['quickReplies']),
      followUpQuestion: followUpQuestion,
      overallAnswer: overallAnswer,
      followUpAnswer: followUpAnswer,
      imageTagQuestion: json['imageTagQuestion']?.toString() ?? '',
      imageTagQuickReplies: _stringList(json['imageTagQuickReplies']),
      imageTagAnswer: json['imageTagAnswer']?.toString() ?? '',
      tracking: LogTracking.tryParse(json['logTracking']),
      overallReflection: _nonEmpty(json['overallReflection']),
      overallAiSummary: _nonEmpty(json['overallAiSummary']),
      scrapbookImageUrl: _nonEmpty(json['scrapbookImageUrl']),
    );
  }

  /// Like [Log.fromJson], but returns null for a log that cannot be parsed.
  static Log? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    try {
      return Log.fromJson(json);
    } on FormatException {
      return null;
    }
  }
}

/// One recorded moment: a photo with an optional reflection and position.
class LogEntry {
  final String id;
  final String imageUrl;
  final DateTime timestamp;
  final String? description;
  final String? question;
  final String? address;
  final double? lat;
  final double? lng;

  LogEntry({
    required this.id,
    required this.imageUrl,
    required this.timestamp,
    this.description,
    this.question,
    this.address,
    this.lat,
    this.lng,
  });

  /// Returns null when the entry has no valid timestamp.
  static LogEntry? tryParse(Object? json, {required String id}) {
    if (json is! Map) return null;
    final timestamp = DateTime.tryParse(json['timestamp']?.toString() ?? '');
    if (timestamp == null) return null;
    return LogEntry(
      id: id,
      imageUrl: json['imageUrl']?.toString() ?? '',
      timestamp: timestamp,
      description: _nonEmpty(json['reflectionText']),
      question: _nonEmpty(json['question']),
      address: _nonEmpty(json['address']),
      lat: _asDouble(json['lat']),
      lng: _asDouble(json['lng']),
    );
  }
}

/// Loads and updates the signed-in user's free-form records.
class LogService {
  LogService({GraphQLService? api, String? Function()? currentUserId})
    : _api = api ?? GraphQLService(),
      _currentUserId =
          currentUserId ?? (() => AuthService().getCurrentUser()?.id);

  final GraphQLService _api;
  final String? Function() _currentUserId;

  /// All logs of the current user, most recent first. Logs that cannot be
  /// parsed are skipped.
  Future<List<Log>> getLogs() async {
    final userId = _currentUserId();
    if (userId == null) return [];

    final data = await _api.getLogs(userId: userId);
    final rawLogs = data['logs'];
    final logs = <Log>[
      if (rawLogs is List)
        for (final raw in rawLogs) ?Log.tryParse(raw),
    ];
    logs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return logs;
  }

  /// The log of [date] with its reflection questions, generated if needed.
  Future<Log?> getLogForReview(String date, int timezoneOffsetMinutes) async {
    final userId = _currentUserId();
    if (userId == null) return null;

    final log = await _api.getLogForReview(
      userId: userId,
      date: date,
      timezoneOffsetMinutes: timezoneOffsetMinutes,
    );
    return log == null ? null : Log.fromJson(log);
  }

  /// Saves the reflection answers. Null arguments are left unchanged.
  Future<Log?> updateReflectionAnswers({
    required String logId,
    String? overallAnswer,
    String? followUpAnswer,
    String? overallReflection,
    String? imageTagAnswer,
  }) async {
    final log = await _api.updateReflectionAnswers(
      logId: logId,
      overallAnswer: overallAnswer,
      followUpAnswer: followUpAnswer,
      overallReflection: overallReflection,
      imageTagAnswer: imageTagAnswer,
    );
    return log == null ? null : Log.fromJson(log);
  }

  /// Asks for a new set of reflection questions.
  Future<Log?> regenerateReflectionQuestion(String logId) async {
    final userId = _currentUserId();
    if (userId == null) return null;

    final log = await _api.regenerateReflectionQuestion(
      logId: logId,
      userId: userId,
    );
    return log == null ? null : Log.fromJson(log);
  }

  /// Replaces the AI summary with the user's own text.
  Future<Log?> updateOverallAiSummary(
    String logId,
    String customizedSummary,
  ) async {
    final userId = _currentUserId();
    if (userId == null) return null;

    final log = await _api.updateOverallAiSummary(
      logId: logId,
      userId: userId,
      overallAiSummary: customizedSummary,
    );
    return log == null ? null : Log.fromJson(log);
  }

  /// Generates a scrapbook cover image. Returns its URL, or null on failure.
  Future<String?> generateScrapbookImage(String logId) async {
    final userId = _currentUserId();
    if (userId == null) return null;

    return _api.generateLogScrapbookImage(logId: logId, userId: userId);
  }
}

String? _nonEmpty(Object? value) {
  final text = value?.toString() ?? '';
  return text.isEmpty ? null : text;
}

List<String> _stringList(Object? value) => [
  if (value is List)
    for (final item in value) ?_nonEmpty(item),
];

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return value == null ? null : double.tryParse(value.toString());
}
