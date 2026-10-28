import 'package:mambo/core/api/api_client.dart';
import 'package:mambo/core/geo/geo_point.dart';
import 'package:mambo/services/graphql_operations.dart';

/// Typed-by-name access to the backend's GraphQL operations.
///
/// All requests go through [ApiClient], which adds the access token, a
/// timeout and uniform error handling and throws an `ApiException` on any
/// failure. Documents live in [GraphQLOperations]; arguments always travel as
/// variables.
class GraphQLService {
  GraphQLService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  /// Operations that wait for a language model need far longer than CRUD.
  static const Duration _aiTimeout = Duration(minutes: 2);

  final ApiClient _client;

  /// Runs [document] and wraps the result as `{'data': ...}`, the shape the
  /// walk pages read.
  Future<Map<String, dynamic>> _run(
    String document,
    Map<String, dynamic> variables, {
    Duration? timeout,
  }) async {
    final data = await _client.execute(
      document,
      variables: variables,
      timeout: timeout,
    );
    return {'data': data};
  }

  // ---------------------------------------------------------------------------
  // Walks
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getCompletedWalks({required String userId}) =>
      _run(GraphQLOperations.completedWalks, {'userId': userId});

  Future<Map<String, dynamic>> generateWalk({
    required String userId,
    required String location,
    required List<String> keywords,
    required double duration,
  }) => _run(GraphQLOperations.generateWalk, {
    'userId': userId,
    'location': location,
    'keywords': keywords.join(' '),
    'duration': duration.toInt(),
  }, timeout: _aiTimeout);

  Future<Map<String, dynamic>> generateTask({required String walkId}) => _run(
    GraphQLOperations.generateTask,
    {'walkId': walkId},
    timeout: _aiTimeout,
  );

  /// The backend accepts the photo without coordinates when there is no
  /// location fix; they are then left out.
  Future<Map<String, dynamic>> verifyTaskWithGpt({
    required String walkId,
    required String imageUrl,
    double? latitude,
    double? longitude,
  }) {
    final hasFix = latitude != null && longitude != null;
    return _run(GraphQLOperations.verifyTask, {
      'walkId': walkId,
      'imageUrl': imageUrl,
      if (hasFix) 'latitude': latitude,
      if (hasFix) 'longitude': longitude,
    }, timeout: _aiTimeout);
  }

  Future<Map<String, dynamic>> updateWalkStatus({
    required String walkId,
    required String status,
  }) => _run(GraphQLOperations.updateWalkStatus, {
    'walkId': walkId,
    'status': status,
  });

  Future<Map<String, dynamic>> addWalkCoordinate({
    required String walkId,
    required String userId,
    required double latitude,
    required double longitude,
    required String timestamp,
  }) => _run(GraphQLOperations.addWalkCoordinate, {
    'walkId': walkId,
    'userId': userId,
    'latitude': latitude,
    'longitude': longitude,
    'timestamp': timestamp,
  });

  Future<Map<String, dynamic>> updateWalkStats({
    required String walkId,
    required double distanceTraveled,
    required int timeSpent,
  }) => _run(GraphQLOperations.updateWalkStats, {
    'walkId': walkId,
    'distanceTraveled': distanceTraveled,
    'timeSpent': timeSpent,
  });

  Future<Map<String, dynamic>> getAllTasksImages({required String walkId}) =>
      _run(GraphQLOperations.allTasksImages, {'walkId': walkId});

  Future<Map<String, dynamic>> generateWalkSummary({required String walkId}) =>
      _run(
        GraphQLOperations.walkSummary,
        {'walkId': walkId},
        timeout: _aiTimeout,
      );

  Future<Map<String, dynamic>> selectLocations({
    required String walkId,
    required List<int> locationIndexes,
  }) => _run(GraphQLOperations.selectLocations, {
    'walkId': walkId,
    'locationIndexes': locationIndexes,
  });

  Future<Map<String, dynamic>> collectLocation({
    required String walkId,
    required int locationIndex,
  }) => _run(GraphQLOperations.collectLocation, {
    'walkId': walkId,
    'locationIndex': locationIndex,
  });

  Future<Map<String, dynamic>> addFavoriteLocation({
    required String walkId,
    required double latitude,
    required double longitude,
    required String photoUrl,
  }) => _run(GraphQLOperations.addFavoriteLocation, {
    'walkId': walkId,
    'latitude': latitude,
    'longitude': longitude,
    'photoUrl': photoUrl,
  });

  Future<Map<String, dynamic>> getFavoriteLocations({required String walkId}) =>
      _run(GraphQLOperations.favoriteLocations, {'walkId': walkId});

  Future<Map<String, dynamic>> getWalk({required String walkId}) =>
      _run(GraphQLOperations.walk, {'id': walkId});

  Future<Map<String, dynamic>> getWalkTracking({required String walkId}) =>
      _run(GraphQLOperations.walkTracking, {'walkId': walkId});

  Future<Map<String, dynamic>> getLatestInProgressWalk({
    required String userId,
  }) => _run(GraphQLOperations.latestInProgressWalk, {'userId': userId});

  // ---------------------------------------------------------------------------
  // Logs (free-form records)
  // ---------------------------------------------------------------------------

  /// Adds a log entry. When [logId] is omitted the backend appends to today's
  /// log or creates one. Returns the `addLogEntry` payload.
  Future<Map<String, dynamic>> addLogEntry({
    required String userId,
    required String imageUrl,
    String reflectionText = '',
    String? logId,
    String? timestamp,
    double? lat,
    double? lng,
    int? timezoneOffsetMinutes,
  }) async {
    final data = await _client.execute(
      GraphQLOperations.addLogEntry,
      variables: {
        'userId': userId,
        'logId': logId,
        'timestamp': timestamp ?? DateTime.now().toUtc().toIso8601String(),
        'imageUrl': imageUrl,
        'reflectionText': reflectionText,
        'lat': ?lat,
        'lng': ?lng,
        'timezoneOffsetMinutes': ?timezoneOffsetMinutes,
      },
      timeout: _aiTimeout,
    );
    return _requireSuccess(data['addLogEntry'], 'addLogEntry');
  }

  /// Updates the reflection text of the latest entry of a log.
  Future<Map<String, dynamic>> updateLogEntryReflection({
    required String logId,
    required String userId,
    required String reflectionText,
  }) async {
    final data = await _client.execute(
      GraphQLOperations.updateLogEntryReflection,
      variables: {
        'logId': logId,
        'userId': userId,
        'reflectionText': reflectionText,
      },
    );
    return _requireSuccess(
      data['updateLogEntryReflection'],
      'updateLogEntryReflection',
    );
  }

  /// Finds or creates today's log, starts a tracking session and returns the
  /// log id.
  Future<String> startLogTracking({
    required String userId,
    required int timezoneOffsetMinutes,
  }) async {
    final data = await _client.execute(
      GraphQLOperations.startLogTracking,
      variables: {
        'userId': userId,
        'timezoneOffsetMinutes': timezoneOffsetMinutes,
      },
    );
    final logId = (data['startLogTracking'] as Map?)?['logId']?.toString();
    if (logId == null) {
      throw Exception('No logId from startLogTracking');
    }
    return logId;
  }

  /// Adds a point to the current tracking session. Returns the session's
  /// points for display, or null when the backend did not accept the point.
  Future<List<GeoPoint>?> addLogTrackingPoint({
    required String logId,
    required String userId,
    required double lat,
    required double lng,
    required String timestamp,
  }) async {
    final data = await _client.execute(
      GraphQLOperations.addLogTrackingPoint,
      variables: {
        'logId': logId,
        'userId': userId,
        'lat': lat,
        'lng': lng,
        'timestamp': timestamp,
      },
    );
    final result = data['addLogTrackingPoint'];
    if (result is! Map || result['success'] != true) return null;
    final points = result['latestSession'];
    if (points is! List) return null;
    return [for (final point in points) ?GeoPoint.tryParse(point)];
  }

  /// Ends the current tracking session.
  Future<void> endLogTrackingSession({required String logId}) async {
    await _client.execute(
      GraphQLOperations.endLogTrackingSession,
      variables: {'logId': logId},
    );
  }

  /// Fetches all logs of a user. Returns the `data` object.
  Future<Map<String, dynamic>> getLogs({required String userId}) =>
      _client.execute(GraphQLOperations.logs, variables: {'userId': userId});

  /// Returns the log of [date] together with AI-generated reflection
  /// questions, or null when there is no log for that date.
  Future<Map<String, dynamic>?> getLogForReview({
    required String userId,
    required String date,
    required int timezoneOffsetMinutes,
  }) async {
    final data = await _client.execute(
      GraphQLOperations.logForReview,
      variables: {
        'userId': userId,
        'date': date,
        'timezoneOffsetMinutes': timezoneOffsetMinutes,
      },
      timeout: _aiTimeout,
    );
    return _logOf(data['getLogForReview']);
  }

  /// Regenerates the reflection questions of a log.
  Future<Map<String, dynamic>?> regenerateReflectionQuestion({
    required String logId,
    required String userId,
  }) async {
    final data = await _client.execute(
      GraphQLOperations.regenerateReflectionQuestion,
      variables: {'logId': logId, 'userId': userId},
      timeout: _aiTimeout,
    );
    return _logOf(data['regenerateReflectionQuestion']);
  }

  /// Saves the reflection answers of a log. Null arguments are left unchanged.
  Future<Map<String, dynamic>?> updateReflectionAnswers({
    required String logId,
    String? overallAnswer,
    String? followUpAnswer,
    String? overallReflection,
    String? imageTagAnswer,
  }) async {
    final data = await _client.execute(
      GraphQLOperations.updateReflectionAnswers,
      variables: {
        'logId': logId,
        'overallAnswer': ?overallAnswer,
        'followUpAnswer': ?followUpAnswer,
        'overallReflection': ?overallReflection,
        'imageTagAnswer': ?imageTagAnswer,
      },
    );
    return _logOf(data['updateReflectionAnswers']);
  }

  /// Replaces the AI summary of a log with the user's own text.
  Future<Map<String, dynamic>?> updateOverallAiSummary({
    required String logId,
    required String userId,
    required String overallAiSummary,
  }) async {
    final data = await _client.execute(
      GraphQLOperations.updateOverallAiSummary,
      variables: {
        'logId': logId,
        'userId': userId,
        'overallAiSummary': overallAiSummary,
      },
    );
    return _logOf(data['updateOverallAiSummary']);
  }

  /// Generates a scrapbook cover for a log. Returns the image URL, or null
  /// when the backend reports failure.
  Future<String?> generateLogScrapbookImage({
    required String logId,
    required String userId,
  }) async {
    final data = await _client.execute(
      GraphQLOperations.generateLogScrapbookImage,
      variables: {'logId': logId, 'userId': userId},
      timeout: _aiTimeout,
    );
    final result = data['generateLogScrapbookImage'];
    if (result is! Map || result['success'] != true) return null;
    return result['imageUrl']?.toString();
  }

  // ---------------------------------------------------------------------------

  /// Returns [payload] when it reports success, otherwise throws with the
  /// backend's message.
  Map<String, dynamic> _requireSuccess(Object? payload, String operation) {
    if (payload is! Map<String, dynamic>) {
      throw Exception('No response from $operation');
    }
    if (payload['success'] != true) {
      throw Exception(payload['message']?.toString() ?? '$operation failed');
    }
    return payload;
  }

  Map<String, dynamic>? _logOf(Object? payload) {
    if (payload is! Map<String, dynamic>) return null;
    return payload['log'] as Map<String, dynamic>?;
  }
}
