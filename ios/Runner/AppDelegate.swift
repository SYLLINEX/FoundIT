import Flutter
import UIKit
import GoogleMaps
import UserNotifications

/// Reads a key from the bundled flutter_assets/.env file.
/// Used as a fallback for local development when the xcconfig
/// placeholder has not been replaced by Codemagic.
func getEnvVar(name: String) -> String {
    guard let envPath = Bundle.main.path(forResource: ".env", ofType: nil, inDirectory: "Frameworks/App.framework/flutter_assets") else {
        // Fallback: some Flutter toolchains place assets at a different depth
        guard let altPath = Bundle.main.path(forResource: "flutter_assets/.env", ofType: nil) else { return "" }
        guard let altString = try? String(contentsOfFile: altPath) else { return "" }
        return parseEnv(contents: altString, key: name)
    }
    guard let envString = try? String(contentsOfFile: envPath) else { return "" }
    return parseEnv(contents: envString, key: name)
}

private func parseEnv(contents: String, key: String) -> String {
    let lines = contents.components(separatedBy: .newlines)
    for line in lines {
        let cleanLine = line.replacingOccurrences(of: "\r", with: "")
        let parts = cleanLine.components(separatedBy: "=")
        if parts.count >= 2 && parts[0].trimmingCharacters(in: .whitespaces) == key {
            var val = parts[1...].joined(separator: "=").trimmingCharacters(in: .whitespaces)
            val = val.replacingOccurrences(of: "\"", with: "")
            val = val.replacingOccurrences(of: "'", with: "")
            return val
        }
    }
    return ""
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // --- Google Maps API Key ---
    // Priority 1: Read from Info.plist (injected via xcconfig by Codemagic)
    var mapsApiKey = ""
    if let plistKey = Bundle.main.object(forInfoDictionaryKey: "googleMapsApiKey") as? String,
       !plistKey.isEmpty,
       plistKey != "INJECT_MAPS_API_KEY_HERE" {
        mapsApiKey = plistKey
    }
    
    // Priority 2: Fallback to .env bundle asset (for local development)
    if mapsApiKey.isEmpty {
        mapsApiKey = getEnvVar(name: "GOOGLE_MAPS_API_KEY")
    }
    
    if !mapsApiKey.isEmpty {
        GMSServices.provideAPIKey(mapsApiKey)
    }

    // --- iOS Push Notifications ---
    // Setting the UNUserNotificationCenter delegate to `self` (FlutterAppDelegate)
    // is REQUIRED for push notifications to appear as banners while the app is
    // in the foreground. Without this, FCM foreground messages are silently dropped
    // by iOS even if flutter_local_notifications is configured correctly.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
