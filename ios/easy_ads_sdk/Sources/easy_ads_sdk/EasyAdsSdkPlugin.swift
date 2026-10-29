import AppTrackingTransparency
import Flutter
import UIKit

public class EasyAdsSdkPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "easy_ads_sdk/tracking",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(EasyAdsSdkPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "requestTracking":
      requestTracking(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func requestTracking(result: @escaping FlutterResult) {
    if #available(iOS 14, *) {
      ATTrackingManager.requestTrackingAuthorization { status in
        let name: String
        switch status {
        case .authorized:
          name = "authorized"
        case .denied:
          name = "denied"
        case .restricted:
          name = "restricted"
        case .notDetermined:
          name = "notDetermined"
        @unknown default:
          name = "notDetermined"
        }
        DispatchQueue.main.async {
          result(name)
        }
      }
    } else {
      result("authorized")
    }
  }
}
