import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MethodChannelPlatformObjectChannelAndroid {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('platform_object_channel_android');

  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
