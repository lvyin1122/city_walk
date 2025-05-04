import 'package:http/http.dart' as http;
import 'dart:convert';

class GraphQLService {
  // static const String _endpoint = 'http://localhost:8000/graphql';
  // if it's android, use the ip address of the machine
  // if it's ios, use the ip address of the simulator
  static const String _endpoint = 'http://10.0.2.2:8000/graphql';

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
              coordinates
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
} 