import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "ticketoff/guest_documents",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "save" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.shareGuestDocument(call.arguments, result: result)
    }
  }

  private func shareGuestDocument(_ arguments: Any?, result: @escaping FlutterResult) {
    let root = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }?.rootViewController
    guard
      let presenter = root,
      let data = arguments as? [String: Any],
      let name = data["name"] as? String,
      name == (name as NSString).lastPathComponent,
      !name.isEmpty, name != ".", name != "..",
      let bytes = data["bytes"] as? FlutterStandardTypedData,
      !bytes.data.isEmpty, bytes.data.count <= 8 * 1024 * 1024
    else {
      result(FlutterError(code: "invalid_file", message: "Unable to share download", details: nil))
      return
    }
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let file = directory.appendingPathComponent(name)
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try bytes.data.write(to: file, options: .atomic)
    } catch {
      try? FileManager.default.removeItem(at: directory)
      result(FlutterError(code: "write_failed", message: "Unable to save download", details: nil))
      return
    }
    let share = UIActivityViewController(activityItems: [file], applicationActivities: nil)
    share.popoverPresentationController?.sourceView = presenter.view
    share.popoverPresentationController?.sourceRect = CGRect(
      x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1
    )
    share.completionWithItemsHandler = { _, _, _, _ in
      try? FileManager.default.removeItem(at: directory)
      result(nil)
    }
    presenter.present(share, animated: true)
  }
}
