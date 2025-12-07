// Ignore any warnings/errors here unless it actually does not work

import UIKit
import Flutter
import GoogleMaps   // add this import

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Google Maps iOS API key
    GMSServices.provideAPIKey("AIzaSyDQEMseV8fWCEBiLMGal7slrGBY3ecJfO4")

    // Request notification permissions for iOS
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

