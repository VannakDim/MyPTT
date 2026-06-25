import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // 1. Register generated plugins with the engine
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // 2. Register com.example.mobile/audio method channel using the engine's binary messenger
    let audioChannel = FlutterMethodChannel(name: "com.example.mobile/audio",
                                              binaryMessenger: engineBridge.applicationRegistrar.messenger())
    audioChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "setSpeakerphoneOn" {
          guard let args = call.arguments as? [String: Any],
                let enable = args["enable"] as? Bool else {
              result(FlutterError(code: "INVALID_ARGUMENTS", message: "Arguments were invalid", details: nil))
              return
          }
          let session = AVAudioSession.sharedInstance()
          do {
              if enable {
                  try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
                  try session.overrideOutputAudioPort(.speaker)
              } else {
                  try session.setCategory(.playAndRecord, options: [.allowBluetooth])
                  try session.overrideOutputAudioPort(.none)
              }
              try session.setActive(true)
              result(true)
          } catch {
              result(FlutterError(code: "AUDIO_ERROR", message: error.localizedDescription, details: nil))
          }
      } else {
          result(FlutterMethodNotImplemented)
      }
    })
  }
}


