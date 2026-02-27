import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private let targetContentSize = NSSize(width: 500, height: 1020)

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.setContentSize(targetContentSize)
    self.contentMinSize = targetContentSize
    self.contentAspectRatio = targetContentSize
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
