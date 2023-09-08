import 'package:platform_object_channel_interface/platform_object_channel_interface.dart';

class PlatformObjectChannel {
  PlatformObjectChannel._fromPlatformObjectChannel(this.platformObjectMessenger);
  final PlatformObjectMessenger platformObjectMessenger;

  factory PlatformObjectChannel(String objectType, [dynamic arguments]) {
    if (PlatformObjectChannelInterface.instance == null) {
      throw "Unsupported platform.";
    }
    return PlatformObjectChannel._fromPlatformObjectChannel(PlatformObjectChannelInterface.instance!.createPlatformObjectChannel(objectType, arguments));
  }

  Future dispose() => platformObjectMessenger.dispose();
  Future invokeMethod(String method, [arguments]) => platformObjectMessenger.invokeMethod(method, arguments);
  Stream invokeMethodStream(String method, [arguments]) => platformObjectMessenger.invokeMethodStream(method, arguments);
  void setPlatformObjectMethodCallHandler(Future Function(String method, dynamic arguments) handler) => platformObjectMessenger.setPlatformObjectMethodCallHandler(handler);
  PlatformObjectRef get ref => platformObjectMessenger.ref;
}
