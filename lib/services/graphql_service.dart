import 'package:http/http.dart' as http;
import 'dart:convert';

class GraphQLService {
  static const String _endpoint = 'http://52.23.183.160:8000/graphql';

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
            difficulty
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
              Id
              createdTime
              description
              photosRequired
              photosFulfilled
              status
              imageUrls
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
            difficulty
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
            imageUrls
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
  }) async {
    final String query = '''
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
            difficulty
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
        throw Exception('Failed to add walk coordinate: ${response.statusCode}');
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
            difficulty
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

  Future<Map<String, dynamic>> getAllTasksImageUrls({
    required String walkId,
  }) async {
    final String query = '''
      mutation {
        getAllTasksImageUrls(
          walkId: "$walkId"
        ) {
          imageUrls
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
        throw Exception('Failed to get task image URLs: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting task image URLs: $e');
    }
  }
}
