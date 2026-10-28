import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'CityWalk'**
  String get appTitle;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow System'**
  String get followSystem;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @chinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get chinese;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @nameNotSet.
  ///
  /// In en, this message translates to:
  /// **'Name not set'**
  String get nameNotSet;

  /// No description provided for @emailNotSet.
  ///
  /// In en, this message translates to:
  /// **'Email not set'**
  String get emailNotSet;

  /// No description provided for @myRecords.
  ///
  /// In en, this message translates to:
  /// **'My Records'**
  String get myRecords;

  /// No description provided for @noRecords.
  ///
  /// In en, this message translates to:
  /// **'No records yet.'**
  String get noRecords;

  /// No description provided for @walkHistory.
  ///
  /// In en, this message translates to:
  /// **'Walk History'**
  String get walkHistory;

  /// No description provided for @noCompletedWalks.
  ///
  /// In en, this message translates to:
  /// **'No completed walks yet.'**
  String get noCompletedWalks;

  /// No description provided for @startRecording.
  ///
  /// In en, this message translates to:
  /// **'Start Recording'**
  String get startRecording;

  /// No description provided for @viewStaticSummary.
  ///
  /// In en, this message translates to:
  /// **'View Static Summary'**
  String get viewStaticSummary;

  /// No description provided for @viewMyRecords.
  ///
  /// In en, this message translates to:
  /// **'View My Records'**
  String get viewMyRecords;

  /// No description provided for @generateLegacyPlan.
  ///
  /// In en, this message translates to:
  /// **'Generate New Walk Plan (Legacy)'**
  String get generateLegacyPlan;

  /// No description provided for @welcomeMamboWalk.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Mambo Walk!'**
  String get welcomeMamboWalk;

  /// No description provided for @iAmNewUser.
  ///
  /// In en, this message translates to:
  /// **'I am a new user'**
  String get iAmNewUser;

  /// No description provided for @iHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'I already have an account'**
  String get iHaveAccount;

  /// No description provided for @createYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Create your\\nAccount'**
  String get createYourAccount;

  /// No description provided for @signInYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign in to\\nYour Account'**
  String get signInYourAccount;

  /// No description provided for @nickname.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get nickname;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @noAccountYet.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account yet?'**
  String get noAccountYet;

  /// No description provided for @passwordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordMismatch;

  /// No description provided for @signupSuccessLoginContinue.
  ///
  /// In en, this message translates to:
  /// **'Sign up successful! Please sign in to continue.'**
  String get signupSuccessLoginContinue;

  /// No description provided for @requestTimeoutRetry.
  ///
  /// In en, this message translates to:
  /// **'Request timed out, please try again.'**
  String get requestTimeoutRetry;

  /// No description provided for @generateWalkFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to generate walk route: {error}'**
  String generateWalkFailed(Object error);

  /// No description provided for @continueYourWalk.
  ///
  /// In en, this message translates to:
  /// **'Continue your walk'**
  String get continueYourWalk;

  /// No description provided for @ongoingWalkPrompt.
  ///
  /// In en, this message translates to:
  /// **'You have an ongoing walk. Continue your previous journey?'**
  String get ongoingWalkPrompt;

  /// No description provided for @continueWalk.
  ///
  /// In en, this message translates to:
  /// **'Continue Walk'**
  String get continueWalk;

  /// No description provided for @restart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restart;

  /// No description provided for @selectAtLeastOneLocation.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one location'**
  String get selectAtLeastOneLocation;

  /// No description provided for @startWalkingQuestion.
  ///
  /// In en, this message translates to:
  /// **'Start walking?'**
  String get startWalkingQuestion;

  /// No description provided for @maybeLater.
  ///
  /// In en, this message translates to:
  /// **'Maybe later'**
  String get maybeLater;

  /// No description provided for @letsGo.
  ///
  /// In en, this message translates to:
  /// **'Let\'s go!'**
  String get letsGo;

  /// No description provided for @startWalkFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to start walking: {error}'**
  String startWalkFailed(Object error);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @editSummary.
  ///
  /// In en, this message translates to:
  /// **'Edit Summary'**
  String get editSummary;

  /// No description provided for @customSummaryHint.
  ///
  /// In en, this message translates to:
  /// **'Custom summary...'**
  String get customSummaryHint;

  /// No description provided for @summaryUpdated.
  ///
  /// In en, this message translates to:
  /// **'Summary updated'**
  String get summaryUpdated;

  /// No description provided for @summaryUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update summary'**
  String get summaryUpdateFailed;

  /// No description provided for @errorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorPrefix(Object error);

  /// No description provided for @reviewYourDay.
  ///
  /// In en, this message translates to:
  /// **'Review your day'**
  String get reviewYourDay;

  /// No description provided for @dayReviewCompleted.
  ///
  /// In en, this message translates to:
  /// **'Complete Review'**
  String get dayReviewCompleted;

  /// No description provided for @writeYourFeelings.
  ///
  /// In en, this message translates to:
  /// **'Write down your feelings...'**
  String get writeYourFeelings;

  /// No description provided for @writeYourThoughts.
  ///
  /// In en, this message translates to:
  /// **'Write your thoughts...'**
  String get writeYourThoughts;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @stopRecording.
  ///
  /// In en, this message translates to:
  /// **'Stop Recording'**
  String get stopRecording;

  /// No description provided for @recordingInProgress.
  ///
  /// In en, this message translates to:
  /// **'Recording...'**
  String get recordingInProgress;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add Photo'**
  String get addPhoto;

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get uploading;

  /// No description provided for @congratulations.
  ///
  /// In en, this message translates to:
  /// **'Congratulations!'**
  String get congratulations;

  /// No description provided for @startReviewNow.
  ///
  /// In en, this message translates to:
  /// **'Start Review'**
  String get startReviewNow;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takePhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get chooseFromGallery;

  /// No description provided for @pleaseSignInFirstToStartRecording.
  ///
  /// In en, this message translates to:
  /// **'Please sign in first to start recording'**
  String get pleaseSignInFirstToStartRecording;

  /// No description provided for @pleaseSignInFirstToAddRecord.
  ///
  /// In en, this message translates to:
  /// **'Please sign in first to add a record'**
  String get pleaseSignInFirstToAddRecord;

  /// No description provided for @createRecordFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create record'**
  String get createRecordFailed;

  /// No description provided for @createRecordFailedWithError.
  ///
  /// In en, this message translates to:
  /// **'Failed to create record: {error}'**
  String createRecordFailedWithError(Object error);

  /// No description provided for @uploadPhotoFailed.
  ///
  /// In en, this message translates to:
  /// **'Photo upload failed'**
  String get uploadPhotoFailed;

  /// No description provided for @takePhotoFailedWithError.
  ///
  /// In en, this message translates to:
  /// **'Failed to take photo: {error}'**
  String takePhotoFailedWithError(Object error);

  /// No description provided for @loadRecordsFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load records: {error}'**
  String loadRecordsFailed(Object error);

  /// No description provided for @startedAt.
  ///
  /// In en, this message translates to:
  /// **' (started at {time})'**
  String startedAt(Object time);

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @userNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'User not signed in.'**
  String get userNotSignedIn;

  /// No description provided for @loadCompletedWalksFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load completed walks: {error}'**
  String loadCompletedWalksFailed(Object error);

  /// No description provided for @cityWalkAt.
  ///
  /// In en, this message translates to:
  /// **'City walk at'**
  String get cityWalkAt;

  /// No description provided for @generatingWalkRoute.
  ///
  /// In en, this message translates to:
  /// **'Generating your walk route...'**
  String get generatingWalkRoute;

  /// No description provided for @welcomeUser.
  ///
  /// In en, this message translates to:
  /// **'Welcome! {name}'**
  String welcomeUser(Object name);

  /// No description provided for @startJourneyHere.
  ///
  /// In en, this message translates to:
  /// **'Start your journey here'**
  String get startJourneyHere;

  /// No description provided for @selectKeywords.
  ///
  /// In en, this message translates to:
  /// **'Choose your keywords'**
  String get selectKeywords;

  /// No description provided for @addCustomKeywords.
  ///
  /// In en, this message translates to:
  /// **'Add custom keywords (comma-separated)'**
  String get addCustomKeywords;

  /// No description provided for @customKeywordsHint.
  ///
  /// In en, this message translates to:
  /// **'Example: local food, street art, architecture'**
  String get customKeywordsHint;

  /// No description provided for @selectWalkDuration.
  ///
  /// In en, this message translates to:
  /// **'Select walk duration'**
  String get selectWalkDuration;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String minutes(int count);

  /// No description provided for @tapLocationToSelect.
  ///
  /// In en, this message translates to:
  /// **'Tap any location marker to view details and select places to visit'**
  String get tapLocationToSelect;

  /// No description provided for @selected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get selected;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @walkStartPreparation.
  ///
  /// In en, this message translates to:
  /// **'Ready to start walking? Wear comfortable shoes and bring water!'**
  String get walkStartPreparation;

  /// No description provided for @selectedLocations.
  ///
  /// In en, this message translates to:
  /// **'Selected locations: {count}'**
  String selectedLocations(int count);

  /// No description provided for @estimatedTime.
  ///
  /// In en, this message translates to:
  /// **'Estimated time: {value}'**
  String estimatedTime(Object value);

  /// No description provided for @locationCount.
  ///
  /// In en, this message translates to:
  /// **'Locations: {count}'**
  String locationCount(int count);

  /// No description provided for @startWalking.
  ///
  /// In en, this message translates to:
  /// **'Start Walking'**
  String get startWalking;

  /// No description provided for @recordCompleteReviewNow.
  ///
  /// In en, this message translates to:
  /// **'Recording complete. Review now?'**
  String get recordCompleteReviewNow;

  /// No description provided for @recordAMoment.
  ///
  /// In en, this message translates to:
  /// **'Record a moment'**
  String get recordAMoment;

  /// No description provided for @addRecordFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add record: {error}'**
  String addRecordFailed(Object error);

  /// No description provided for @recordAdded.
  ///
  /// In en, this message translates to:
  /// **'Record added'**
  String get recordAdded;

  /// No description provided for @reflectionQ1.
  ///
  /// In en, this message translates to:
  /// **'What did you notice while walking?'**
  String get reflectionQ1;

  /// No description provided for @reflectionQ2.
  ///
  /// In en, this message translates to:
  /// **'How did you feel during the walk?'**
  String get reflectionQ2;

  /// No description provided for @reflectionQ3.
  ///
  /// In en, this message translates to:
  /// **'What surprised you or felt memorable?'**
  String get reflectionQ3;

  /// No description provided for @reflectionQ4.
  ///
  /// In en, this message translates to:
  /// **'What would you do differently next time?'**
  String get reflectionQ4;

  /// No description provided for @noReflectionsAddHint.
  ///
  /// In en, this message translates to:
  /// **'No reflections yet.\\nTap + to add'**
  String get noReflectionsAddHint;

  /// No description provided for @addReflection.
  ///
  /// In en, this message translates to:
  /// **'Add Reflection'**
  String get addReflection;

  /// No description provided for @questionProgress.
  ///
  /// In en, this message translates to:
  /// **'Question {current} of {total}'**
  String questionProgress(int current, int total);

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @complete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get complete;

  /// No description provided for @myReflection.
  ///
  /// In en, this message translates to:
  /// **'My Reflection'**
  String get myReflection;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @dateAndTime.
  ///
  /// In en, this message translates to:
  /// **'Date & Time'**
  String get dateAndTime;

  /// No description provided for @map.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get map;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @completedTasks.
  ///
  /// In en, this message translates to:
  /// **'Completed Tasks'**
  String get completedTasks;

  /// No description provided for @routeMap.
  ///
  /// In en, this message translates to:
  /// **'Route Map'**
  String get routeMap;

  /// No description provided for @startPoint.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startPoint;

  /// No description provided for @endPoint.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get endPoint;

  /// No description provided for @photoGallery.
  ///
  /// In en, this message translates to:
  /// **'Photo Gallery'**
  String get photoGallery;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'zh': return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
