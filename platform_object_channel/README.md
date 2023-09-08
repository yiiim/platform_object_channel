# platform_object_channel

[![pub package](https://img.shields.io/pub/v/platform_object_channel.svg)](https://pub.dev/packages/platform_object_channel)

A Flutter plugin for create channel for platform object instance and dart object instance

|             | Android | iOS   | macOS    |
|-------------|---------|-------|----------|
| **Support** | SDK 19+ | 13.0+ | 10.15+   |

## Usage

To use this plugin, add `platform_object_channel` as a [dependency in your pubspec.yaml file](https://flutter.dev/platform-plugins/).

## Example

for dart:

```dart
final platformObjectInstance = PlatformObjectChannel(Platform.isAndroid ? "com.example.example.TestObject" : "TestObject", "arguments");
platformObjectInstance.setPlatformObjectMethodCallHandler(
  (method, arguments) async {
    if (method == "sayHi") {
      return "reply from flutter";
    }
  },
);
Future(() async {
  _methodResult = await platformObjectInstance.invokeMethod("sayHi", "im flutter");
  setState(() {});
});
Future(() async {
  await for (var element in platformObjectInstance.invokeMethodStream("sayHi_10", "im flutter, 10")) {
    setState(() {
      _streamMethodResult = element;
    });
  }
});
```

for iOS and macOS:

```swift
@objc(TestObject)
class TestObject : NSObject, FoundationPlatformObject{
    required init(_ flutterArgs: Any?, _ messager: FoundationPlatformObjectMessenger) {
        self.messager = messager
    }
    let messager: FoundationPlatformObjectMessenger
    func handleFlutterMethodCall(_ method: String, _ arguments: Any?) async -> Any? {
        Task {
            var result = await messager.invokeMethod("sayHi", "hi")
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
```

for Android:

```kotlin
class  TestObject() : AndroidPlatformObject {
    private lateinit var messager: AndroidPlatformObjectMessenger
    override fun setUp(flutterArgs: Any?, messager: AndroidPlatformObjectMessenger) {
        this.messager = messager
    }

    override suspend fun handleFlutterMethodCall(method: String, arguments: Any?): Any? {
        GlobalScope.launch(Dispatchers.Default) {
            var result = messager.invokeMethod("sayHi", "hi")
            print("flutter return $result")
        }
        return "Hi"
    }

    override fun handleFlutterStreamMethodCall(
        method: String,
        arguments: Any?,
        sink: AndroidPlatformStreamMethodSink
    ) {
        var count = 0
        GlobalScope.launch {
            while (true) {
                count++
                if(count > 10){
                    sink.done()
                }else{
                    sink.add(count)
                }
                delay(1000)
            }
        }
    }

    override fun dispose() {
    }
}
```