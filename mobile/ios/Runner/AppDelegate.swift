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
                  try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
                  try session.setActive(true)
                  try session.overrideOutputAudioPort(.speaker)
              } else {
                  try session.setCategory(.playAndRecord, options: [.allowBluetooth, .allowBluetoothA2DP])
                  try session.setActive(true)
                  try session.overrideOutputAudioPort(.none)
              }
              result(true)
          } catch {
              result(FlutterError(code: "AUDIO_ERROR", message: error.localizedDescription, details: nil))
          }

      } else if call.method == "setAudioOutput" {
          // port: "speaker" | "earpiece" | "bluetooth"
          guard let args = call.arguments as? [String: Any],
                let port = args["port"] as? String else {
              result(FlutterError(code: "INVALID_ARGUMENTS", message: "port required", details: nil))
              return
          }
          let session = AVAudioSession.sharedInstance()
          do {
              switch port {
              case "speaker":
                  try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
                  try session.setActive(true)
                  try session.overrideOutputAudioPort(.speaker)
              case "bluetooth":
                  try session.setCategory(.playAndRecord, options: [.allowBluetooth, .allowBluetoothA2DP])
                  try session.setActive(true)
                  try session.overrideOutputAudioPort(.none)
                  // Prefer Bluetooth HFP input if available (iOS routes output to BT automatically)
                  if let btInput = session.availableInputs?.first(where: {
                      $0.portType == .bluetoothHFP || $0.portType == .bluetoothA2DP
                  }) {
                      try session.setPreferredInput(btInput)
                  }
              default: // earpiece
                  try session.setCategory(.playAndRecord, options: [.allowBluetooth, .allowBluetoothA2DP])
                  try session.setActive(true)
                  try session.overrideOutputAudioPort(.none)
              }
              result(true)
          } catch {
              result(FlutterError(code: "AUDIO_ERROR", message: error.localizedDescription, details: nil))
          }

      } else if call.method == "listAudioOutputs" {
          let session = AVAudioSession.sharedInstance()
          var outputs: [[String: String]] = []
          // Always include earpiece and speaker
          outputs.append(["id": "earpiece", "name": "ស្មាហ្វូន", "type": "earpiece"])
          outputs.append(["id": "speaker",  "name": "លំโพ",     "type": "speaker"])
          // Detect Bluetooth from current route outputs
          let currentRoute = session.currentRoute
          for output in currentRoute.outputs {
              if output.portType == .bluetoothHFP || output.portType == .bluetoothA2DP || output.portType == .bluetoothLE {
                  outputs.append(["id": "bluetooth_\(output.uid)", "name": output.portName, "type": "bluetooth"])
              }
          }
          // Also scan available inputs for BT HFP (appear as inputs on iOS for voice calls)
          if let inputs = session.availableInputs {
              for input in inputs {
                  if input.portType == .bluetoothHFP {
                      let alreadyListed = outputs.contains(where: { $0["type"] == "bluetooth" })
                      if !alreadyListed {
                          outputs.append(["id": "bluetooth_\(input.uid)", "name": input.portName, "type": "bluetooth"])
                      }
                  }
              }
          }
          result(outputs)

      } else {
          result(FlutterMethodNotImplemented)
      }
    })
  }
}


