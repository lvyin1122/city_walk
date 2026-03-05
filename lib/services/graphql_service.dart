import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter_dotenv/flutter_dotenv.dart';

const bool _kGraphQLDebugLogging = true; // Set to false to disable

class GraphQLService {
  final String _endpoint = dotenv.env['GRAPHQL_ENDPOINT']!;

  void _debugLog(String operation, Map<String, dynamic> requestBody, http.Response response) {
    if (!_kGraphQLDebugLogging) return;
    developer.log(
      '[GraphQL] $operation',
      name: 'GraphQLService',
    );
    developer.log(
      'Request: endpoint=$_endpoint',
      name: 'GraphQLService',
    );
    try {
      final prettyRequest = const JsonEncoder.withIndent('  ').convert(requestBody);
      developer.log('Request body:\n$prettyRequest', name: 'GraphQLService');
    } catch (_) {}
    developer.log(
      'Response: status=${response.statusCode}',
      name: 'GraphQLService',
    );
    developer.log(
      'Response body:\n${response.body}',
      name: 'GraphQLService',
    );
  }

  // Query all

  // Query all completed walks by userId
  Future<Map<String, dynamic>> getCompletedWalks({
    required String userId,
  }) async {
    final String query = '''
      query {
        completedWalksByUserId(userId: "$userId") {
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
    ''';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'query': query}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
          'Failed to get completed walks: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error getting completed walks: $e');
    }
  }

  Future<Map<String, dynamic>> generateWalk({
    required String userId,
    required String location,
    required List<String> keywords,
    required double duration,
  }) async {
    final String query = '''
      mutation {
        generateWalkWithGpt(
          userId: "$userId"
          location: "$location"
          keywords: "${keywords.join(' ')}"
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
    ''';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'query': query}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to generate walk: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to generate walk: $e');
    }
  }

  Future<Map<String, dynamic>> generateWalks({
    required String userId,
    required String location,
    required List<String> keywords,
    required double duration,
  }) async {
    final String query = '''
      mutation {
        generateWalksWithGpt(
          userId: "$userId"
          location: "$location"
          keywords: "${keywords.join(' ')}"
          duration: ${duration.toInt()}
        ) {
          walks {
            Id
            userId
            title
            description
            totalDuration
            status
            locations {
              name
              coordinates {
                latitude
                longitude
              }
              description
              estimatedTime
            }
            tasks {
              status
            }
          }
        }
      }
    ''';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'query': query}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to generate walks: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error generating walks: $e');
    }
  }

  Future<Map<String, dynamic>> generateTask({required String walkId}) async {
    final String query = '''
      mutation {
        generateTaskWithGpt(
          walkId: "$walkId"
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
    ''';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'query': query}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to generate task: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error generating task: $e');
    }
  }

  Future<Map<String, dynamic>> verifyTaskWithGpt({
    required String walkId,
    required String imageUrl,
    String? latitude,
    String? longitude,
  }) async {
    final String query =
        latitude != null && longitude != null
            ? '''
      mutation {
        verifyTaskWithGpt(
          walkId: "$walkId"
          imageUrl: "$imageUrl"
          latitude: $latitude
          longitude: $longitude
        ) {
          success
          message
          photosFulfilled
          taskStatus
        }
      }
    '''
            : '''
      mutation {
        verifyTaskWithGpt(
          walkId: "$walkId"
          imageUrl: "$imageUrl"
        ) {
          success
          message
          photosFulfilled
          taskStatus
        }
      }
    ''';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'query': query}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to verify task: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error verifying task: $e');
    }
  }

  Future<Map<String, dynamic>> updateWalkStatus({
    required String walkId,
    required String status,
  }) async {
    final String query = '''
      mutation {
        updateWalkStatus(
          walkId: "$walkId"
          status: "$status"
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
    ''';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'query': query}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to update walk status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating walk status: $e');
    }
  }

  Future<Map<String, dynamic>> addWalkCoordinate({
    required String walkId,
    required String userId,
    required double latitude,
    required double longitude,
    required String timestamp,
  }) async {
    final String query = '''
      mutation {
        addWalkCoordinate(
          walkId: "$walkId"
          userId: "$userId"
          latitude: $latitude
          longitude: $longitude
          timestamp: "$timestamp"
        ) {
          walkTracking {
            walkId
            userId
          }
        }
      }
    ''';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'query': query}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
          'Failed to add walk coordinate: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error adding walk coordinate: $e');
    }
  }

  Future<Map<String, dynamic>> updateWalkStats({
    required String walkId,
    required double distanceTraveled,
    required int timeSpent,
  }) async {
    final String query = '''
      mutation {
        updateWalkStats(
          walkId: "$walkId"
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
    ''';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'query': query}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to update walk stats: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating walk stats: $e');
    }
  }

  Future<Map<String, dynamic>> getAllTasksImages({
    required String walkId,
  }) async {
    final String query = '''
      mutation {
        getAllTasksImages(
          walkId: "$walkId"
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
    ''';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'query': query}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get task images: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting task images: $e');
    }
  }

  Future<Map<String, dynamic>> generateWalkSummary({
    required String walkId,
  }) async {
    final String query = '''
      mutation {
        generateWalkSummary(
          walkId: "$walkId"
        ) {
          summary
        }
      }
    ''';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'query': query}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
          'Failed to generate walk summary: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error generating walk summary: $e');
    }
  }

  Future<Map<String, dynamic>> selectLocations({
    required String walkId,
    required List<int> locationIndexes,
  }) async {
    final String query = '''
      mutation {
        selectLocations(
          locationIndexes: ${locationIndexes.map((index) => index).toList()}
          walkId: "$walkId"
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
    ''';

    print('query: $query');

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'query': query}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to select locations: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error selecting locations: $e');
    }
  }

  Future<Map<String, dynamic>> collectLocation({
    required String walkId,
    required int locationIndex,
  }) async {
    final String query = '''
      mutation {
        collectLocation(
          walkId: "$walkId"
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
    ''';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'query': query}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to collect location:  {response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error collecting location: $e');
    }
  }

  Future<Map<String, dynamic>> addFavoriteLocation({
    required String walkId,
    required double latitude,
    required double longitude,
    required String photoUrl,
  }) async {
    final String query = '''
      mutation {
        addFavoriteLocation(
          latitude: $latitude
          longitude: $longitude
          walkId: "$walkId"
          photoUrl: "$photoUrl"
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
    ''';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'query': query}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
          'Failed to add favorite location: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error adding favorite location: $e');
    }
  }

  /// Add a log entry via GraphQL addLogEntry mutation.
  /// If logId is omitted, backend creates a new log. Returns response or throws.
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
    final ts = timestamp ?? DateTime.now().toUtc().toIso8601String();
    final query = '''
      mutation AddLogEntry(\$userId: String!, \$logId: String, \$timestamp: String!, \$imageUrl: String!, \$reflectionText: String, \$lat: Float, \$lng: Float, \$timezoneOffsetMinutes: Int) {
        addLogEntry(userId: \$userId, logId: \$logId, timestamp: \$timestamp, imageUrl: \$imageUrl, reflectionText: \$reflectionText, lat: \$lat, lng: \$lng, timezoneOffsetMinutes: \$timezoneOffsetMinutes) {
          success
          message
          log {
            id
            userId
            startTimestamp
            logEntries { timestamp imageUrl reflectionText question lat lng address }
          }
        }
      }
    ''';
    final variables = <String, dynamic>{
      'userId': userId,
      'logId': logId,
      'timestamp': ts,
      'imageUrl': imageUrl,
      'reflectionText': reflectionText,
    };
    if (lat != null) variables['lat'] = lat;
    if (lng != null) variables['lng'] = lng;
    if (timezoneOffsetMinutes != null) variables['timezoneOffsetMinutes'] = timezoneOffsetMinutes;

    try {
      final requestBody = {'query': query, 'variables': variables};
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      _debugLog('addLogEntry', requestBody, response);

      final body = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to add log entry: ${response.statusCode}',
        );
      }

      if (body['errors'] != null) {
        final errors = body['errors'] as List;
        final msg = errors.isNotEmpty
            ? (errors.first as Map<String, dynamic>)['message']?.toString() ?? 'GraphQL error'
            : 'GraphQL error';
        throw Exception(msg);
      }

      final data = body['data'] as Map<String, dynamic>?;
      final addLogEntryResult = data?['addLogEntry'] as Map<String, dynamic>?;
      if (addLogEntryResult == null) {
        throw Exception('No response from addLogEntry');
      }
      if (addLogEntryResult['success'] != true) {
        final msg = addLogEntryResult['message']?.toString() ?? 'Add log entry failed';
        throw Exception(msg);
      }
      return addLogEntryResult;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Error adding log entry: $e');
    }
  }

  /// Update the latest log entry's reflection text via GraphQL updateLogEntryReflection mutation.
  Future<Map<String, dynamic>> updateLogEntryReflection({
    required String logId,
    required String userId,
    required String reflectionText,
  }) async {
    final query = '''
      mutation UpdateLogEntryReflection(\$logId: String!, \$userId: String!, \$reflectionText: String!) {
        updateLogEntryReflection(logId: \$logId, userId: \$userId, reflectionText: \$reflectionText) {
          success
          message
          log {
            id
            logEntries { timestamp imageUrl reflectionText question lat lng address }
          }
        }
      }
    ''';
    final variables = {
      'logId': logId,
      'userId': userId,
      'reflectionText': reflectionText,
    };

    try {
      final requestBody = {'query': query, 'variables': variables};
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      _debugLog('updateLogEntryReflection', requestBody, response);

      final body = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to update log entry reflection: ${response.statusCode}',
        );
      }

      if (body['errors'] != null) {
        final errors = body['errors'] as List;
        final msg = errors.isNotEmpty
            ? (errors.first as Map<String, dynamic>)['message']?.toString() ?? 'GraphQL error'
            : 'GraphQL error';
        throw Exception(msg);
      }

      final data = body['data'] as Map<String, dynamic>?;
      final result = data?['updateLogEntryReflection'] as Map<String, dynamic>?;
      if (result == null) {
        throw Exception('No response from updateLogEntryReflection');
      }
      if (result['success'] != true) {
        final msg = result['message']?.toString() ?? 'Update reflection failed';
        throw Exception(msg);
      }
      return result;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Error updating log entry reflection: $e');
    }
  }

  /// Fetch logs for a user via GraphQL logs query.
  Future<Map<String, dynamic>> getLogs({required String userId}) async {
    final query = '''
      query GetLogs(\$userId: String) {
        logs(userId: \$userId) {
          id
          userId
          startTimestamp
          logEntries {
            timestamp
            imageUrl
            reflectionText
            question
            lat
            lng
            address
          }
          reflectionQuestions {
            question
            answer
          }
        }
      }
    ''';
    final variables = {'userId': userId};

    try {
      final requestBody = {'query': query, 'variables': variables};
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      _debugLog('getLogs', requestBody, response);

      final body = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        throw Exception('Failed to get logs: ${response.statusCode}');
      }

      if (body['errors'] != null) {
        final errors = body['errors'] as List;
        final msg = errors.isNotEmpty
            ? (errors.first as Map<String, dynamic>)['message']?.toString() ?? 'GraphQL error'
            : 'GraphQL error';
        throw Exception(msg);
      }

      return body['data'] as Map<String, dynamic>? ?? {};
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Error getting logs: $e');
    }
  }

  /// Get log for review with AI-generated reflection questions.
  /// Returns the log or null if no log found for the date.
  Future<Map<String, dynamic>?> getLogForReview({
    required String userId,
    required String date,
    required int timezoneOffsetMinutes,
  }) async {
    final query = '''
      mutation GetLogForReview(\$userId: String!, \$date: String!, \$timezoneOffsetMinutes: Int!) {
        getLogForReview(userId: \$userId, date: \$date, timezoneOffsetMinutes: \$timezoneOffsetMinutes) {
          log {
            id
            userId
            startTimestamp
            logEntries {
              timestamp
              imageUrl
              reflectionText
              question
              lat
              lng
              address
            }
            reflectionQuestions {
              question
              answer
            }
            overallReflection
          }
        }
      }
    ''';
    final variables = {
      'userId': userId,
      'date': date,
      'timezoneOffsetMinutes': timezoneOffsetMinutes,
    };

    try {
      final requestBody = {'query': query, 'variables': variables};
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      _debugLog('getLogForReview', requestBody, response);

      final body = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        throw Exception('Failed to get log for review: ${response.statusCode}');
      }

      if (body['errors'] != null) {
        final errors = body['errors'] as List;
        final msg = errors.isNotEmpty
            ? (errors.first as Map<String, dynamic>)['message']?.toString() ?? 'GraphQL error'
            : 'GraphQL error';
        throw Exception(msg);
      }

      final data = body['data'] as Map<String, dynamic>?;
      final result = data?['getLogForReview'] as Map<String, dynamic>?;
      return result?['log'] as Map<String, dynamic>?;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Error getting log for review: $e');
    }
  }

  /// Regenerate a reflection question at the given index (0=overall, 1=image).
  Future<Map<String, dynamic>?> regenerateReflectionQuestion({
    required String logId,
    required int questionIndex,
    required String userId,
  }) async {
    final query = '''
      mutation RegenerateReflectionQuestion(\$logId: String!, \$questionIndex: Int!, \$userId: String!) {
        regenerateReflectionQuestion(logId: \$logId, questionIndex: \$questionIndex, userId: \$userId) {
          log {
            id
            userId
            startTimestamp
            logEntries {
              timestamp
              imageUrl
              reflectionText
              question
              lat
              lng
              address
            }
            reflectionQuestions {
              question
              answer
            }
            overallReflection
          }
        }
      }
    ''';
    final variables = {
      'logId': logId,
      'questionIndex': questionIndex,
      'userId': userId,
    };

    try {
      final requestBody = {'query': query, 'variables': variables};
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      _debugLog('regenerateReflectionQuestion', requestBody, response);

      final body = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        throw Exception('Failed to regenerate reflection question: ${response.statusCode}');
      }

      if (body['errors'] != null) {
        final errors = body['errors'] as List;
        final msg = errors.isNotEmpty
            ? (errors.first as Map<String, dynamic>)['message']?.toString() ?? 'GraphQL error'
            : 'GraphQL error';
        throw Exception(msg);
      }

      final data = body['data'] as Map<String, dynamic>?;
      final result = data?['regenerateReflectionQuestion'] as Map<String, dynamic>?;
      return result?['log'] as Map<String, dynamic>?;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Error regenerating reflection question: $e');
    }
  }

  /// Update reflection answers and optionally overall reflection.
  Future<Map<String, dynamic>?> updateReflectionAnswers({
    required String logId,
    List<String>? reflectionAnswers,
    String? overallReflection,
  }) async {
    final query = '''
      mutation UpdateReflectionAnswers(\$logId: String!, \$reflectionAnswers: [String], \$overallReflection: String) {
        updateReflectionAnswers(logId: \$logId, reflectionAnswers: \$reflectionAnswers, overallReflection: \$overallReflection) {
          log {
            id
            startTimestamp
            logEntries { timestamp imageUrl reflectionText question lat lng address }
            reflectionQuestions { question answer }
            overallReflection
          }
        }
      }
    ''';
    final variables = <String, dynamic>{'logId': logId};
    if (reflectionAnswers != null) variables['reflectionAnswers'] = reflectionAnswers;
    if (overallReflection != null) variables['overallReflection'] = overallReflection;

    try {
      final requestBody = {'query': query, 'variables': variables};
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      _debugLog('updateReflectionAnswers', requestBody, response);

      final body = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        throw Exception('Failed to update reflection answers: ${response.statusCode}');
      }

      if (body['errors'] != null) {
        final errors = body['errors'] as List;
        final msg = errors.isNotEmpty
            ? (errors.first as Map<String, dynamic>)['message']?.toString() ?? 'GraphQL error'
            : 'GraphQL error';
        throw Exception(msg);
      }

      final data = body['data'] as Map<String, dynamic>?;
      final result = data?['updateReflectionAnswers'] as Map<String, dynamic>?;
      return result?['log'] as Map<String, dynamic>?;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Error updating reflection answers: $e');
    }
  }

  Future<Map<String, dynamic>> removeFavoriteLocation({
    required String userId,
    required double latitude,
    required double longitude,
  }) async {
    final String query = '''
      mutation {
        removeFavoriteLocation(
          userId: "$userId"
          latitude: $latitude
          longitude: $longitude
        ) {
          success
          message
        }
      }
    ''';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'query': query}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
          'Failed to remove favorite location: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error removing favorite location: $e');
    }
  }

  Future<Map<String, dynamic>> getFavoriteLocations({
    required String walkId,
  }) async {
    final String query = '''
      mutation {
        getFavoriteLocations(walkId: "$walkId") {
          favoriteLocations {
            latitude
            longitude
            photoUrl
          }
        }
      }
    ''';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'query': query}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
          'Failed to get favorite locations: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error getting favorite locations: $e');
    }
  }

  Future<Map<String, dynamic>> getWalk({required String walkId}) async {
    final String query = '''
      query {
        walk(id: "$walkId") {
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
    ''';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'query': query}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get walk: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting walk: $e');
    }
  }

  Future<Map<String, dynamic>> getWalkTracking({required String walkId}) async {
    final String query = '''
      query {
        walkTracking(walkId: "$walkId") {
          coordinates {
            latitude
            longitude
          }
        }
      }
    ''';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'query': query}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get walk tracking: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting walk tracking: $e');
    }
  }

  Future<Map<String, dynamic>> getLatestInProgressWalk({
    required String userId,
  }) async {
    final String query = '''
      query {
        latestInProgressWalk(userId: "$userId") {
          Id
        }
      }
    ''';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'query': query}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
          'Failed to get latest in-progress walk: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error getting latest in-progress walk: $e');
    }
  }
}
