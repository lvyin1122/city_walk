import 'package:mambo/core/api/api_client.dart';
import 'package:mambo/core/api/graphql_literals.dart';
import 'package:mambo/core/geo/geo_point.dart';

/// Typed-by-name access to the backend's GraphQL operations.
///
/// All requests go through [ApiClient], which adds the access token, a
/// timeout and uniform error handling and throws an `ApiException` on any
/// failure.
///
/// The walk operations place their arguments inline in the document, because
/// the backend schema (and so the variable types) is not available to the
/// client. Every inline string goes through [gqlString]. The log operations
/// use GraphQL variables.
class GraphQLService {
  GraphQLService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  /// Operations that wait for a language model need far longer than CRUD.
  static const Duration _aiTimeout = Duration(minutes: 2);

  final ApiClient _client;

  /// Runs [document] and wraps the result as `{'data': ...}`, the shape the
  /// walk pages read.
  Future<Map<String, dynamic>> _run(String document, {Duration? timeout}) async {
    final data = await _client.execute(document, timeout: timeout);
    return {'data': data};
  }

  // ---------------------------------------------------------------------------
  // Walks
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getCompletedWalks({required String userId}) {
    return _run('''
      query {
        completedWalksByUserId(userId: ${gqlString(userId)}) {
          Id
          userId
          totalDuration
          title
          description
          createdAt
          status
          timeSpent
          distanceTraveled
          tasksCompleted
          tasksTotal
          userAddress
          city
          locations {
            name
            description
            estimatedTime
            selected
            collected
            photoUrls
            coordinates {
              latitude
              longitude
            }
          }
          tasks {
            createdTime
            description
            photosRequired
            photosFulfilled
            status
            images {
              url
            }
          }
          favoriteLocations {
            latitude
            longitude
            photoUrl
          }
        }
      }
    ''');
  }

  Future<Map<String, dynamic>> generateWalk({
    required String userId,
    required String location,
    required List<String> keywords,
    required double duration,
  }) {
    return _run('''
      mutation {
        generateWalkWithGpt(
          userId: ${gqlString(userId)}
          location: ${gqlString(location)}
          keywords: ${gqlString(keywords.join(' '))}
          duration: ${duration.toInt()}
        ) {
          walk {
            Id
            userId
            totalDuration
            title
            description
            createdAt
            status
            locations {
              name
              description
              estimatedTime
              collected
              coordinates {
                latitude
                longitude
              }
              photoUrls
            }
            tasks {
              createdTime
              description
              photosRequired
              photosFulfilled
              status
            }
          }
        }
      }
    ''', timeout: _aiTimeout);
  }

  Future<Map<String, dynamic>> generateTask({required String walkId}) {
    return _run('''
      mutation {
        generateTaskWithGpt(
          walkId: ${gqlString(walkId)}
        ) {
          task {
            createdTime
            description
            status
            photosFulfilled
            photosRequired
          }
        }
      }
    ''', timeout: _aiTimeout);
  }

  Future<Map<String, dynamic>> verifyTaskWithGpt({
    required String walkId,
    required String imageUrl,
    double? latitude,
    double? longitude,
  }) {
    final coordinates =
        latitude != null && longitude != null
            ? 'latitude: $latitude\n          longitude: $longitude'
            : '';
    return _run('''
      mutation {
        verifyTaskWithGpt(
          walkId: ${gqlString(walkId)}
          imageUrl: ${gqlString(imageUrl)}
          $coordinates
        ) {
          success
          message
          photosFulfilled
          taskStatus
        }
      }
    ''', timeout: _aiTimeout);
  }

  Future<Map<String, dynamic>> updateWalkStatus({
    required String walkId,
    required String status,
  }) {
    return _run('''
      mutation {
        updateWalkStatus(
          walkId: ${gqlString(walkId)}
          status: ${gqlString(status)}
        ) {
          walk {
            Id
            userId
            totalDuration
            title
            description
            createdAt
            status
          }
        }
      }
    ''');
  }

  Future<Map<String, dynamic>> addWalkCoordinate({
    required String walkId,
    required String userId,
    required double latitude,
    required double longitude,
    required String timestamp,
  }) {
    return _run('''
      mutation {
        addWalkCoordinate(
          walkId: ${gqlString(walkId)}
          userId: ${gqlString(userId)}
          latitude: $latitude
          longitude: $longitude
          timestamp: ${gqlString(timestamp)}
        ) {
          walkTracking {
            walkId
            userId
          }
        }
      }
    ''');
  }

  Future<Map<String, dynamic>> updateWalkStats({
    required String walkId,
    required double distanceTraveled,
    required int timeSpent,
  }) {
    return _run('''
      mutation {
        updateWalkStats(
          walkId: ${gqlString(walkId)}
          distanceTraveled: $distanceTraveled
          timeSpent: $timeSpent
        ) {
          walk {
            Id
            userId
            totalDuration
            title
            description
            createdAt
            status
            timeSpent
            distanceTraveled
            tasksCompleted
            tasksTotal
          }
        }
      }
    ''');
  }

  Future<Map<String, dynamic>> getAllTasksImages({required String walkId}) {
    return _run('''
      mutation {
        getAllTasksImages(
          walkId: ${gqlString(walkId)}
        ) {
          images {
            url
            coordinates {
              latitude
              longitude
            }
          }
        }
      }
    ''');
  }

  Future<Map<String, dynamic>> generateWalkSummary({required String walkId}) {
    return _run('''
      mutation {
        generateWalkSummary(
          walkId: ${gqlString(walkId)}
        ) {
          summary
        }
      }
    ''', timeout: _aiTimeout);
  }

  Future<Map<String, dynamic>> selectLocations({
    required String walkId,
    required List<int> locationIndexes,
  }) {
    return _run('''
      mutation {
        selectLocations(
          locationIndexes: [${locationIndexes.join(', ')}]
          walkId: ${gqlString(walkId)}
        ) {
          walk {
            Id
            userId
            locations {
                name
                description
                estimatedTime
                selected
                collected
                photoUrls
                coordinates {
                    latitude
                    longitude
                }
            }
          }
        }
      }
    ''');
  }

  Future<Map<String, dynamic>> collectLocation({
    required String walkId,
    required int locationIndex,
  }) {
    return _run('''
      mutation {
        collectLocation(
          walkId: ${gqlString(walkId)}
          locationIndex: $locationIndex
        ) {
          walk {
            Id
            status
            locations {
              name
              collected
            }
          }
        }
      }
    ''');
  }

  Future<Map<String, dynamic>> addFavoriteLocation({
    required String walkId,
    required double latitude,
    required double longitude,
    required String photoUrl,
  }) {
    return _run('''
      mutation {
        addFavoriteLocation(
          latitude: $latitude
          longitude: $longitude
          walkId: ${gqlString(walkId)}
          photoUrl: ${gqlString(photoUrl)}
        ) {
          walk {
            favoriteLocations {
              latitude
              longitude
              photoUrl
            }
          }
        }
      }
    ''');
  }

  Future<Map<String, dynamic>> getFavoriteLocations({required String walkId}) {
    return _run('''
      mutation {
        getFavoriteLocations(walkId: ${gqlString(walkId)}) {
          favoriteLocations {
            latitude
            longitude
            photoUrl
          }
        }
      }
    ''');
  }

  Future<Map<String, dynamic>> getWalk({required String walkId}) {
    return _run('''
      query {
        walk(id: ${gqlString(walkId)}) {
          Id
          userId
          totalDuration
          title
          description
          createdAt
          status
          timeSpent
          distanceTraveled
          tasksCompleted
          tasksTotal
          userAddress
          city
          locations {
            name
            description
            estimatedTime
            selected
            collected
            photoUrls
            coordinates {
              latitude
              longitude
            }
          }
          tasks {
            createdTime
            description
            photosRequired
            photosFulfilled
            status
            images {
              url
              coordinates {
                latitude
                longitude
              }
            }
          }
          favoriteLocations {
            latitude
            longitude
            photoUrl
          }
        }
      }
    ''');
  }

  Future<Map<String, dynamic>> getWalkTracking({required String walkId}) {
    return _run('''
      query {
        walkTracking(walkId: ${gqlString(walkId)}) {
          coordinates {
            latitude
            longitude
          }
        }
      }
    ''');
  }

  Future<Map<String, dynamic>> getLatestInProgressWalk({
    required String userId,
  }) {
    return _run('''
      query {
        latestInProgressWalk(userId: ${gqlString(userId)}) {
          Id
        }
      }
    ''');
  }

  // ---------------------------------------------------------------------------
  // Logs (free-form records)
  // ---------------------------------------------------------------------------

  static const String _logEntryFields =
      'timestamp imageUrl reflectionText question quickReplies lat lng address';

  static const String _logTrackingFields = '''
            logTracking {
              logId
              sessions {
                points { lat lng timestamp }
              }
            }''';

  /// Adds a log entry. When [logId] is omitted the backend creates a new log.
  /// Returns the `addLogEntry` payload.
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
      '''
      mutation AddLogEntry(\$userId: String!, \$logId: String, \$timestamp: String!, \$imageUrl: String!, \$reflectionText: String, \$lat: Float, \$lng: Float, \$timezoneOffsetMinutes: Int) {
        addLogEntry(userId: \$userId, logId: \$logId, timestamp: \$timestamp, imageUrl: \$imageUrl, reflectionText: \$reflectionText, lat: \$lat, lng: \$lng, timezoneOffsetMinutes: \$timezoneOffsetMinutes) {
          success
          message
          log {
            id
            userId
            startTimestamp
            logEntries { $_logEntryFields }
          }
        }
      }
    ''',
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
      '''
      mutation UpdateLogEntryReflection(\$logId: String!, \$userId: String!, \$reflectionText: String!) {
        updateLogEntryReflection(logId: \$logId, userId: \$userId, reflectionText: \$reflectionText) {
          success
          message
          log {
            id
            logEntries { $_logEntryFields }
          }
        }
      }
    ''',
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
      '''
      mutation StartLogTracking(\$userId: String!, \$timezoneOffsetMinutes: Int!) {
        startLogTracking(userId: \$userId, timezoneOffsetMinutes: \$timezoneOffsetMinutes) {
          logId
        }
      }
    ''',
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
      '''
      mutation AddLogTrackingPoint(\$logId: String!, \$userId: String!, \$lat: Float!, \$lng: Float!, \$timestamp: String!) {
        addLogTrackingPoint(logId: \$logId, userId: \$userId, lat: \$lat, lng: \$lng, timestamp: \$timestamp) {
          success
          latestSession {
            lat
            lng
          }
        }
      }
    ''',
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
      '''
      mutation EndLogTrackingSession(\$logId: String!) {
        endLogTrackingSession(logId: \$logId) {
          success
        }
      }
    ''',
      variables: {'logId': logId},
    );
  }

  /// Fetches all logs of a user. Returns the `data` object.
  Future<Map<String, dynamic>> getLogs({required String userId}) {
    return _client.execute(
      '''
      query GetLogs(\$userId: String) {
        logs(userId: \$userId) {
          id
          userId
          startTimestamp
          logEntries { $_logEntryFields }
          overallQuestion
          quickReplies
          followUpQuestion
          overallAnswer
          followUpAnswer
          overallReflection
          overallAiSummary
          scrapbookImageUrl
$_logTrackingFields
        }
      }
    ''',
      variables: {'userId': userId},
    );
  }

  /// Returns the log of [date] together with AI-generated reflection
  /// questions, or null when there is no log for that date.
  Future<Map<String, dynamic>?> getLogForReview({
    required String userId,
    required String date,
    required int timezoneOffsetMinutes,
  }) async {
    final data = await _client.execute(
      '''
      mutation GetLogForReview(\$userId: String!, \$date: String!, \$timezoneOffsetMinutes: Int!) {
        getLogForReview(userId: \$userId, date: \$date, timezoneOffsetMinutes: \$timezoneOffsetMinutes) {
          log {
            id
            userId
            startTimestamp
            logEntries { $_logEntryFields }
            overallQuestion
            quickReplies
            followUpQuestion
            overallAnswer
            followUpAnswer
            imageTagQuestion
            imageTagQuickReplies
            imageTagAnswer
            overallReflection
            overallAiSummary
            scrapbookImageUrl
$_logTrackingFields
          }
        }
      }
    ''',
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
      '''
      mutation RegenerateReflectionQuestion(\$logId: String!, \$userId: String!) {
        regenerateReflectionQuestion(logId: \$logId, userId: \$userId) {
          log {
            id
            userId
            startTimestamp
            logEntries { $_logEntryFields }
            overallQuestion
            quickReplies
            followUpQuestion
            overallAnswer
            followUpAnswer
            imageTagQuestion
            imageTagQuickReplies
            imageTagAnswer
            overallReflection
            overallAiSummary
$_logTrackingFields
          }
        }
      }
    ''',
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
      '''
      mutation UpdateReflectionAnswers(\$logId: String!, \$overallAnswer: String, \$followUpAnswer: String, \$overallReflection: String, \$imageTagAnswer: String) {
        updateReflectionAnswers(logId: \$logId, overallAnswer: \$overallAnswer, followUpAnswer: \$followUpAnswer, overallReflection: \$overallReflection, imageTagAnswer: \$imageTagAnswer) {
          log {
            id
            startTimestamp
            logEntries { $_logEntryFields }
            overallQuestion
            quickReplies
            followUpQuestion
            overallAnswer
            followUpAnswer
            imageTagQuestion
            imageTagQuickReplies
            imageTagAnswer
            overallReflection
            overallAiSummary
$_logTrackingFields
          }
        }
      }
    ''',
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
      '''
      mutation UpdateOverallAiSummary(\$logId: String!, \$userId: String!, \$overallAiSummary: String!) {
        updateOverallAiSummary(logId: \$logId, userId: \$userId, overallAiSummary: \$overallAiSummary) {
          log {
            id
            startTimestamp
            logEntries { $_logEntryFields }
            overallQuestion
            quickReplies
            followUpQuestion
            overallAnswer
            followUpAnswer
            overallReflection
            overallAiSummary
$_logTrackingFields
          }
        }
      }
    ''',
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
      '''
      mutation GenerateLogScrapbookImage(\$logId: String!, \$userId: String!) {
        generateLogScrapbookImage(logId: \$logId, userId: \$userId) {
          imageUrl
          success
          message
        }
      }
    ''',
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
