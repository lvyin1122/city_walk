// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'CityWalk';

  @override
  String get language => '语言';

  @override
  String get followSystem => '跟随系统';

  @override
  String get english => 'English';

  @override
  String get chinese => '中文';

  @override
  String get profile => '个人资料';

  @override
  String get about => '关于';

  @override
  String get signOut => '退出登录';

  @override
  String get nameNotSet => '未设置姓名';

  @override
  String get emailNotSet => '未设置邮箱';

  @override
  String get myRecords => '我的记录';

  @override
  String get noRecords => '暂无记录。';

  @override
  String get walkHistory => '步行历史';

  @override
  String get noCompletedWalks => '暂无已完成的步行。';

  @override
  String get startRecording => '开始记录';

  @override
  String get viewStaticSummary => '查看静态总结页';

  @override
  String get viewMyRecords => '查看我的记录';

  @override
  String get generateLegacyPlan => '生成新漫步计划（旧版）';

  @override
  String get welcomeMamboWalk => '欢迎使用 Mambo 漫步！';

  @override
  String get iAmNewUser => '我是新用户';

  @override
  String get iHaveAccount => '我已有账号';

  @override
  String get createYourAccount => '创建你的\\n账户';

  @override
  String get signInYourAccount => '登录你的\\n账户';

  @override
  String get nickname => '昵称';

  @override
  String get email => '邮箱';

  @override
  String get password => '密码';

  @override
  String get confirmPassword => '确认密码';

  @override
  String get signUp => '注册';

  @override
  String get signIn => '登录';

  @override
  String get alreadyHaveAccount => '已有账户？';

  @override
  String get noAccountYet => '还没有账户？';

  @override
  String get passwordMismatch => '两次输入的密码不一致';

  @override
  String get signupSuccessLoginContinue => '注册成功！请登录以继续。';

  @override
  String get requestTimeoutRetry => '请求超时，请重试。';

  @override
  String generateWalkFailed(Object error) {
    return '生成步行路线失败：$error';
  }

  @override
  String get continueYourWalk => '继续你的步行';

  @override
  String get ongoingWalkPrompt => '你有一项进行中的步行。是否继续上次的行程？';

  @override
  String get continueWalk => '继续步行';

  @override
  String get restart => '重新开始';

  @override
  String get selectAtLeastOneLocation => '请至少选择一个地点';

  @override
  String get startWalkingQuestion => '开始步行？';

  @override
  String get maybeLater => '再等一下';

  @override
  String get letsGo => '出发！';

  @override
  String startWalkFailed(Object error) {
    return '开始步行失败：$error';
  }

  @override
  String get cancel => '取消';

  @override
  String get save => '保存';

  @override
  String get editSummary => '编辑总结';

  @override
  String get customSummaryHint => '自定义总结...';

  @override
  String get summaryUpdated => '总结已更新';

  @override
  String get summaryUpdateFailed => '更新总结失败';

  @override
  String errorPrefix(Object error) {
    return '错误：$error';
  }

  @override
  String get reviewYourDay => '回顾你的一天';

  @override
  String get dayReviewCompleted => '完成回顾';

  @override
  String get writeYourFeelings => '写下你的感受...';

  @override
  String get writeYourThoughts => '写下你的想法...';

  @override
  String get submit => '提交';

  @override
  String get stopRecording => '停止记录';

  @override
  String get recordingInProgress => '记录中...';

  @override
  String get addPhoto => '添加照片';

  @override
  String get uploading => '上传中...';

  @override
  String get congratulations => '恭喜！';

  @override
  String get startReviewNow => '开始回顾';

  @override
  String get later => '稍后再说';

  @override
  String get takePhoto => '拍照';

  @override
  String get chooseFromGallery => '从相册选择';

  @override
  String get pleaseSignInFirstToStartRecording => '请先登录以开始记录';

  @override
  String get pleaseSignInFirstToAddRecord => '请先登录以添加记录';

  @override
  String get createRecordFailed => '创建记录失败';

  @override
  String createRecordFailedWithError(Object error) {
    return '创建记录失败：$error';
  }

  @override
  String get uploadPhotoFailed => '上传照片失败';

  @override
  String takePhotoFailedWithError(Object error) {
    return '拍照失败：$error';
  }

  @override
  String loadRecordsFailed(Object error) {
    return '加载记录失败：$error';
  }

  @override
  String startedAt(Object time) {
    return '（开始于 $time）';
  }

  @override
  String get review => '回顾';

  @override
  String get getStarted => '开始使用';

  @override
  String get next => '下一步';

  @override
  String get userNotSignedIn => '用户未登录。';

  @override
  String loadCompletedWalksFailed(Object error) {
    return '加载已完成的步行失败：$error';
  }

  @override
  String get cityWalkAt => '城市漫步于';

  @override
  String get generatingWalkRoute => '正在生成你的步行路线...';

  @override
  String welcomeUser(Object name) {
    return '欢迎！$name';
  }

  @override
  String get startJourneyHere => '从这里开始你的旅程';

  @override
  String get selectKeywords => '选择你的关键词';

  @override
  String get addCustomKeywords => '添加自定义关键词（用逗号分隔）';

  @override
  String get customKeywordsHint => '例如：本地美食、街头艺术、建筑';

  @override
  String get selectWalkDuration => '选择漫步时长';

  @override
  String minutes(int count) {
    return '$count 分钟';
  }

  @override
  String get tapLocationToSelect => '点击任意地点标记查看更多信息并选择要访问的地点';

  @override
  String get selected => '已选';

  @override
  String get select => '选择';

  @override
  String get walkStartPreparation => '准备好开始步行了吗？记得穿上舒适的鞋子和带上水！';

  @override
  String selectedLocations(int count) {
    return '已选地点：$count';
  }

  @override
  String estimatedTime(Object value) {
    return '预计时间：$value';
  }

  @override
  String locationCount(int count) {
    return '地点数：$count';
  }

  @override
  String get startWalking => '开始步行';

  @override
  String get recordCompleteReviewNow => '记录已完成。是否现在回顾？';

  @override
  String get recordAMoment => '记录一个瞬间';

  @override
  String addRecordFailed(Object error) {
    return '添加记录失败：$error';
  }

  @override
  String get recordAdded => '记录已添加';

  @override
  String get reflectionQ1 => '步行时你注意到了什么？';

  @override
  String get reflectionQ2 => '步行时你的感受如何？';

  @override
  String get reflectionQ3 => '有没有什么让你惊喜或难忘的？';

  @override
  String get reflectionQ4 => '下次你会有什么不同的做法？';

  @override
  String get noReflectionsAddHint => '暂无反思。\\n点击 + 添加';

  @override
  String get addReflection => '添加反思';

  @override
  String questionProgress(int current, int total) {
    return '第 $current 题，共 $total 题';
  }

  @override
  String get close => '关闭';

  @override
  String get back => '返回';

  @override
  String get complete => '完成';

  @override
  String get myReflection => '我的反思';

  @override
  String get location => '位置';

  @override
  String get dateAndTime => '日期与时间';

  @override
  String get map => '地图';

  @override
  String get date => '日期';

  @override
  String get duration => '时长';

  @override
  String get distance => '距离';

  @override
  String get completedTasks => '完成任务';

  @override
  String get routeMap => '路线地图';

  @override
  String get startPoint => '起点';

  @override
  String get endPoint => '终点';

  @override
  String get photoGallery => '照片画廊';
}
