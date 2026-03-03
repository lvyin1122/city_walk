/// Log service for log-related data.
/// Currently provides dummy data; GraphQL integration (e.g. logsByUserId, logById) to be added later.
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
  final String? address;
  final double? lat;
  final double? lng;

  LogEntry({
    required this.id,
    required this.imageUrl,
    required this.timestamp,
    this.description,
    this.address,
    this.lat,
    this.lng,
  });
}

class LogService {
  // Dummy data for development. Replace with GraphQL queries when backend is ready.
  static final List<Log> _dummyLogs = _buildDummyLogs();

  static List<Log> _buildDummyLogs() {
    final now = DateTime.now();
    return [
      Log(
        id: '1',
        createdAt: now.subtract(const Duration(hours: 2)),
        entries: [
          LogEntry(
            id: '1-1',
            imageUrl: 'https://placehold.co/400x300/lightgreen/333',
            timestamp: now.subtract(const Duration(hours: 2)),
            description: 'Beautiful sunset at the park.',
            address: 'Central Park, New York, NY',
            lat: 40.7851,
            lng: -73.9683,
          ),
          LogEntry(
            id: '1-2',
            imageUrl: 'https://placehold.co/400x300/lightblue/333',
            timestamp: now.subtract(const Duration(hours: 1, minutes: 45)),
            description: null,
            address: '5th Avenue, New York, NY',
            lat: 40.7580,
            lng: -73.9855,
          ),
          LogEntry(
            id: '1-3',
            imageUrl: 'https://placehold.co/400x300/amber/333',
            timestamp: now.subtract(const Duration(hours: 1, minutes: 30)),
            description: 'Found a great coffee spot!',
            address: '123 Coffee St, New York, NY',
            lat: 40.7484,
            lng: -73.9857,
          ),
        ],
      ),
      Log(
        id: '2',
        createdAt: now.subtract(const Duration(days: 1)),
        entries: [
          LogEntry(
            id: '2-1',
            imageUrl: 'https://placehold.co/400x300/lightgreen/333',
            timestamp: now.subtract(const Duration(days: 1)),
            description: 'Early morning vibes.',
            address: 'Brooklyn Bridge Park, Brooklyn, NY',
            lat: 40.7024,
            lng: -73.9875,
          ),
          LogEntry(
            id: '2-2',
            imageUrl: 'https://placehold.co/400x300/lightgray/333',
            timestamp: now.subtract(const Duration(days: 1, minutes: -20)),
            description: null,
            address: 'DUMBO, Brooklyn, NY',
            lat: 40.7033,
            lng: -73.9892,
          ),
        ],
      ),
      Log(
        id: '3',
        createdAt: now.subtract(const Duration(days: 2)),
        entries: [
          LogEntry(
            id: '3-1',
            imageUrl: 'https://placehold.co/400x300/teal/333',
            timestamp: now.subtract(const Duration(days: 2)),
            description: 'Exploring the neighborhood.',
            address: 'Williamsburg, Brooklyn, NY',
            lat: 40.7081,
            lng: -73.9571,
          ),
        ],
      ),
      Log(
        id: '4',
        createdAt: now.subtract(const Duration(days: 3)),
        entries: [
          LogEntry(
            id: '4-1',
            imageUrl: 'https://placehold.co/400x300/indigo/333',
            timestamp: now.subtract(const Duration(days: 3)),
            description: null,
            address: 'Times Square, New York, NY',
            lat: 40.7580,
            lng: -73.9855,
          ),
          LogEntry(
            id: '4-2',
            imageUrl: 'https://placehold.co/400x300/purple/333',
            timestamp: now.subtract(const Duration(days: 3, minutes: -15)),
            description: 'Lunch at the new place.',
            address: 'Grand Central Terminal, New York, NY',
            lat: 40.7527,
            lng: -73.9772,
          ),
          LogEntry(
            id: '4-3',
            imageUrl: 'https://placehold.co/400x300/deeppink/333',
            timestamp: now.subtract(const Duration(days: 3, minutes: -45)),
            description: 'Hello',
            address: 'Bryant Park, New York, NY',
            lat: 40.7542,
            lng: -73.9840,
          ),
        ],
      ),
    ];
  }

  /// Fetches all logs for the current user.
  /// TODO: Replace with GraphQL query logsByUserId when backend is ready.
  Future<List<Log>> getLogs() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final logs = List<Log>.from(_dummyLogs);
    logs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return logs;
  }

  /// Fetches a single log by id.
  /// TODO: Replace with GraphQL query logById when backend is ready.
  Future<Log?> getLogDetail(String logId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    for (final log in _dummyLogs) {
      if (log.id == logId) return log;
    }
    return null;
  }
}
