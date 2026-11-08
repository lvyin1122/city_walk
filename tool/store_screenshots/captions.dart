/// Store and marketing captions, one per screenshot slot.
///
/// The wording follows the message pillars in
/// `docs/product-ux-marketing-analysis.md` §6.2. Keep claims the product can
/// back up: no "60 秒", no scrapbook cover (free record is off for 1.0).
library;

enum Lang { zh, en }

extension LangCode on Lang {
  /// Folder name for the output, matching the store locale.
  String get folder => switch (this) {
    Lang.zh => 'zh-Hans',
    Lang.en => 'en',
  };
}

/// The brand line shown above every caption.
const brand = {Lang.zh: 'Mambo 漫步', Lang.en: 'Mambo'};

/// Tagline of the Google Play feature graphic.
const featureTagline = {
  Lang.zh: '给不想做功课的旅人，\n一场此刻生成的城市漫步',
  Lang.en: "For travellers who'd\nrather wander than plan.",
};

/// Headline per slot number.
const captions = <int, Map<Lang, String>>{
  1: {Lang.zh: '选兴趣，定时长，\n马上出发', Lang.en: 'Pick a mood\nand a time. Go.'},
  2: {Lang.zh: '为你此刻的街区，\n生成一条路线', Lang.en: "A walk made for\nwhere you're standing."},
  3: {Lang.zh: '沿途小任务，\n让你看得更仔细', Lang.en: 'Small missions that\nmake you look closer.'},
  4: {Lang.zh: '拍下来，\nMambo 帮你确认', Lang.en: 'Snap it.\nMambo checks it.'},
  5: {Lang.zh: '走完，\n带走一段故事', Lang.en: 'Come home\nwith a story.'},
  6: {Lang.zh: '每一次漫步，\n都留在这里', Lang.en: 'Every walk,\nkept.'},
};
