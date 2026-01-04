import UIKit
import Flutter

enum AppGroup: String {
    case shared = "group.com.au.shared"

    static func containerPath() -> String? {
        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroup.shared.rawValue
        ) else {
            return nil
        }
        return url.path
    }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController

    let channel = FlutterMethodChannel(
      name: "com.au/appgroup",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getAppGroupPath":
        if let path = AppGroup.containerPath() {
          result(path)
        } else {
          // Return empty string if App Group is not configured / available.
          result("")
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
