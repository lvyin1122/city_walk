import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // The key comes from Flutter/Secrets.xcconfig through Info.plist, so it is
    // not stored in the repository. See Flutter/Secrets.example.xcconfig.
    let mapsApiKey = (Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String ?? "")
      .trimmingCharacters(in: .whitespaces)
    // Without a key the Maps SDK throws in checkServicePreconditions as soon
    // as the first map opens. Stop debug builds here with the reason instead.
    if mapsApiKey.isEmpty || mapsApiKey.hasPrefix("$(") {
      assertionFailure(
        "MAPS_API_KEY is empty. Copy ios/Flutter/Secrets.example.xcconfig to "
          + "ios/Flutter/Secrets.xcconfig, set the iOS Maps key, then rebuild.")
    }
    GMSServices.provideAPIKey(mapsApiKey)
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
