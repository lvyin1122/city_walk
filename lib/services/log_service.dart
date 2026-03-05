import 'package:mambo/services/auth_service.dart';
import 'package:mambo/services/graphql_service.dart';

/// Log service for log-related data.
class Log {
  final String id;
  final DateTime createdAt;
  final List<LogEntry> entries;

  Log({
    required this.id,
    required this.createdAt,
    required this.entries,
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

      logs.add(Log(id: id, createdAt: createdAt, entries: entries));
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
}
