import Cocoa
import FlutterMacOS
import window_manager
import LaunchAtLogin
import desktop_multi_window

class MainFlutterWindow: NSWindow {
    override func awakeFromNib() {
        let flutterViewController = FlutterViewController()
        let windowFrame = self.frame
        self.contentViewController = flutterViewController
        self.setFrame(windowFrame, display: true)
        
        FlutterMethodChannel(
            name: "launch_at_startup", binaryMessenger: flutterViewController.engine.binaryMessenger
        )
        .setMethodCallHandler { (_ call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "launchAtStartupIsEnabled":
                result(LaunchAtLogin.isEnabled)
            case "launchAtStartupSetEnabled":
                if let arguments = call.arguments as? [String: Any] {
                    LaunchAtLogin.isEnabled = (arguments["setEnabledValue"] as? Bool) ?? false
                }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        RegisterGeneratedPlugins(registry: flutterViewController)

        // Register plugins for each desktop_multi_window sub-window (the macOS
        // config editor) so its engine has the multi-window channel. Its Dart
        // only uses that channel; the rest register but stay dormant unless
        // called, so no duplicate tray/window side effects.
        FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
            RegisterGeneratedPlugins(registry: controller)
        }

        super.awakeFromNib()
    }
    override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
        super.order(place, relativeTo: otherWin)
        hiddenWindowAtLaunch()
    }
}
