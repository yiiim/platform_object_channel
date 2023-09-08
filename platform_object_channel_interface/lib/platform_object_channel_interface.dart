import 'package:plugin_platform_interface/plugin_platform_interface.dart';

abstract class PlatformObjectRef {}

abstract class PlatformObjectMessenger {
  Future<dynamic> invokeMethod(String method, [dynamic arguments]);
  Stream invokeMethodStream(String method, [dynamic arguments]);
  void setPlatformObjectMethodCallHandler(Future Function(String method, dynamic arguments) handler);
  Future dispose();
  PlatformObjectRef get ref;
}

abstract class PlatformObjectChannelInterface extends PlatformInterface {
  PlatformObjectChannelInterface() : super(token: _token);
  static final Object _token = Object();

  static PlatformObjectChannelInterface? get instance => _instance;

  static set instance(PlatformObjectChannelInterface? instance) {
    if (instance == null) {
      throw AssertionError('Platform interfaces can only be set to a non-null instance');
    }
    _instance = instance;
  }

  static PlatformObjectChannelInterface? _instance;

  PlatformObjectMessenger createPlatformObjectChannel(String objectType, dynamic arguments);
}
