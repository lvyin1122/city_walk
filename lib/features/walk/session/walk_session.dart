import 'package:mambo/core/geo/geo_point.dart';

import '../domain/photo_check.dart';
import '../domain/walk.dart';

/// What a second of the task countdown brought.
enum CountdownEvent {
  none,

  /// Five minutes left on the current task.
  fiveMinutesLeft,

  /// Time is up and the task is unfinished: hand out a new one.
  expired,
}

/// The state of a walk in progress, without any widgets, timers or network.
///
/// The walk page owns one, feeds it positions, ticks and backend results, and
/// redraws from it. Everything here is synchronous and unit-tested.
class WalkSession {
  WalkSession._(this.walk, this.stops);

  /// Restores a session from the walk as saved on the backend, so a paused
  /// walk continues where it stopped.
  factory WalkSession.resume(Walk walk) {
    final session = WalkSession._(walk, walk.selectedStops);
    session.reachedStops.addAll(
      session.stops.where((s) => s.collected).map((s) => s.index),
    );
    session._finishSuggested = session.allStopsReached;
    session.tasksCompleted = walk.completedTaskCount;
    session.elapsedBefore = walk.timeSpent ?? Duration.zero;
    session.distanceKm = walk.distanceKm ?? 0;
    session.surprises = List.of(walk.surprises);
    final open = walk.tasks.isEmpty ? null : walk.tasks.last;
    if (open != null && !open.isCompleted) {
      session.startTask(open, photosFulfilled: open.photosFulfilled);
    }
    return session;
  }

  /// How close the user must get to a stop for it to count as reached.
  static const double reachRadiusMeters = 20;

  /// How long a task stays open before it is swapped for a new one.
  static const Duration taskWindow = Duration(minutes: 15);
  static const Duration taskWarning = Duration(minutes: 5);

  /// Two surprise spots closer than this are the same place.
  static const double sameSpotMeters = 12;

  final Walk walk;

  /// The stops the user chose, in walking order.
  final List<WalkStop> stops;

  /// Indexes (positions in the walk) of the stops reached so far.
  final Set<int> reachedStops = {};

  WalkTask? task;
  int photosFulfilled = 0;
  int tasksCompleted = 0;

  /// Time walked before this session started (a resumed walk).
  Duration elapsedBefore = Duration.zero;
  double distanceKm = 0;

  /// The walked route, oldest first.
  final List<GeoPoint> path = [];

  List<SurpriseSpot> surprises = [];

  /// Seconds until the current task is swapped.
  int countdownSeconds = 0;

  bool _warned = false;
  bool _finishSuggested = false;

  bool get allStopsReached =>
      stops.isNotEmpty && stops.every((s) => reachedStops.contains(s.index));

  bool isReached(WalkStop stop) => reachedStops.contains(stop.index);

  /// Where the map should open: the first stop, else [fallback].
  GeoPoint? get firstStopPosition => stops.isEmpty ? null : stops.first.position;

  // --- position --------------------------------------------------------------

  /// Marks stops within reach of [position] and returns the ones reached just
  /// now (each is reported once; [unreach] lets a failed upload retry).
  List<WalkStop> reachStopsNear(GeoPoint position) => [
    for (final stop in stops)
      if (distanceMeters(position, stop.position) <= reachRadiusMeters &&
          reachedStops.add(stop.index))
        stop,
  ];

  void unreach(WalkStop stop) => reachedStops.remove(stop.index);

  /// True once, the first time every stop has been reached.
  bool takeFinishSuggestion() {
    if (_finishSuggested || !allStopsReached) return false;
    _finishSuggested = true;
    return true;
  }

  /// Adds a point to the route and to the distance walked.
  void recordPathPoint(GeoPoint point) {
    if (path.isNotEmpty) distanceKm += distanceMeters(path.last, point) / 1000;
    path.add(point);
  }

  /// Puts the route walked before a pause in front of the current one,
  /// without counting its distance again.
  void restoreEarlierPath(List<GeoPoint> earlier) => path.insertAll(0, earlier);

  Duration totalElapsed(Duration thisSession) => elapsedBefore + thisSession;

  // --- tasks -----------------------------------------------------------------

  void startTask(WalkTask newTask, {int photosFulfilled = 0}) {
    task = newTask;
    this.photosFulfilled = photosFulfilled;
    countdownSeconds = taskWindow.inSeconds;
    _warned = false;
  }

  bool get taskDone =>
      task != null &&
      task!.photosRequired > 0 &&
      photosFulfilled >= task!.photosRequired;

  /// Applies the backend's verdict on a photo. Returns true when it completed
  /// the task.
  bool applyPhotoCheck(PhotoCheck check) {
    if (!check.accepted || task == null) return false;
    final wasDone = taskDone;
    photosFulfilled = check.photosFulfilled ?? photosFulfilled + 1;
    final done = check.completesTask || taskDone;
    if (done && !wasDone) {
      photosFulfilled = task!.photosRequired;
      tasksCompleted++;
      return true;
    }
    return false;
  }

  /// Advances the task countdown by one second.
  CountdownEvent tick() {
    if (task == null || taskDone) return CountdownEvent.none;
    if (countdownSeconds > 0) countdownSeconds--;
    if (countdownSeconds == taskWarning.inSeconds && !_warned) {
      _warned = true;
      return CountdownEvent.fiveMinutesLeft;
    }
    if (countdownSeconds == 0) {
      // Wait for the next task before expiring again.
      countdownSeconds = taskWindow.inSeconds;
      return CountdownEvent.expired;
    }
    return CountdownEvent.none;
  }

  bool get countdownUrgent => countdownSeconds <= taskWarning.inSeconds;

  // --- surprises -------------------------------------------------------------

  bool hasSurpriseNear(GeoPoint? position) =>
      position != null &&
      surprises.any((s) => distanceMeters(s.position, position) < sameSpotMeters);
}
