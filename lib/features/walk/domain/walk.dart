import 'package:mambo/core/geo/geo_point.dart';

/// Lifecycle states the backend uses for a walk.
abstract final class WalkStatus {
  static const pending = 'pending';
  static const inProgress = 'in_progress';
  static const completed = 'completed';
}

/// A generated walk: its stops, the photo tasks handed out so far and the
/// surprise spots the user marked.
class Walk {
  const Walk({
    required this.id,
    this.title = '',
    this.description = '',
    this.status = '',
    this.createdAt,
    this.plannedMinutes,
    this.timeSpent,
    this.distanceKm,
    this.userAddress,
    this.stops = const [],
    this.tasks = const [],
    this.surprises = const [],
  });

  final String id;
  final String title;
  final String description;
  final String status;
  final DateTime? createdAt;

  /// Duration the route was planned for, in minutes.
  final int? plannedMinutes;

  /// Time actually spent walking, when the walk has been started.
  final Duration? timeSpent;

  /// Distance actually walked, in kilometres.
  final double? distanceKm;

  final String? userAddress;
  final List<WalkStop> stops;
  final List<WalkTask> tasks;
  final List<SurpriseSpot> surprises;

  /// Stops the user chose to visit.
  List<WalkStop> get selectedStops =>
      stops.where((stop) => stop.selected).toList();

  /// Stops the user reached.
  List<WalkStop> get collectedStops =>
      stops.where((stop) => stop.collected).toList();

  int get completedTaskCount => tasks.where((task) => task.isCompleted).length;

  /// Parses a walk as returned by the backend.
  ///
  /// Tolerant by design: the backend spells the id `Id`, sends numbers as
  /// numbers or strings, and omits lists that are empty. A stop without
  /// coordinates is dropped because nothing can be done with it.
  factory Walk.fromJson(Map<String, dynamic> json) {
    final stops = <WalkStop>[];
    final rawStops = json['locations'];
    if (rawStops is List) {
      for (var i = 0; i < rawStops.length; i++) {
        final stop = WalkStop.tryParse(rawStops[i], index: i);
        if (stop != null) stops.add(stop);
      }
    }

    final timeSpentSeconds = _asInt(json['timeSpent']);

    return Walk(
      id: (json['Id'] ?? json['id'] ?? '').toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      // The backend sends UTC with an offset; show it in device time.
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal(),
      plannedMinutes: _asInt(json['totalDuration']),
      timeSpent:
          timeSpentSeconds == null ? null : Duration(seconds: timeSpentSeconds),
      distanceKm: _asDouble(json['distanceTraveled']),
      userAddress: json['userAddress']?.toString(),
      stops: stops,
      tasks: _parseList(json['tasks'], WalkTask.tryParse),
      surprises: _parseList(json['favoriteLocations'], SurpriseSpot.tryParse),
    );
  }
}

/// One place on a walk.
class WalkStop {
  const WalkStop({
    required this.index,
    required this.name,
    required this.position,
    this.description = '',
    this.selected = false,
    this.collected = false,
    this.photoUrls = const [],
  });

  /// Position in the walk's list of stops. The backend identifies a stop by
  /// this index when selecting and collecting.
  final int index;
  final String name;
  final String description;
  final GeoPoint position;

  /// Whether the user chose to visit this stop.
  final bool selected;

  /// Whether the user has reached this stop.
  final bool collected;
  final List<String> photoUrls;

  static WalkStop? tryParse(Object? json, {required int index}) {
    if (json is! Map) return null;
    final position = GeoPoint.tryParse(json['coordinates']);
    if (position == null) return null;
    return WalkStop(
      index: index,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      position: position,
      selected: json['selected'] == true,
      collected: json['collected'] == true,
      photoUrls: _parseList(json['photoUrls'], _nonEmptyString),
    );
  }
}

/// A photo task handed out during a walk.
class WalkTask {
  const WalkTask({
    required this.description,
    this.status = '',
    this.photosRequired = 0,
    this.photosFulfilled = 0,
    this.imageUrls = const [],
  });

  final String description;
  final String status;
  final int photosRequired;
  final int photosFulfilled;
  final List<String> imageUrls;

  bool get isCompleted => status == 'completed';

  static WalkTask? tryParse(Object? json) {
    if (json is! Map) return null;
    return WalkTask(
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      photosRequired: _asInt(json['photosRequired']) ?? 0,
      photosFulfilled: _asInt(json['photosFulfilled']) ?? 0,
      imageUrls: _parseList(
        json['images'],
        (image) => image is Map ? _nonEmptyString(image['url']) : null,
      ),
    );
  }
}

/// A place the user marked as a surprise, with the photo they took there.
class SurpriseSpot {
  const SurpriseSpot({required this.position, required this.photoUrl});

  final GeoPoint position;
  final String photoUrl;

  static SurpriseSpot? tryParse(Object? json) {
    if (json is! Map) return null;
    final position = GeoPoint.tryParse(json);
    if (position == null) return null;
    return SurpriseSpot(
      position: position,
      photoUrl: json['photoUrl']?.toString() ?? '',
    );
  }
}

List<T> _parseList<T>(Object? json, T? Function(Object? item) parse) {
  if (json is! List) return const [];
  return [for (final item in json) ?parse(item)];
}

String? _nonEmptyString(Object? value) {
  final text = value?.toString() ?? '';
  return text.isEmpty ? null : text;
}

int? _asInt(Object? value) {
  if (value is num) return value.round();
  return value == null ? null : double.tryParse(value.toString())?.round();
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return value == null ? null : double.tryParse(value.toString());
}
