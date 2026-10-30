import 'package:mambo/core/api/api_exception.dart';
import 'package:mambo/services/graphql_service.dart';

enum ReportKind {
  place,
  task,
  story;

  String get wireName => name;
}

/// Sends feedback through the authenticated backend client.
class ReportRepository {
  ReportRepository([GraphQLService? service])
    : _service = service ?? GraphQLService();

  final GraphQLService _service;

  Future<void> send({
    required ReportKind kind,
    required String walkId,
    int? stopIndex,
    String? detail,
  }) async {
    final success = await _service.reportContent(
      kind: kind.wireName,
      walkId: walkId,
      stopIndex: stopIndex,
      detail: detail,
    );
    if (!success) {
      throw const ApiResponseFormatException('reportContent returned false');
    }
  }
}
