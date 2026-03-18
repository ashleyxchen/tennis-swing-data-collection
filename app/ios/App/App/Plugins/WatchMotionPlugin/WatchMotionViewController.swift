import UIKit
import Capacitor

class WatchMotionViewController: CAPBridgeViewController {
    override func capacitorDidLoad() {
        bridge?.registerPluginInstance(WatchMotionPlugin())
    }
}
