import 'package:mambo/features/walk/domain/walk.dart';

/// Demo walks for the rendered screenshots. Real Hong Kong places, made-up
/// numbers; nothing here comes from a user account.

Map<String, Object?> _stop(
  String name,
  double lat,
  double lng, {
  bool collected = true,
  String description = '',
}) => {
  'name': name,
  'description': description,
  'selected': true,
  'collected': collected,
  'coordinates': {'latitude': lat, 'longitude': lng},
};

Map<String, Object?> _task(String description, {int photos = 1}) => {
  'description': description,
  'photosRequired': photos,
  'photosFulfilled': photos,
  'status': 'completed',
};

/// The walk shown on the summary screen. [photoUrls] become its surprise
/// spots, so they appear under 心动瞬间.
Walk sheungWanWalk({List<String> photoUrls = const []}) => Walk.fromJson({
  'Id': 'demo-sheung-wan',
  'userId': 'demo',
  'totalDuration': 90,
  'title': '上环老街慢游',
  'description': '从文武庙到元创方，走进香港最早的街区。',
  'createdAt': '2026-11-08T06:20:00Z',
  'status': 'completed',
  'timeSpent': 5520,
  'distanceTraveled': 3.4,
  'userAddress': '香港上环荷李活道',
  'locations': [
    _stop('文武庙', 22.2840, 114.1497),
    _stop('摩罗街古董市集', 22.2845, 114.1505),
    _stop('荷李活道', 22.2830, 114.1520),
    _stop('永利街', 22.2826, 114.1508),
    _stop('PMQ 元创方', 22.2836, 114.1527),
    _stop('大馆', 22.2817, 114.1541, collected: false),
  ],
  'tasks': [
    _task('拍一盏庙里的盘香'),
    _task('找到两件比你年纪还大的古董', photos: 2),
    _task('拍下一面有故事的墙'),
    _task('找一扇绿色的门'),
  ],
  'favoriteLocations': [
    for (final url in photoUrls)
      {'latitude': 22.2833, 'longitude': 114.1512, 'photoUrl': url},
  ],
});

/// The AI-written story shown on the summary screen.
const sheungWanStory =
    '午后的阳光斜斜照进文武庙，盘香一圈圈落下细灰。你在摩罗街的旧物摊前停了很久，'
    '翻到一只比你年纪还大的搪瓷杯。荷李活道的斜坡不算好走，永利街的楼梯却让人想坐下来。'
    '一个半小时，三点四公里，你把上环最老的几条街慢慢走了一遍。';

/// Completed walks for the history screen, newest first.
List<Walk> historyWalks() => [
  sheungWanWalk(photoUrls: ['a', 'b']),
  Walk.fromJson({
    'Id': 'demo-sham-shui-po',
    'totalDuration': 60,
    'title': '深水埗布行与小吃',
    'createdAt': '2026-11-02T08:05:00Z',
    'status': 'completed',
    'timeSpent': 3900,
    'distanceTraveled': 2.6,
    'userAddress': '香港深水埗基隆街',
    'locations': [
      _stop('基隆街布行', 22.3301, 114.1617),
      _stop('鸭寮街', 22.3296, 114.1634),
      _stop('合益泰小食', 22.3307, 114.1625),
      _stop('北河街街市', 22.3291, 114.1609),
    ],
    'tasks': [_task('拍三种不同花色的布', photos: 3), _task('找一家开了五十年的小店')],
    'favoriteLocations': [
      {'latitude': 22.33, 'longitude': 114.16, 'photoUrl': 'c'},
    ],
  }),
  Walk.fromJson({
    'Id': 'demo-sai-ying-pun',
    'totalDuration': 45,
    'title': '西营盘斜坡与海旁',
    'createdAt': '2026-10-26T09:40:00Z',
    'status': 'completed',
    'timeSpent': 2820,
    'distanceTraveled': 2.1,
    'userAddress': '香港西营盘高街',
    'locations': [
      _stop('高街鬼屋', 22.2862, 114.1428),
      _stop('第三街', 22.2858, 114.1440),
      _stop('西区海旁', 22.2889, 114.1421),
    ],
    'tasks': [_task('拍一段向下望的楼梯')],
  }),
  Walk.fromJson({
    'Id': 'demo-tai-hang',
    'totalDuration': 40,
    'title': '大坑小巷里的老店',
    'createdAt': '2026-10-19T03:15:00Z',
    'status': 'completed',
    'timeSpent': 2580,
    'distanceTraveled': 1.8,
    'userAddress': '香港大坑浣纱街',
    'locations': [
      _stop('莲花宫', 22.2779, 114.1925),
      _stop('浣纱街', 22.2786, 114.1920),
      _stop('京街', 22.2793, 114.1914, collected: false),
    ],
    'tasks': [_task('找一块手写的招牌')],
  }),
];
