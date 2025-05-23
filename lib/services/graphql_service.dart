import 'package:http/http.dart' as http;
import 'dart:convert';

class GraphQLService {
  static const String _endpoint = 'http://localhost:8000/graphql';
  // if it's android, use the ip address of the machine
  // if it's ios, use the ip address of the simulator
  // static const String _endpoint = 'http://10.0.2.2:8000/graphql';

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
              popularity
              cost
              description
              estimatedTime
              collected
              coordinates {
                latitude
                longitude
              }
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
              cost
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
}
