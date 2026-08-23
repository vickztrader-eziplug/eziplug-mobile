import Flutter
import UIKit
import Firebase

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // FirebaseApp.configure() raises an Objective-C NSException (which Swift
    // do/catch CANNOT catch) when GoogleService-Info.plist is not present in
    // the app bundle, terminating the app before Flutter ever starts. Guard on
    // the file's presence so a packaging mistake degrades to "push disabled"
    // instead of an immediate launch crash.
    if FirebaseApp.app() == nil {
      if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
        FirebaseApp.configure()
      } else {
        NSLog("[Eziplug] GoogleService-Info.plist is missing from the app bundle — "
              + "Firebase was not configured and push notifications are disabled. "
              + "Add it to the Runner target's Copy Bundle Resources phase.")
      }
    }

    // Set the UNUserNotificationCenter delegate so the notification
    // permission dialog can appear and foreground notifications work.
    UNUserNotificationCenter.current().delegate = self

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
