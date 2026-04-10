import Flutter
import UIKit
import GoogleMaps

func getEnvVar(name: String) -> String {
    guard let envPath = Bundle.main.path(forResource: "flutter_assets/.env", ofType: nil) else { return "" }
    guard let envString = try? String(contentsOfFile: envPath) else { return "" }
    let lines = envString.components(separatedBy: .newlines)
    for line in lines {
        let parts = line.components(separatedBy: "=")
        if parts.count >= 2 && parts[0].trimmingCharacters(in: .whitespaces) == name {
            let val = parts[1...].joined(separator: "=").trimmingCharacters(in: .whitespaces)
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
    let mapsApiKey = getEnvVar(name: "GOOGLE_MAPS_API_KEY")
    if !mapsApiKey.isEmpty {
        GMSServices.provideAPIKey(mapsApiKey)
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
