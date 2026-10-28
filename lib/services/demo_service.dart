import 'dart:math';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// In-memory mock "backend" that lets the whole city-walk → walk-plan → photo-task
/// path run with fake Hong Kong Central data and no network calls.
///
/// When [isDemo] is true, [GraphQLService], [CloudinaryService] and [AuthService]
/// short-circuit to this class instead of hitting Supabase / GraphQL / Cloudinary.
///
/// Scope: only the *city walk* path (planner, preview, live walk, photo tasks,
/// summary). The log-entry path is intentionally untouched.
class DemoService {
  DemoService._();
  static final DemoService instance = DemoService._();

  /// Master switch. Flipped on when the user taps "Try demo" on the splash.
  bool isDemo = false;

  static const String demoUserId = 'demo-user';

  /// Center of the simulated walk (Statue Square, Central, Hong Kong).
  static const LatLng demoCenter = LatLng(22.28115, 114.15980);
  static String get demoCenterString =>
      '${demoCenter.latitude}, ${demoCenter.longitude}';

  User? _demoUser;
  User get demoUser =>
      _demoUser ??=
          User.fromJson({
            'id': demoUserId,
            'aud': 'authenticated',
            'email': 'demo@mambo.com',
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'app_metadata': <String, dynamic>{'provider': 'demo'},
            'user_metadata': <String, dynamic>{'name': 'Explorer'},
          })!;

  // walkId -> mutable walk state
  final Map<String, Map<String, dynamic>> _walks = {};
  int _walkCounter = 0;
  int _lastTaskIndex = -1;
  final Random _random = Random();

  /// Clear all demo state (called when (re)entering demo mode).
  void reset() {
    _walks.clear();
    _walkCounter = 0;
    _lastTaskIndex = -1;
    _seedHistory();
  }

  // ---------------------------------------------------------------------------
  // Canonical Hong Kong Central data
  // ---------------------------------------------------------------------------

  /// The collectible stops, ordered so that walking them forms a loop through
  /// Central & Sheung Wan.
  ///
  /// To use your own preview photos, replace the `photoUrls` lists below with
  /// your image URLs. The preview photo viewer uses `Image.network`, so these
  /// should be remote https URLs.
  static const List<Map<String, dynamic>> _seedLocations = [
    {
      'name': 'Statue Square Garden',
      'description':
          'A calm colonial-era square framed by the HSBC building and the old '
          'Supreme Court — a classic place to start a Central wander.',
      'estimatedTime': '10 mins',
      'lat': 22.28115,
      'lng': 114.15980,
      'photoUrls': [
        'https://picsum.photos/seed/statue-square-hk/800/600',
        'https://picsum.photos/seed/central-hk/800/600',
      ],
    },
    {
      'name': 'Lan Kwai Fong',
      'description':
          'Sloping cobbled lanes packed with bars, neon and after-work energy. '
          'Quiet and photogenic in daylight, electric at night.',
      'estimatedTime': '15 mins',
      'lat': 22.28080,
      'lng': 114.15555,
      'photoUrls': [
        'https://picsum.photos/seed/lan-kwai-fong/800/600',
        'https://picsum.photos/seed/lkf-hk/800/600',
      ],
    },
    {
      'name': 'Tai Kwun',
      'description':
          'The revitalised Central Police Station compound — heritage granite '
          'walls now home to galleries, courtyards and cafés.',
      'estimatedTime': '20 mins',
      'lat': 22.28160,
      'lng': 114.15440,
      'photoUrls': [
        'https://lh3.googleusercontent.com/gps-cs-s/AHRPTWk0HmqoMYK_A_sWyJYYRFcmS2PVPHH5IqdKAlZbnQTSCaFqioXvF807Qoj46DhHcaxTxHMBL24prhu54RnBzLRHGdl44Bd4eSlYsygaS0cw-P-NyDNQyg70H5r_2U5EF9yUFFp90Q=w408-h725-k-no',
      ],
    },
    {
      'name': 'PMQ',
      'description':
          'A former married police quarters turned creative hub, stacked with '
          'local designers, studios and pop-up shops.',
      'estimatedTime': '20 mins',
      'lat': 22.28345,
      'lng': 114.15130,
      'photoUrls': [
        'https://picsum.photos/seed/pmq-hk/800/600',
        'https://picsum.photos/seed/pmq-design/800/600',
      ],
    },
    {
      'name': 'Man Mo Temple',
      'description':
          'Incense coils drift over an atmospheric 19th-century temple on '
          'Hollywood Road, dedicated to the gods of literature and war.',
      'estimatedTime': '15 mins',
      'lat': 22.28390,
      'lng': 114.14975,
      'photoUrls': [
        'https://picsum.photos/seed/man-mo-temple/800/600',
        'https://picsum.photos/seed/hollywood-road-hk/800/600',
      ],
    },
  ];

  /// Extra routing waypoint (not a collectible stop) that curves the return leg
  /// north along Queen's Road so the simulated path reads as a loop rather than
  /// a straight diagonal back to the start.
  static const LatLng _returnWaypoint = LatLng(22.28470, 114.15470);

  /// Loop the location-simulator follows: through every stop, then the return
  /// waypoint, then back to the start.
  List<LatLng> get routePoints => [
    for (final l in _seedLocations)
      LatLng(l['lat'] as double, l['lng'] as double),
    _returnWaypoint,
  ];

  LatLng get startPoint => routePoints.first;

  /// Pre-written photo tasks that read as if produced by the city-exploration
  /// task prompt: an observation cue followed by a "Take N photos of X, such as
  /// …" instruction that nudges you to notice the small details of Hong Kong's
  /// public spaces. `photos` matches the wording of the sentence.
  ///
  /// `seen` is a pool of fabricated "what the photo shows" descriptions used to
  /// build the feedback message (there is no real image analysis in demo mode).
  /// For passing tasks the descriptions match the task; for always-fail tasks
  /// they describe something off-topic so the kind rejection makes sense.
  static const List<Map<String, Object>> _taskTemplates = [
    {
      'description':
          'Look closely at the old street storefronts here. Take two photos of '
          'distinctive signboard details, such as bilingual lettering, unusual '
          'typefaces, decorative symbols, or vintage shop names.',
      'photos': 2,
      'seen': [
        'a weathered shopfront sign painted with bold bilingual lettering',
        'an aged gold-and-red signboard with beautifully worn typography',
        'a hand-painted shop name framed by peeling paint and character',
      ],
    },
    {
      'description':
          'Look closely at where old and new Hong Kong sit side by side. Take '
          'three photos of the contrast, such as weathered tiles against glass '
          'towers, bamboo scaffolding on a modern facade, or a temple roofline '
          'framed by skyscrapers.',
      'photos': 3,
      // Demo: this task always fails verification (to show the failure screen).
      'alwaysFail': true,
      'seen': [
        'mostly a close-up of the pavement at your feet',
        'a blurry shot of passing traffic',
        'a plain patch of grey wall with little else in frame',
      ],
    },
    {
      'description':
          'Look closely at the everyday life of a local market or street stall. '
          'Take two photos of the small rituals of the day, such as a vendor '
          'mid-gesture, neatly stacked produce, or steam rising from a food '
          'cart.',
      'photos': 2,
      'seen': [
        'a stall with produce stacked in neat, colourful rows',
        'a vendor caught mid-gesture amid the bustle of the market',
        'steam curling up from a food cart into the morning light',
      ],
    },
    {
      'description':
          'Look up at everything that lives above street level. Take three '
          'photos of the layers overhead, such as laundry on bamboo poles, '
          'tangled neon signage, or a thin sliver of sky between the towers.',
      'photos': 3,
      'seen': [
        'laundry strung on bamboo poles high above the lane',
        'a tangle of signboards and wires crisscrossing overhead',
        'a narrow sliver of sky squeezed between two tall towers',
      ],
    },
    {
      'description':
          'Look closely at how light moves through these streets. Take two '
          'photos of light and shadow, such as sunlight cutting down an alley, a '
          'glowing doorway, or shadows falling across a stairwell.',
      'photos': 2,
      'seen': [
        'warm sunlight slicing down a narrow alley',
        'a glowing doorway framed by deep shadow',
        'long shadows falling in stripes across a stairwell',
      ],
    },
    {
      'description':
          'Look closely at the small touches people leave behind. Take three '
          'photos of quiet personal details, such as a potted plant on a step, a '
          'hand-written notice, or a shrine tucked into a corner.',
      'photos': 3,
      'seen': [
        'a little potted plant perched on a worn doorstep',
        'a hand-written notice taped to a metal shutter',
        'a tiny roadside shrine tucked into a corner',
      ],
    },
    {
      'description':
          'Look closely at the textures of the streets underfoot and along the '
          'walls. Take two photos of surfaces most people walk past, such as '
          'peeling paint, patterned tiles, worn stone steps, or a rusted gate.',
      'photos': 2,
      'seen': [
        'a wall of peeling paint layered in years of colour',
        'a patch of patterned floor tiles worn smooth underfoot',
        'a rusted metal gate full of texture and history',
      ],
    },
    {
      'description':
          'Look closely at the neighbourhood after dark. Take three photos of '
          'the city aglow, such as neon reflections, glowing lanterns, or shop '
          'lights spilling into an alley.',
      'photos': 3,
      // Demo: this task always fails verification (to show the failure screen).
      'alwaysFail': true,
      'seen': [
        'a bright daytime street with none of the lights lit',
        'an overexposed patch of blank sky',
        'a close-up of a thumb partly covering the lens',
      ],
    },
  ];

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _requireWalk(String walkId) {
    final walk = _walks[walkId];
    if (walk == null) {
      throw StateError('Demo walk $walkId not found');
    }
    return walk;
  }

  /// The pool of fabricated "what the photo shows" descriptions for a task.
  List<String> _seenOf(Map<String, dynamic>? task) {
    final raw = task?['seen'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return const [];
  }

  /// Builds the full walk map in the exact shape GraphQL returns.
  Map<String, dynamic> _walkPayload(Map<String, dynamic> walk) {
    return {
      'Id': walk['Id'],
      'userId': walk['userId'],
      'totalDuration': walk['totalDuration'],
      'title': walk['title'],
      'description': walk['description'],
      'createdAt': walk['createdAt'],
      'status': walk['status'],
      'timeSpent': walk['timeSpent'],
      'distanceTraveled': walk['distanceTraveled'],
      'tasksCompleted': walk['tasksCompleted'],
      'tasksTotal': walk['tasksTotal'],
      'userAddress': walk['userAddress'],
      'city': walk['city'],
      'locations': [
        for (final l in (walk['locations'] as List))
          {
            'name': l['name'],
            'description': l['description'],
            'estimatedTime': l['estimatedTime'],
            'selected': l['selected'],
            'collected': l['collected'],
            'photoUrls': List<String>.from(l['photoUrls'] as List),
            'coordinates': {
              'latitude': l['coordinates']['latitude'],
              'longitude': l['coordinates']['longitude'],
            },
          },
      ],
      'tasks': [
        for (final t in (walk['tasks'] as List))
          {
            'createdTime': t['createdTime'],
            'description': t['description'],
            'photosRequired': t['photosRequired'],
            'photosFulfilled': t['photosFulfilled'],
            'status': t['status'],
            'images': [
              for (final img in (t['images'] as List))
                {
                  'url': img['url'],
                  'coordinates': {
                    'latitude': img['coordinates']['latitude'],
                    'longitude': img['coordinates']['longitude'],
                  },
                },
            ],
          },
      ],
      'favoriteLocations': [
        for (final f in (walk['favoriteLocations'] as List))
          {
            'latitude': f['latitude'],
            'longitude': f['longitude'],
            'photoUrl': f['photoUrl'],
          },
      ],
    };
  }

  // ---------------------------------------------------------------------------
  // GraphQL-shaped operations
  // ---------------------------------------------------------------------------

  Map<String, dynamic> generateWalk({
    required int duration,
    required List<String> keywords,
  }) {
    final id = 'demo-walk-${++_walkCounter}';
    final locations = [
      for (final l in _seedLocations)
        {
          'name': l['name'],
          'description': l['description'],
          'estimatedTime': l['estimatedTime'],
          'selected': false,
          'collected': false,
          'photoUrls': List<String>.from(l['photoUrls'] as List),
          'coordinates': {'latitude': l['lat'], 'longitude': l['lng']},
        },
    ];
    final walk = <String, dynamic>{
      'Id': id,
      'userId': demoUserId,
      'totalDuration': duration <= 0 ? 45 : duration,
      'title': 'Central & Sheung Wan Heritage Loop',
      'description':
          'A soulful loop through the beating heart of Hong Kong Island — '
          'colonial squares, temple incense, creative hubs and hidden lanes.',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'status': 'pending',
      'timeSpent': 0,
      'distanceTraveled': 0.0,
      'tasksCompleted': 0,
      'tasksTotal': 0,
      'userAddress': 'Hong Kong, Central, Statue Square',
      'city': 'Hong Kong',
      'locations': locations,
      'tasks': <Map<String, dynamic>>[],
      'favoriteLocations': <Map<String, dynamic>>[],
      'coordinates': <Map<String, dynamic>>[], // tracking path
      'allTaskImages': <Map<String, dynamic>>[],
    };
    _walks[id] = walk;
    return {
      'data': {
        'generateWalkWithGpt': {'walk': _walkPayload(walk)},
      },
    };
  }

  Map<String, dynamic> getWalk(String walkId) {
    final walk = _requireWalk(walkId);
    return {
      'data': {'walk': _walkPayload(walk)},
    };
  }

  Map<String, dynamic> selectLocations(String walkId, List<int> indexes) {
    final walk = _requireWalk(walkId);
    final locations = walk['locations'] as List;
    for (var i = 0; i < locations.length; i++) {
      locations[i]['selected'] = indexes.contains(i);
    }
    return {
      'data': {
        'selectLocations': {'walk': _walkPayload(walk)},
      },
    };
  }

  Map<String, dynamic> updateWalkStatus(String walkId, String status) {
    final walk = _requireWalk(walkId);
    walk['status'] = status;
    return {
      'data': {
        'updateWalkStatus': {'walk': _walkPayload(walk)},
      },
    };
  }

  Map<String, dynamic> updateWalkStats(
    String walkId,
    double distanceTraveled,
    int timeSpent,
  ) {
    final walk = _requireWalk(walkId);
    walk['distanceTraveled'] = distanceTraveled;
    walk['timeSpent'] = timeSpent;
    return {
      'data': {
        'updateWalkStats': {'walk': _walkPayload(walk)},
      },
    };
  }

  Map<String, dynamic> collectLocation(String walkId, int locationIndex) {
    final walk = _requireWalk(walkId);
    final locations = walk['locations'] as List;
    if (locationIndex >= 0 && locationIndex < locations.length) {
      locations[locationIndex]['collected'] = true;
    }
    return {
      'data': {
        'collectLocation': {'walk': _walkPayload(walk)},
      },
    };
  }

  Map<String, dynamic> addWalkCoordinate(
    String walkId,
    double latitude,
    double longitude,
  ) {
    final walk = _requireWalk(walkId);
    (walk['coordinates'] as List).add({
      'latitude': latitude,
      'longitude': longitude,
    });
    return {
      'data': {
        'addWalkCoordinate': {
          'walkTracking': {'walkId': walkId, 'userId': demoUserId},
        },
      },
    };
  }

  Map<String, dynamic> getWalkTracking(String walkId) {
    final walk = _requireWalk(walkId);
    return {
      'data': {
        'walkTracking': {
          'coordinates': List<Map<String, dynamic>>.from(
            walk['coordinates'] as List,
          ),
        },
      },
    };
  }

  Map<String, dynamic> generateTask(String walkId) {
    final walk = _requireWalk(walkId);
    final bool isFirstTask = (walk['tasks'] as List).isEmpty;

    // Split templates into always-fail and passing ones.
    final failIndexes = <int>[];
    final passIndexes = <int>[];
    for (var i = 0; i < _taskTemplates.length; i++) {
      if (_taskTemplates[i]['alwaysFail'] == true) {
        failIndexes.add(i);
      } else {
        passIndexes.add(i);
      }
    }

    int idx;
    if (isFirstTask && failIndexes.isNotEmpty) {
      // The FIRST task of every demo walk always fails, so the failure screen
      // is guaranteed up front without hunting for it.
      idx = failIndexes[_random.nextInt(failIndexes.length)];
    } else {
      // Subsequent tasks are passing tasks, picked at random without an
      // immediate repeat.
      final pool =
          passIndexes.isNotEmpty
              ? passIndexes
              : List<int>.generate(_taskTemplates.length, (i) => i);
      idx = pool[_random.nextInt(pool.length)];
      if (pool.length > 1 && idx == _lastTaskIndex) {
        idx = pool[(pool.indexOf(idx) + 1) % pool.length];
      }
    }
    _lastTaskIndex = idx;
    final template = _taskTemplates[idx];
    final task = <String, dynamic>{
      'createdTime': DateTime.now().toUtc().toIso8601String(),
      'description': template['description'] as String,
      'photosRequired': template['photos'] as int,
      'photosFulfilled': 0,
      'status': 'pending',
      'images': <Map<String, dynamic>>[],
      'alwaysFail': template['alwaysFail'] == true,
      'seen': template['seen'] ?? const <String>[],
    };
    (walk['tasks'] as List).add(task);
    walk['tasksTotal'] = (walk['tasks'] as List).length;
    return {
      'data': {
        'generateTaskWithGpt': {
          'task': {
            'createdTime': task['createdTime'],
            'description': task['description'],
            'photosRequired': task['photosRequired'],
            'photosFulfilled': task['photosFulfilled'],
            'status': task['status'],
          },
        },
      },
    };
  }

  Map<String, dynamic> verifyTask(
    String walkId,
    String imageUrl,
    String? latitude,
    String? longitude,
  ) {
    final walk = _requireWalk(walkId);
    final tasks = walk['tasks'] as List;
    final Map<String, dynamic>? current =
        tasks.isNotEmpty ? tasks.last as Map<String, dynamic> : null;

    // Some demo tasks always fail verification, so the failure screen can be
    // presented. The photo is rejected — not stored and not counted.
    if (current != null && current['alwaysFail'] == true) {
      final failSeen = _seenOf(current);
      final saw =
          failSeen.isEmpty
              ? 'something a little off-topic'
              : failSeen[_random.nextInt(failSeen.length)];
      return {
        'data': {
          'verifyTaskWithGpt': {
            'success': false,
            'message':
                "This photo looks mostly like $saw, which doesn't seem to "
                "match what the task is asking for. No worries — take another "
                "look around, reframe, and give it another try. You've got "
                "this! 📸",
            'photosFulfilled': current['photosFulfilled'] as int,
            'taskStatus': current['status'] as String,
          },
        },
      };
    }

    final lat = double.tryParse(latitude ?? '') ?? demoCenter.latitude;
    final lng = double.tryParse(longitude ?? '') ?? demoCenter.longitude;
    final image = {
      'url': imageUrl,
      'coordinates': {'latitude': lat, 'longitude': lng},
    };
    (walk['allTaskImages'] as List).add(image);

    String taskStatus = 'in_progress';
    int photosFulfilled = 0;
    int photosRequired = 1;
    if (current != null) {
      (current['images'] as List).add(image);
      current['photosFulfilled'] = (current['photosFulfilled'] as int) + 1;
      photosFulfilled = current['photosFulfilled'] as int;
      photosRequired = current['photosRequired'] as int;
      if (photosFulfilled >= photosRequired) {
        current['status'] = 'completed';
        walk['tasksCompleted'] = (walk['tasksCompleted'] as int) + 1;
      }
      taskStatus = current['status'] as String;
    }

    final bool done = photosFulfilled >= photosRequired;
    final okSeen = _seenOf(current);
    final saw =
        okSeen.isEmpty
            ? 'a lovely city detail'
            : okSeen[(photosFulfilled - 1) % okSeen.length];
    final String message =
        done
            ? 'Beautiful — this photo shows $saw. That completes the task, enjoy '
                'the rest of your walk! 🎉'
            : 'Nice — this photo shows $saw. Exactly the kind of detail this task '
                'is about ($photosFulfilled of $photosRequired). 📸';

    return {
      'data': {
        'verifyTaskWithGpt': {
          'success': true,
          'message': message,
          'photosFulfilled': photosFulfilled,
          'taskStatus': taskStatus,
        },
      },
    };
  }

  Map<String, dynamic> getAllTasksImages(String walkId) {
    final walk = _requireWalk(walkId);
    return {
      'data': {
        'getAllTasksImages': {
          'images': [
            for (final img in (walk['allTaskImages'] as List))
              {
                'url': img['url'],
                'coordinates': {
                  'latitude': img['coordinates']['latitude'],
                  'longitude': img['coordinates']['longitude'],
                },
              },
          ],
        },
      },
    };
  }

  Map<String, dynamic> addFavoriteLocation(
    String walkId,
    double latitude,
    double longitude,
    String photoUrl,
  ) {
    final walk = _requireWalk(walkId);
    (walk['favoriteLocations'] as List).add({
      'latitude': latitude,
      'longitude': longitude,
      'photoUrl': photoUrl,
    });
    return {
      'data': {
        'addFavoriteLocation': {
          'walk': {
            'favoriteLocations': List<Map<String, dynamic>>.from(
              walk['favoriteLocations'] as List,
            ),
          },
        },
      },
    };
  }

  Map<String, dynamic> getFavoriteLocations(String walkId) {
    final walk = _requireWalk(walkId);
    return {
      'data': {
        'getFavoriteLocations': {
          'favoriteLocations': List<Map<String, dynamic>>.from(
            walk['favoriteLocations'] as List,
          ),
        },
      },
    };
  }

  Map<String, dynamic> generateWalkSummary(String walkId) {
    final walk = _requireWalk(walkId);
    final locations = walk['locations'] as List;
    final visited =
        locations
            .where((l) => l['collected'] == true)
            .map((l) => l['name'] as String)
            .toList();
    const checkpointDescriptions = <String, String>{
      'Statue Square Garden': 'colonial architecture and a calm urban garden',
      'Lan Kwai Fong': 'sloping lanes filled with unmistakable city energy',
      'Tai Kwun':
          'heritage courtyards where history meets contemporary culture',
      'PMQ': 'a creative hub alive with local design',
      'Man Mo Temple':
          'an atmospheric sanctuary beneath drifting incense coils',
    };
    final checkpointText =
        visited.isEmpty
            ? 'No checkpoints were formally collected, though the streets of '
                'Central still offered plenty to notice along the way.'
            : visited
                .map(
                  (name) =>
                      '$name — ${checkpointDescriptions[name] ?? 'a memorable stop with its own local character'}',
                )
                .join('; ');

    const highlightDescriptions = <String, String>{
      'Man Mo Temple':
          'Man Mo Temple stood out for its incense-filled stillness and rich spiritual atmosphere',
      'Tai Kwun':
          'Tai Kwun made a striking impression with its restored heritage walls and lively courtyards',
      'PMQ':
          'PMQ brought playful creative energy through its studios, designers and reinvigorated architecture',
      'Lan Kwai Fong':
          'Lan Kwai Fong added colour and energy with its steep, characterful lanes',
      'Statue Square Garden':
          'Statue Square Garden offered a peaceful opening framed by Central’s landmark architecture',
    };
    const highlightPriority = [
      'Man Mo Temple',
      'Tai Kwun',
      'PMQ',
      'Lan Kwai Fong',
      'Statue Square Garden',
    ];
    final highlighted =
        highlightPriority
            .where(visited.contains)
            .take(2)
            .map((name) => highlightDescriptions[name]!)
            .toList();
    final highlightsText =
        highlighted.isEmpty
            ? 'Central’s layered streets remained the highlight, blending historic '
                'architecture, lively lanes and small everyday details into a route '
                'worth revisiting.'
            : '${highlighted.join('; ')}, making ${highlighted.length == 1 ? 'it' : 'them'} especially memorable.';

    final tasksDone = walk['tasksCompleted'] as int;
    final tasksTotal = walk['tasksTotal'] as int;
    final completedTasks =
        (walk['tasks'] as List)
            .where((task) => task['status'] == 'completed')
            .toList();
    final observations =
        completedTasks
            .expand((task) => _seenOf(task as Map<String, dynamic>))
            .take(2)
            .toList();
    final observationsText =
        observations.isEmpty
            ? 'Your walk encouraged attentive exploration, even without a completed '
                'photo task, leaving plenty of street details to discover next time.'
            : 'Your tasks helped you notice ${observations.join(', ')}, revealing '
                'the character hidden in details many people pass by.';

    final capturedPhotos = walk['allTaskImages'] as List;
    final capturedText =
        capturedPhotos.isEmpty
            ? ''
            : '\n📸 Captured moments: Your ${capturedPhotos.length} '
                '${capturedPhotos.length == 1 ? 'photo preserves' : 'photos preserve'} '
                '${observations.isEmpty ? 'the walk’s distinctive street atmosphere' : observations.first}, '
                'showing a thoughtful eye for meaningful details.';
    final distance = (walk['distanceTraveled'] as num).toStringAsFixed(1);
    final timeSpent = walk['timeSpent'] as int;
    final title = walk['title'] as String;

    final summary =
        '🎯 Summary: Your $title adventure covered $distance km in '
        '$timeSpent seconds, completing $tasksDone of $tasksTotal tasks while '
        'exploring Hong Kong with curiosity and purpose.\n'
        '📍 Checkpoint summary: $checkpointText\n'
        '⭐ Notable highlights: $highlightsText\n'
        '📝 Task observations: $observationsText'
        '$capturedText\n'
        '🌟 You explored with real attention and enthusiasm—keep following your '
        'curiosity, because every walk can reveal another wonderful side of the '
        'city.';

    print(summary);

    return {
      'data': {
        'generateWalkSummary': {'summary': summary},
      },
    };
  }

  Map<String, dynamic> getLatestInProgressWalk() {
    return {
      'data': {'latestInProgressWalk': null},
    };
  }

  /// Every completed walk (seeded history + any live walk you finished), newest
  /// first is handled by the history page itself.
  Map<String, dynamic> getCompletedWalks() {
    final completed =
        _walks.values
            .where((w) => w['status'] == 'completed')
            .map((w) => _walkPayload(w))
            .toList();
    return {
      'data': {'completedWalksByUserId': completed},
    };
  }

  // ---------------------------------------------------------------------------
  // Fake completed-walk history (so the History tab is populated in demo mode)
  // ---------------------------------------------------------------------------

  void _seedHistory() {
    _addHistoryWalk(
      id: 'demo-history-1',
      title: 'Central & Sheung Wan Heritage Loop',
      address: 'Hong Kong, Central, Statue Square',
      daysAgo: 1,
      minutes: 62,
      distance: 2.4,
      collected: 4,
      taskCount: 3,
      momentCount: 3,
    );
    _addHistoryWalk(
      id: 'demo-history-2',
      title: 'Sheung Wan Lanes & Temples',
      address: 'Hong Kong, Sheung Wan, Hollywood Road',
      daysAgo: 4,
      minutes: 47,
      distance: 1.6,
      collected: 3,
      taskCount: 2,
      momentCount: 2,
    );
    _addHistoryWalk(
      id: 'demo-history-3',
      title: 'Harbourfront to Hillside',
      address: 'Hong Kong, Central, Des Voeux Road',
      daysAgo: 9,
      minutes: 83,
      distance: 3.5,
      collected: 5,
      taskCount: 4,
      momentCount: 4,
    );
  }

  void _addHistoryWalk({
    required String id,
    required String title,
    required String address,
    required int daysAgo,
    required int minutes,
    required double distance,
    required int collected,
    required int taskCount,
    required int momentCount,
  }) {
    final createdAt = DateTime.now().toUtc().subtract(
      Duration(days: daysAgo, hours: 4),
    );
    final isoCreated = createdAt.toIso8601String();
    final route = routePoints;

    final locations = <Map<String, dynamic>>[];
    for (var i = 0; i < _seedLocations.length; i++) {
      final l = _seedLocations[i];
      locations.add({
        'name': l['name'],
        'description': l['description'],
        'estimatedTime': l['estimatedTime'],
        'selected': true,
        'collected': i < collected,
        'photoUrls': List<String>.from(l['photoUrls'] as List),
        'coordinates': {'latitude': l['lat'], 'longitude': l['lng']},
      });
    }

    final tasks = <Map<String, dynamic>>[];
    final allImages = <Map<String, dynamic>>[];
    for (var t = 0; t < taskCount; t++) {
      final tmpl = _taskTemplates[t % _taskTemplates.length];
      final photos = tmpl['photos'] as int;
      final images = <Map<String, dynamic>>[];
      for (var p = 0; p < photos; p++) {
        final coord = route[(t + p) % _seedLocations.length];
        final img = {
          'url': 'https://picsum.photos/seed/${id}_task${t}_$p/600/600',
          'coordinates': {
            'latitude': coord.latitude,
            'longitude': coord.longitude,
          },
        };
        images.add(img);
        allImages.add(img);
      }
      tasks.add({
        'createdTime': isoCreated,
        'description': tmpl['description'],
        'photosRequired': photos,
        'photosFulfilled': photos,
        'status': 'completed',
        'images': images,
      });
    }

    final moments = <Map<String, dynamic>>[];
    for (var f = 0; f < momentCount; f++) {
      final coord = route[f % _seedLocations.length];
      moments.add({
        'latitude': coord.latitude + 0.0004,
        'longitude': coord.longitude + 0.0004,
        'photoUrl': 'https://picsum.photos/seed/${id}_moment$f/600/600',
      });
    }

    _walks[id] = {
      'Id': id,
      'userId': demoUserId,
      'totalDuration': minutes,
      'title': title,
      'description':
          'A completed city walk through the heart of Hong Kong Island.',
      'createdAt': isoCreated,
      'status': 'completed',
      'timeSpent': minutes,
      'distanceTraveled': distance,
      'tasksCompleted': taskCount,
      'tasksTotal': taskCount,
      'userAddress': address,
      'city': 'Hong Kong',
      'locations': locations,
      'tasks': tasks,
      'favoriteLocations': moments,
      'coordinates': _trackFromRoute(),
      'allTaskImages': allImages,
    };
  }

  /// A smooth loop of tracking points for the summary map polyline.
  List<Map<String, dynamic>> _trackFromRoute() {
    final route = routePoints;
    final track = <Map<String, dynamic>>[];
    const stepsPerSegment = 6;
    for (var i = 0; i < route.length; i++) {
      final a = route[i];
      final b = route[(i + 1) % route.length];
      for (var s = 0; s < stepsPerSegment; s++) {
        final t = s / stepsPerSegment;
        track.add({
          'latitude': a.latitude + (b.latitude - a.latitude) * t,
          'longitude': a.longitude + (b.longitude - a.longitude) * t,
        });
      }
    }
    return track;
  }
}
