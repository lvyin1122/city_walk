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
}

/// Log service for log-related data.
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
}

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
}

class LogService {
  final _graphQLService = GraphQLService();
  final _authService = AuthService();

  /// Fetches all logs for the current user via GraphQL logs query.
  Future<List<Log>> getLogs() async {
    final user = _authService.getCurrentUser();
    if (user == null) return [];

    final data = await _graphQLService.getLogs(userId: user.id);
    final rawLogs = data['logs'] as List<dynamic>? ?? [];
    final logs = <Log>[];

    for (final raw in rawLogs) {
      final logMap = raw as Map<String, dynamic>;
      final id = logMap['id']?.toString() ?? '';
      final startTs = logMap['startTimestamp']?.toString();
      if (startTs == null) continue;

      DateTime createdAt;
      try {
        createdAt = DateTime.parse(startTs);
      } catch (_) {
        continue;
      }

      final rawEntries = logMap['logEntries'] as List<dynamic>? ?? [];
      final entries = <LogEntry>[];
      for (var i = 0; i < rawEntries.length; i++) {
        final e = rawEntries[i] as Map<String, dynamic>;
        final ts = e['timestamp']?.toString();
        if (ts == null) continue;
        DateTime timestamp;
        try {
          timestamp = DateTime.parse(ts);
        } catch (_) {
          continue;
        }
        final imageUrl = e['imageUrl']?.toString() ?? '';
        final reflectionText = e['reflectionText']?.toString();
        final question = e['question']?.toString();
        final address = e['address']?.toString();
        final latVal = e['lat'];
        final lngVal = e['lng'];
        final lat = latVal != null ? (latVal is num ? latVal.toDouble() : double.tryParse(latVal.toString())) : null;
        final lng = lngVal != null ? (lngVal is num ? lngVal.toDouble() : double.tryParse(lngVal.toString())) : null;
        entries.add(
          LogEntry(
            id: '${id}_$i',
            imageUrl: imageUrl,
            timestamp: timestamp,
            description: reflectionText != null && reflectionText.isNotEmpty
                ? reflectionText
                : null,
            question: question != null && question.isNotEmpty ? question : null,
            address: address != null && address.isNotEmpty ? address : null,
            lat: lat,
            lng: lng,
          ),
        );
      }

      final (overallQuestion, quickReplies, followUpQuestion, overallAnswer, followUpAnswer) =
          _parseReflectionFields(logMap);

      final tracking = _parseTrackingFromMap(logMap['logTracking']);
      final overallAiSummary = logMap['overallAiSummary']?.toString();
      final overallAiSummaryVal = overallAiSummary != null && overallAiSummary.isNotEmpty
          ? overallAiSummary
          : null;
      final overallReflection = logMap['overallReflection']?.toString();
      final overallReflectionVal = overallReflection != null && overallReflection.isNotEmpty
          ? overallReflection
          : null;
      final scrapbookImageUrl = logMap['scrapbookImageUrl']?.toString();
      final scrapbookImageUrlVal = scrapbookImageUrl != null && scrapbookImageUrl.isNotEmpty
          ? scrapbookImageUrl
          : null;

      final imageTagQuestion = logMap['imageTagQuestion']?.toString() ?? '';
      final imageTagQuickRepliesRaw = logMap['imageTagQuickReplies'] as List<dynamic>? ?? [];
      final imageTagQuickReplies = imageTagQuickRepliesRaw
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      final imageTagAnswer = logMap['imageTagAnswer']?.toString() ?? '';

      logs.add(Log(
        id: id,
        createdAt: createdAt,
        entries: entries,
        overallQuestion: overallQuestion,
        quickReplies: quickReplies,
        followUpQuestion: followUpQuestion,
        overallAnswer: overallAnswer,
        followUpAnswer: followUpAnswer,
        imageTagQuestion: imageTagQuestion,
        imageTagQuickReplies: imageTagQuickReplies,
        imageTagAnswer: imageTagAnswer,
        tracking: tracking,
        overallReflection: overallReflectionVal,
        overallAiSummary: overallAiSummaryVal,
        scrapbookImageUrl: scrapbookImageUrlVal,
      ));
    }

    logs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return logs;
  }

  /// Fetches a single log by id. Uses getLogs and filters by id.
  Future<Log?> getLogDetail(String logId) async {
    final logs = await getLogs();
    for (final log in logs) {
      if (log.id == logId) return log;
    }
    return null;
  }

  /// Fetches log for review for the given date. Generates reflection questions if needed.
  Future<Log?> getLogForReview(String date, int timezoneOffsetMinutes) async {
    final user = _authService.getCurrentUser();
    if (user == null) return null;

    final logMap = await _graphQLService.getLogForReview(
      userId: user.id,
      date: date,
      timezoneOffsetMinutes: timezoneOffsetMinutes,
    );
    if (logMap == null) return null;

    return _parseLogFromMap(logMap);
  }

  /// Updates overall answer, follow-up answer, optionally overall reflection, and image tag answer.
  Future<Log?> updateReflectionAnswers({
    required String logId,
    String? overallAnswer,
    String? followUpAnswer,
    String? overallReflection,
    String? imageTagAnswer,
  }) async {
    final logMap = await _graphQLService.updateReflectionAnswers(
      logId: logId,
      overallAnswer: overallAnswer,
      followUpAnswer: followUpAnswer,
      overallReflection: overallReflection,
      imageTagAnswer: imageTagAnswer,
    );
    if (logMap == null) return null;
    return _parseLogFromMap(logMap);
  }

  /// Regenerates the overall reflection block (question, quick replies, follow-up).
  Future<Log?> regenerateReflectionQuestion(String logId) async {
    final user = _authService.getCurrentUser();
    if (user == null) return null;

    final logMap = await _graphQLService.regenerateReflectionQuestion(
      logId: logId,
      userId: user.id,
    );
    if (logMap == null) return null;

    return _parseLogFromMap(logMap);
  }

  /// Updates the overall AI summary with user's customized text.
  Future<Log?> updateOverallAiSummary(String logId, String customizedSummary) async {
    final user = _authService.getCurrentUser();
    if (user == null) return null;

    final logMap = await _graphQLService.updateOverallAiSummary(
      logId: logId,
      userId: user.id,
      overallAiSummary: customizedSummary,
    );
    if (logMap == null) return null;

    return _parseLogFromMap(logMap);
  }

  /// Generate a scrapbook cover image for a log.
  /// Returns the image URL on success, or null on failure.
  Future<String?> generateScrapbookImage(String logId) async {
    final user = _authService.getCurrentUser();
    if (user == null) return null;

    return _graphQLService.generateLogScrapbookImage(
      logId: logId,
      userId: user.id,
    );
  }

  (String, List<String>, String, String, String) _parseReflectionFields(Map<String, dynamic> logMap) {
    var overallQuestion = logMap['overallQuestion']?.toString() ?? '';
    var quickReplies = logMap['quickReplies'] as List<dynamic>? ?? [];
    var followUpQuestion = logMap['followUpQuestion']?.toString() ?? '';
    var overallAnswer = logMap['overallAnswer']?.toString() ?? '';
    var followUpAnswer = logMap['followUpAnswer']?.toString() ?? '';
    if (overallQuestion.isEmpty && followUpQuestion.isEmpty) {
      final rq = logMap['reflectionQuestions'] as List<dynamic>? ?? [];
      if (rq.isNotEmpty) {
        final first = rq[0] as Map<String, dynamic>?;
        overallQuestion = first?['question']?.toString() ?? '';
        overallAnswer = first?['answer']?.toString() ?? '';
      }
      if (rq.length > 1) {
        final second = rq[1] as Map<String, dynamic>?;
        followUpQuestion = second?['question']?.toString() ?? '';
        followUpAnswer = second?['answer']?.toString() ?? '';
      }
    }
    final quickRepliesList = quickReplies
        .map((e) => e?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    return (overallQuestion, quickRepliesList, followUpQuestion, overallAnswer, followUpAnswer);
  }

  Log _parseLogFromMap(Map<String, dynamic> logMap) {
    final id = logMap['id']?.toString() ?? '';
    final startTs = logMap['startTimestamp']?.toString();
    if (startTs == null) throw Exception('Invalid log: missing startTimestamp');

    final createdAt = DateTime.parse(startTs);

    final rawEntries = logMap['logEntries'] as List<dynamic>? ?? [];
    final entries = <LogEntry>[];
    for (var i = 0; i < rawEntries.length; i++) {
      final e = rawEntries[i] as Map<String, dynamic>;
      final ts = e['timestamp']?.toString();
      if (ts == null) continue;
      final timestamp = DateTime.parse(ts);
      final imageUrl = e['imageUrl']?.toString() ?? '';
      final reflectionText = e['reflectionText']?.toString();
      final question = e['question']?.toString();
      final address = e['address']?.toString();
      final latVal = e['lat'];
      final lngVal = e['lng'];
      final lat = latVal != null ? (latVal is num ? latVal.toDouble() : double.tryParse(latVal.toString())) : null;
      final lng = lngVal != null ? (lngVal is num ? lngVal.toDouble() : double.tryParse(lngVal.toString())) : null;
      entries.add(
        LogEntry(
          id: '${id}_$i',
          imageUrl: imageUrl,
          timestamp: timestamp,
          description: reflectionText != null && reflectionText.isNotEmpty ? reflectionText : null,
          question: question != null && question.isNotEmpty ? question : null,
          address: address != null && address.isNotEmpty ? address : null,
          lat: lat,
          lng: lng,
        ),
      );
    }

    final (overallQuestion, quickReplies, followUpQuestion, overallAnswer, followUpAnswer) =
        _parseReflectionFields(logMap);

    final imageTagQuestion = logMap['imageTagQuestion']?.toString() ?? '';
    final imageTagQuickRepliesRaw = logMap['imageTagQuickReplies'] as List<dynamic>? ?? [];
    final imageTagQuickReplies = imageTagQuickRepliesRaw
        .map((e) => e?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    final imageTagAnswer = logMap['imageTagAnswer']?.toString() ?? '';

    final tracking = _parseTrackingFromMap(logMap['logTracking']);
    final overallReflection = logMap['overallReflection']?.toString();
    final overallReflectionVal = overallReflection != null && overallReflection.isNotEmpty
        ? overallReflection
        : null;
    final overallAiSummary = logMap['overallAiSummary']?.toString();
    final overallAiSummaryVal = overallAiSummary != null && overallAiSummary.isNotEmpty
        ? overallAiSummary
        : null;
    final scrapbookImageUrl = logMap['scrapbookImageUrl']?.toString();
    final scrapbookImageUrlVal = scrapbookImageUrl != null && scrapbookImageUrl.isNotEmpty
        ? scrapbookImageUrl
        : null;

    return Log(
      id: id,
      createdAt: createdAt,
      entries: entries,
      overallQuestion: overallQuestion,
      quickReplies: quickReplies,
      followUpQuestion: followUpQuestion,
      overallAnswer: overallAnswer,
      followUpAnswer: followUpAnswer,
      imageTagQuestion: imageTagQuestion,
      imageTagQuickReplies: imageTagQuickReplies,
      imageTagAnswer: imageTagAnswer,
      tracking: tracking,
      overallReflection: overallReflectionVal,
      overallAiSummary: overallAiSummaryVal,
      scrapbookImageUrl: scrapbookImageUrlVal,
    );
  }

  LogTracking? _parseTrackingFromMap(dynamic raw) {
    if (raw == null) return null;
    final map = raw as Map<String, dynamic>;
    final sessionsRaw = map['sessions'] as List<dynamic>? ?? [];
    if (sessionsRaw.isEmpty) return null;

    final sessions = <LogTrackingSession>[];
    for (final s in sessionsRaw) {
      final sessionMap = s as Map<String, dynamic>;
      final pointsRaw = sessionMap['points'] as List<dynamic>? ?? [];
      final points = <LogTrackingPoint>[];
      for (final p in pointsRaw) {
        final pm = p as Map<String, dynamic>;
        final latVal = pm['lat'];
        final lngVal = pm['lng'];
        if (latVal != null && lngVal != null) {
          final lat = latVal is num ? latVal.toDouble() : double.tryParse(latVal.toString());
          final lng = lngVal is num ? lngVal.toDouble() : double.tryParse(lngVal.toString());
          if (lat != null && lng != null) {
            points.add(LogTrackingPoint(
              lat: lat,
              lng: lng,
              timestamp: pm['timestamp']?.toString() ?? '',
            ));
          }
        }
      }
      if (points.isNotEmpty) {
        sessions.add(LogTrackingSession(points: points));
      }
    }
    if (sessions.isEmpty) return null;

    return LogTracking(
      logId: map['logId']?.toString() ?? '',
      sessions: sessions,
    );
  }
}
