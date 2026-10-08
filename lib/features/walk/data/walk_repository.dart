import 'package:mambo/core/geo/geo_point.dart';
import 'package:mambo/services/graphql_service.dart';

import '../domain/walk.dart';
import 'walk_summary_cache.dart';

/// Loads and updates walks, returning typed models.
///
/// Pages should depend on this rather than on [GraphQLService], so that they
/// never touch raw JSON. Every method throws an `ApiException` on failure.
class WalkRepository {
  WalkRepository({GraphQLService? api, WalkSummaryCache? summaryCache})
    : _api = api ?? GraphQLService(),
      _summaryCache = summaryCache ?? WalkSummaryCache();

  final GraphQLService _api;
  final WalkSummaryCache _summaryCache;

  /// Asks the backend to generate a walk around [origin].
  Future<Walk> generateWalk({
    required String userId,
    required GeoPoint origin,
    required List<String> keywords,
    required int minutes,
  }) async {
    final result = await _api.generateWalk(
      userId: userId,
      location: '${origin.latitude}, ${origin.longitude}',
      keywords: keywords,
      duration: minutes.toDouble(),
    );
    final walk = _map(_map(result['data'])?['generateWalkWithGpt'])?['walk'];
    if (walk is! Map<String, dynamic>) {
      throw const FormatException('The backend returned no walk');
    }
    return Walk.fromJson(walk);
  }

  Future<Walk> getWalk(String walkId) async {
    final result = await _api.getWalk(walkId: walkId);
    final walk = _map(result['data'])?['walk'];
    if (walk is! Map<String, dynamic>) {
      throw const FormatException('Walk not found');
    }
    return Walk.fromJson(walk);
  }

  /// Completed walks of [userId], most recent first.
  Future<List<Walk>> getCompletedWalks(String userId) async {
    final result = await _api.getCompletedWalks(userId: userId);
    final raw = _map(result['data'])?['completedWalksByUserId'];
    final walks = <Walk>[
      if (raw is List)
        for (final item in raw)
          if (item is Map<String, dynamic>) Walk.fromJson(item),
    ];
    walks.sort((a, b) {
      final aDate = a.createdAt;
      final bDate = b.createdAt;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return walks;
  }

  /// Id of the walk [userId] has in progress, or null.
  Future<String?> getInProgressWalkId(String userId) async {
    final result = await _api.getLatestInProgressWalk(userId: userId);
    final walk = _map(_map(result['data'])?['latestInProgressWalk']);
    return (walk?['Id'] ?? walk?['id'])?.toString();
  }

  /// Marks the stops at [stopIndexes] as chosen and starts the walk.
  Future<void> startWalk(String walkId, List<int> stopIndexes) async {
    await _api.updateWalkStatus(walkId: walkId, status: WalkStatus.inProgress);
    await _api.selectLocations(walkId: walkId, locationIndexes: stopIndexes);
  }

  /// Gives up a walk so that it is no longer offered for resuming.
  Future<void> abandonWalk(String walkId) async {
    await _api.updateWalkStatus(walkId: walkId, status: WalkStatus.pending);
  }

  /// The path the user actually walked.
  Future<List<GeoPoint>> getTrack(String walkId) async {
    final result = await _api.getWalkTracking(walkId: walkId);
    final raw = _map(_map(result['data'])?['walkTracking'])?['coordinates'];
    return _points(raw);
  }

  Future<List<SurpriseSpot>> getSurprises(String walkId) async {
    final result = await _api.getFavoriteLocations(walkId: walkId);
    final raw =
        _map(_map(result['data'])?['getFavoriteLocations'])?['favoriteLocations'];
    return [
      if (raw is List)
        for (final item in raw) ?SurpriseSpot.tryParse(item),
    ];
  }

  /// URLs of all photos submitted for the walk's tasks.
  Future<List<String>> getTaskPhotoUrls(String walkId) async {
    final result = await _api.getAllTasksImages(walkId: walkId);
    final raw = _map(_map(result['data'])?['getAllTasksImages'])?['images'];
    return [
      if (raw is List)
        for (final item in raw)
          if (item is Map && item['url'] != null) item['url'].toString(),
    ];
  }

  /// The story of the walk. Written by the backend the first time it is
  /// asked for (slow: it calls a language model) and kept on the device
  /// afterwards, so reopening a walk shows the same story at once.
  Future<String> getSummary(String walkId) async {
    final cached = await _summaryCache.read(walkId);
    if (cached != null) return cached;

    final result = await _api.generateWalkSummary(walkId: walkId);
    final summary =
        _map(_map(result['data'])?['generateWalkSummary'])?['summary']
            ?.toString() ??
        '';
    await _summaryCache.write(walkId, summary);
    return summary;
  }

  Map<String, dynamic>? _map(Object? value) =>
      value is Map<String, dynamic> ? value : null;

  List<GeoPoint> _points(Object? raw) => [
    if (raw is List)
      for (final item in raw) ?GeoPoint.tryParse(item),
  ];
}
