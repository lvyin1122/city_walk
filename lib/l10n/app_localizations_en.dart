// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'CityWalk';

  @override
  String get language => 'Language';

  @override
  String get followSystem => 'Follow System';

  @override
  String get english => 'English';

  @override
  String get chinese => 'Chinese';

  @override
  String get profile => 'Profile';

  @override
  String get about => 'About';

  @override
  String get signOut => 'Sign Out';

  @override
  String get nameNotSet => 'Name not set';

  @override
  String get emailNotSet => 'Email not set';

  @override
  String get myRecords => 'My Records';

  @override
  String get noRecords => 'No records yet.';

  @override
  String get walkHistory => 'Walk History';

  @override
  String get noCompletedWalks => 'No completed walks yet.';

  @override
  String get startRecording => 'Start Recording';

  @override
  String get viewStaticSummary => 'View Static Summary';

  @override
  String get viewMyRecords => 'View My Records';

  @override
  String get generateLegacyPlan => 'Generate New Walk Plan (Legacy)';

  @override
  String get welcomeMamboWalk => 'Welcome to Mambo Walk!';

  @override
  String get iAmNewUser => 'I am a new user';

  @override
  String get iHaveAccount => 'I already have an account';

  @override
  String get createYourAccount => 'Create your\\nAccount';

  @override
  String get signInYourAccount => 'Sign in to\\nYour Account';

  @override
  String get nickname => 'Nickname';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get signUp => 'Sign Up';

  @override
  String get signIn => 'Sign In';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get noAccountYet => 'Don\'t have an account yet?';

  @override
  String get passwordMismatch => 'Passwords do not match';

  @override
  String get signupSuccessLoginContinue => 'Sign up successful! Please sign in to continue.';

  @override
  String get requestTimeoutRetry => 'Request timed out, please try again.';

  @override
  String generateWalkFailed(Object error) {
    return 'Failed to generate walk route: $error';
  }

  @override
  String get continueYourWalk => 'Continue your walk';

  @override
  String get ongoingWalkPrompt => 'You have an ongoing walk. Continue your previous journey?';

  @override
  String get continueWalk => 'Continue Walk';

  @override
  String get restart => 'Restart';

  @override
  String get selectAtLeastOneLocation => 'Please select at least one location';

  @override
  String get startWalkingQuestion => 'Start walking?';

  @override
  String get maybeLater => 'Maybe later';

  @override
  String get letsGo => 'Let\'s go!';

  @override
  String startWalkFailed(Object error) {
    return 'Failed to start walking: $error';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get editSummary => 'Edit Summary';

  @override
  String get customSummaryHint => 'Custom summary...';

  @override
  String get summaryUpdated => 'Summary updated';

  @override
  String get summaryUpdateFailed => 'Failed to update summary';

  @override
  String errorPrefix(Object error) {
    return 'Error: $error';
  }

  @override
  String get reviewYourDay => 'Review your day';

  @override
  String get dayReviewCompleted => 'Complete Review';

  @override
  String get writeYourFeelings => 'Write down your feelings...';

  @override
  String get writeYourThoughts => 'Write your thoughts...';

  @override
  String get submit => 'Submit';

  @override
  String get stopRecording => 'Stop Recording';

  @override
  String get recordingInProgress => 'Recording...';

  @override
  String get addPhoto => 'Add Photo';

  @override
  String get uploading => 'Uploading...';

  @override
  String get congratulations => 'Congratulations!';

  @override
  String get startReviewNow => 'Start Review';

  @override
  String get later => 'Later';

  @override
  String get takePhoto => 'Take Photo';

  @override
  String get chooseFromGallery => 'Choose from Gallery';

  @override
  String get pleaseSignInFirstToStartRecording => 'Please sign in first to start recording';

  @override
  String get pleaseSignInFirstToAddRecord => 'Please sign in first to add a record';

  @override
  String get createRecordFailed => 'Failed to create record';

  @override
  String createRecordFailedWithError(Object error) {
    return 'Failed to create record: $error';
  }

  @override
  String get uploadPhotoFailed => 'Photo upload failed';

  @override
  String takePhotoFailedWithError(Object error) {
    return 'Failed to take photo: $error';
  }

  @override
  String loadRecordsFailed(Object error) {
    return 'Failed to load records: $error';
  }

  @override
  String startedAt(Object time) {
    return ' (started at $time)';
  }

  @override
  String get review => 'Review';

  @override
  String get getStarted => 'Get Started';

  @override
  String get next => 'Next';

  @override
  String get userNotSignedIn => 'User not signed in.';

  @override
  String loadCompletedWalksFailed(Object error) {
    return 'Failed to load completed walks: $error';
  }

  @override
  String get cityWalkAt => 'City walk at';

  @override
  String get generatingWalkRoute => 'Generating your walk route...';

  @override
  String welcomeUser(Object name) {
    return 'Welcome! $name';
  }

  @override
  String get startJourneyHere => 'Start your journey here';

  @override
  String get selectKeywords => 'Choose your keywords';

  @override
  String get addCustomKeywords => 'Add custom keywords (comma-separated)';

  @override
  String get customKeywordsHint => 'Example: local food, street art, architecture';

  @override
  String get selectWalkDuration => 'Select walk duration';

  @override
  String minutes(int count) {
    return '$count min';
  }

  @override
  String get tapLocationToSelect => 'Tap any location marker to view details and select places to visit';

  @override
  String get selected => 'Selected';

  @override
  String get select => 'Select';

  @override
  String get walkStartPreparation => 'Ready to start walking? Wear comfortable shoes and bring water!';

  @override
  String selectedLocations(int count) {
    return 'Selected locations: $count';
  }

  @override
  String estimatedTime(Object value) {
    return 'Estimated time: $value';
  }

  @override
  String locationCount(int count) {
    return 'Locations: $count';
  }

  @override
  String get startWalking => 'Start Walking';

  @override
  String get recordCompleteReviewNow => 'Recording complete. Review now?';

  @override
  String get recordAMoment => 'Record a moment';

  @override
  String addRecordFailed(Object error) {
    return 'Failed to add record: $error';
  }

  @override
  String get recordAdded => 'Record added';

  @override
  String get reflectionQ1 => 'What did you notice while walking?';

  @override
  String get reflectionQ2 => 'How did you feel during the walk?';

  @override
  String get reflectionQ3 => 'What surprised you or felt memorable?';

  @override
  String get reflectionQ4 => 'What would you do differently next time?';

  @override
  String get noReflectionsAddHint => 'No reflections yet.\\nTap + to add';

  @override
  String get addReflection => 'Add Reflection';

  @override
  String questionProgress(int current, int total) {
    return 'Question $current of $total';
  }

  @override
  String get close => 'Close';

  @override
  String get back => 'Back';

  @override
  String get complete => 'Complete';

  @override
  String get myReflection => 'My Reflection';

  @override
  String get location => 'Location';

  @override
  String get dateAndTime => 'Date & Time';

  @override
  String get map => 'Map';

  @override
  String get date => 'Date';

  @override
  String get duration => 'Duration';

  @override
  String get distance => 'Distance';

  @override
  String get completedTasks => 'Completed Tasks';

  @override
  String get routeMap => 'Route Map';

  @override
  String get startPoint => 'Start';

  @override
  String get endPoint => 'End';

  @override
  String get photoGallery => 'Photo Gallery';
}
