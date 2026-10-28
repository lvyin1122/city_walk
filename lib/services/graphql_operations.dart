/// Every GraphQL document the app sends to the backend.
///
/// Arguments always travel as GraphQL variables, never inside the document,
/// so user text cannot change a query. The list in [all] is exported by
/// `test/contract/operations_test.dart` to `test/contract/operations.json`;
/// the backend's contract test validates that file against its schema, so a
/// change on either side that breaks the other fails a test.
abstract final class GraphQLOperations {
  static const _stopFields = '''
    name
    description
    estimatedTime
    selected
    collected
    photoUrls
    coordinates { latitude longitude }''';

  static const _taskFields = '''
    createdTime
    description
    photosRequired
    photosFulfilled
    status''';

  static const _walkSummaryFields = '''
    Id
    userId
    totalDuration
    title
    description
    createdAt
    status''';

  static const _walkFields =
      '''
    $_walkSummaryFields
    timeSpent
    distanceTraveled
    tasksCompleted
    tasksTotal
    userAddress
    city
    locations { $_stopFields }
    tasks {
      $_taskFields
      images { url coordinates { latitude longitude } }
    }
    favoriteLocations { latitude longitude photoUrl }''';

  // --- walks -----------------------------------------------------------------

  static const completedWalks =
      '''
query CompletedWalks(\$userId: String!) {
  completedWalksByUserId(userId: \$userId) { $_walkFields }
}''';

  static const generateWalk =
      '''
mutation GenerateWalk(\$userId: String!, \$location: String!, \$keywords: String!, \$duration: Int!) {
  generateWalkWithGpt(userId: \$userId, location: \$location, keywords: \$keywords, duration: \$duration) {
    walk {
      $_walkSummaryFields
      locations { $_stopFields }
      tasks { $_taskFields }
    }
  }
}''';

  static const generateTask =
      '''
mutation GenerateTask(\$walkId: String!) {
  generateTaskWithGpt(walkId: \$walkId) {
    task { $_taskFields }
  }
}''';

  static const verifyTask = r'''
mutation VerifyTask($walkId: String!, $imageUrl: String!, $latitude: Float, $longitude: Float) {
  verifyTaskWithGpt(walkId: $walkId, imageUrl: $imageUrl, latitude: $latitude, longitude: $longitude) {
    success
    message
    photosFulfilled
    taskStatus
  }
}''';

  static const updateWalkStatus =
      '''
mutation UpdateWalkStatus(\$walkId: String!, \$status: String!) {
  updateWalkStatus(walkId: \$walkId, status: \$status) {
    walk { $_walkSummaryFields }
  }
}''';

  static const addWalkCoordinate = r'''
mutation AddWalkCoordinate($walkId: String!, $userId: String!, $latitude: Float!, $longitude: Float!, $timestamp: String!) {
  addWalkCoordinate(walkId: $walkId, userId: $userId, latitude: $latitude, longitude: $longitude, timestamp: $timestamp) {
    walkTracking { walkId userId }
  }
}''';

  static const updateWalkStats =
      '''
mutation UpdateWalkStats(\$walkId: String!, \$distanceTraveled: Float!, \$timeSpent: Int!) {
  updateWalkStats(walkId: \$walkId, distanceTraveled: \$distanceTraveled, timeSpent: \$timeSpent) {
    walk {
      $_walkSummaryFields
      timeSpent
      distanceTraveled
      tasksCompleted
      tasksTotal
    }
  }
}''';

  static const allTasksImages = r'''
mutation AllTasksImages($walkId: String!) {
  getAllTasksImages(walkId: $walkId) {
    images { url coordinates { latitude longitude } }
  }
}''';

  static const walkSummary = r'''
mutation WalkSummary($walkId: String!) {
  generateWalkSummary(walkId: $walkId) { summary }
}''';

  static const selectLocations =
      '''
mutation SelectLocations(\$walkId: String!, \$locationIndexes: [Int]) {
  selectLocations(walkId: \$walkId, locationIndexes: \$locationIndexes) {
    walk {
      Id
      userId
      locations { $_stopFields }
    }
  }
}''';

  static const collectLocation = r'''
mutation CollectLocation($walkId: String!, $locationIndex: Int!) {
  collectLocation(walkId: $walkId, locationIndex: $locationIndex) {
    walk {
      Id
      status
      locations { name collected }
    }
  }
}''';

  static const addFavoriteLocation = r'''
mutation AddFavoriteLocation($walkId: String!, $latitude: Float!, $longitude: Float!, $photoUrl: String) {
  addFavoriteLocation(walkId: $walkId, latitude: $latitude, longitude: $longitude, photoUrl: $photoUrl) {
    walk {
      favoriteLocations { latitude longitude photoUrl }
    }
  }
}''';

  static const favoriteLocations = r'''
mutation FavoriteLocations($walkId: String!) {
  getFavoriteLocations(walkId: $walkId) {
    favoriteLocations { latitude longitude photoUrl }
  }
}''';

  static const walk =
      '''
query Walk(\$id: String!) {
  walk(id: \$id) { $_walkFields }
}''';

  static const walkTracking = r'''
query WalkTracking($walkId: String!) {
  walkTracking(walkId: $walkId) {
    coordinates { latitude longitude }
  }
}''';

  static const latestInProgressWalk = r'''
query LatestInProgressWalk($userId: String!) {
  latestInProgressWalk(userId: $userId) { Id }
}''';

  // --- logs ------------------------------------------------------------------

  static const _logEntryFields =
      'timestamp imageUrl reflectionText question quickReplies lat lng address';

  static const _logTrackingFields =
      'logTracking { logId sessions { points { lat lng timestamp } } }';

  static const _reviewFields =
      '''
    startTimestamp
    logEntries { $_logEntryFields }
    overallQuestion
    quickReplies
    followUpQuestion
    overallAnswer
    followUpAnswer
    imageTagQuestion
    imageTagQuickReplies
    imageTagAnswer
    overallReflection
    overallAiSummary''';

  static const addLogEntry =
      '''
mutation AddLogEntry(\$userId: String!, \$logId: String, \$timestamp: String!, \$imageUrl: String!, \$reflectionText: String, \$lat: Float, \$lng: Float, \$timezoneOffsetMinutes: Int) {
  addLogEntry(userId: \$userId, logId: \$logId, timestamp: \$timestamp, imageUrl: \$imageUrl, reflectionText: \$reflectionText, lat: \$lat, lng: \$lng, timezoneOffsetMinutes: \$timezoneOffsetMinutes) {
    success
    message
    log {
      id
      userId
      startTimestamp
      logEntries { $_logEntryFields }
    }
  }
}''';

  static const updateLogEntryReflection =
      '''
mutation UpdateLogEntryReflection(\$logId: String!, \$userId: String!, \$reflectionText: String!) {
  updateLogEntryReflection(logId: \$logId, userId: \$userId, reflectionText: \$reflectionText) {
    success
    message
    log {
      id
      logEntries { $_logEntryFields }
    }
  }
}''';

  static const startLogTracking = r'''
mutation StartLogTracking($userId: String!, $timezoneOffsetMinutes: Int!) {
  startLogTracking(userId: $userId, timezoneOffsetMinutes: $timezoneOffsetMinutes) { logId }
}''';

  static const addLogTrackingPoint = r'''
mutation AddLogTrackingPoint($logId: String!, $userId: String!, $lat: Float!, $lng: Float!, $timestamp: String!) {
  addLogTrackingPoint(logId: $logId, userId: $userId, lat: $lat, lng: $lng, timestamp: $timestamp) {
    success
    latestSession { lat lng }
  }
}''';

  static const endLogTrackingSession = r'''
mutation EndLogTrackingSession($logId: String!) {
  endLogTrackingSession(logId: $logId) { success }
}''';

  static const logs =
      '''
query GetLogs(\$userId: String) {
  logs(userId: \$userId) {
    id
    userId
    startTimestamp
    logEntries { $_logEntryFields }
    overallQuestion
    quickReplies
    followUpQuestion
    overallAnswer
    followUpAnswer
    overallReflection
    overallAiSummary
    scrapbookImageUrl
    $_logTrackingFields
  }
}''';

  static const logForReview =
      '''
mutation GetLogForReview(\$userId: String!, \$date: String!, \$timezoneOffsetMinutes: Int!) {
  getLogForReview(userId: \$userId, date: \$date, timezoneOffsetMinutes: \$timezoneOffsetMinutes) {
    log {
      id
      userId
      $_reviewFields
      scrapbookImageUrl
      $_logTrackingFields
    }
  }
}''';

  static const regenerateReflectionQuestion =
      '''
mutation RegenerateReflectionQuestion(\$logId: String!, \$userId: String!) {
  regenerateReflectionQuestion(logId: \$logId, userId: \$userId) {
    log {
      id
      userId
      $_reviewFields
      $_logTrackingFields
    }
  }
}''';

  static const updateReflectionAnswers =
      '''
mutation UpdateReflectionAnswers(\$logId: String!, \$overallAnswer: String, \$followUpAnswer: String, \$overallReflection: String, \$imageTagAnswer: String) {
  updateReflectionAnswers(logId: \$logId, overallAnswer: \$overallAnswer, followUpAnswer: \$followUpAnswer, overallReflection: \$overallReflection, imageTagAnswer: \$imageTagAnswer) {
    log {
      id
      $_reviewFields
      $_logTrackingFields
    }
  }
}''';

  static const updateOverallAiSummary =
      '''
mutation UpdateOverallAiSummary(\$logId: String!, \$userId: String!, \$overallAiSummary: String!) {
  updateOverallAiSummary(logId: \$logId, userId: \$userId, overallAiSummary: \$overallAiSummary) {
    log {
      id
      $_reviewFields
      $_logTrackingFields
    }
  }
}''';

  static const generateLogScrapbookImage = r'''
mutation GenerateLogScrapbookImage($logId: String!, $userId: String!) {
  generateLogScrapbookImage(logId: $logId, userId: $userId) {
    imageUrl
    success
    message
  }
}''';

  /// Every operation, by name. Exported for the backend contract test.
  static const all = <String, String>{
    'completedWalks': completedWalks,
    'generateWalk': generateWalk,
    'generateTask': generateTask,
    'verifyTask': verifyTask,
    'updateWalkStatus': updateWalkStatus,
    'addWalkCoordinate': addWalkCoordinate,
    'updateWalkStats': updateWalkStats,
    'allTasksImages': allTasksImages,
    'walkSummary': walkSummary,
    'selectLocations': selectLocations,
    'collectLocation': collectLocation,
    'addFavoriteLocation': addFavoriteLocation,
    'favoriteLocations': favoriteLocations,
    'walk': walk,
    'walkTracking': walkTracking,
    'latestInProgressWalk': latestInProgressWalk,
    'addLogEntry': addLogEntry,
    'updateLogEntryReflection': updateLogEntryReflection,
    'startLogTracking': startLogTracking,
    'addLogTrackingPoint': addLogTrackingPoint,
    'endLogTrackingSession': endLogTrackingSession,
    'logs': logs,
    'logForReview': logForReview,
    'regenerateReflectionQuestion': regenerateReflectionQuestion,
    'updateReflectionAnswers': updateReflectionAnswers,
    'updateOverallAiSummary': updateOverallAiSummary,
    'generateLogScrapbookImage': generateLogScrapbookImage,
  };
}
