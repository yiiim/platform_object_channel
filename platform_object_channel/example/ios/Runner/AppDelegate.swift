import UIKit
import Flutter
import platform_object_channel_foundation

@objc(TestObject)
class TestObject : NSObject, FoundationPlatformObject{
    required init(_ flutterArgs: Any?, _ messager: FoundationPlatformObjectMessenger) {
        self.messager = messager
    }
    let messager: FoundationPlatformObjectMessenger
    func handleFlutterMethodCall(_ method: String, _ arguments: Any?) async -> Any? {
        Task {
            var result = await messager.invokeMethod("sayHi")
            print("flutter return \(result ?? "")")
        }
        return "Hi"
    }
    
    func handleFlutterStreamMethodCall(_ method: String, _ arguments: Any?, _ sink: platform_object_channel_foundation.FoundationPlatformStreamMethodSink) {
        var count = 10
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            count -= 1
            if count <= 0 {
                timer.invalidate()
                sink.done()
            }else {
                sink.add("Hi \(count)")
            }
        }
    }
    
    func dispose() {
        
    }
    
}

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
