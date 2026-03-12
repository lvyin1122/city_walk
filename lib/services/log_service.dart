import 'package:mambo/services/auth_service.dart';
import 'package:mambo/services/graphql_service.dart';

/// Reflection question with question text and optional answer.
class ReflectionQuestion {
  final String question;
  final String answer;

  ReflectionQuestion({required this.question, required this.answer});
}

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
  final List<ReflectionQuestion> reflectionQuestions;
  final LogTracking? tracking;
  final String? overallReflection;
  final String? overallAiSummary;

  Log({
    required this.id,
    required this.createdAt,
    required this.entries,
    this.reflectionQuestions = const [],
    this.tracking,
    this.overallReflection,
    this.overallAiSummary,
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

      final rawQuestions = logMap['reflectionQuestions'] as List<dynamic>? ?? [];
      final reflectionQuestions = rawQuestions
          .map<ReflectionQuestion>((q) {
            final m = q as Map<String, dynamic>;
            return ReflectionQuestion(
              question: m['question']?.toString() ?? '',
              answer: m['answer']?.toString() ?? '',
            );
          })
          .toList();

      final tracking = _parseTrackingFromMap(logMap['logTracking']);

      logs.add(Log(
        id: id,
        createdAt: createdAt,
        entries: entries,
        reflectionQuestions: reflectionQuestions,
        tracking: tracking,
        overallAiSummary: logMap['overallAiSummary']?.toString(),
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

  /// Updates reflection answers and optionally overall reflection.
  Future<Log?> updateReflectionAnswers({
    required String logId,
    List<String>? reflectionAnswers,
    String? overallReflection,
  }) async {
    final logMap = await _graphQLService.updateReflectionAnswers(
      logId: logId,
      reflectionAnswers: reflectionAnswers,
      overallReflection: overallReflection,
    );
    if (logMap == null) return null;
    return _parseLogFromMap(logMap);
  }

  /// Regenerates the reflection question at the given index (0=overall, 1=image).
  Future<Log?> regenerateReflectionQuestion(String logId, int questionIndex) async {
    final user = _authService.getCurrentUser();
    if (user == null) return null;

    final logMap = await _graphQLService.regenerateReflectionQuestion(
      logId: logId,
      questionIndex: questionIndex,
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

    final rawQuestions = logMap['reflectionQuestions'] as List<dynamic>? ?? [];
    final reflectionQuestions = rawQuestions
        .map<ReflectionQuestion>((q) {
          final m = q as Map<String, dynamic>;
          return ReflectionQuestion(
            question: m['question']?.toString() ?? '',
            answer: m['answer']?.toString() ?? '',
          );
        })
        .toList();

    final tracking = _parseTrackingFromMap(logMap['logTracking']);
    final overallReflection = logMap['overallReflection']?.toString();
    final overallReflectionVal = overallReflection != null && overallReflection.isNotEmpty
        ? overallReflection
        : null;
    final overallAiSummary = logMap['overallAiSummary']?.toString();
    final overallAiSummaryVal = overallAiSummary != null && overallAiSummary.isNotEmpty
        ? overallAiSummary
        : null;

    return Log(
      id: id,
      createdAt: createdAt,
      entries: entries,
      reflectionQuestions: reflectionQuestions,
      tracking: tracking,
      overallReflection: overallReflectionVal,
      overallAiSummary: overallAiSummaryVal,
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
