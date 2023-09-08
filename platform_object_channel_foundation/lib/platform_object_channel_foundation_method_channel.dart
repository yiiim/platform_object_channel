import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MethodChannelPlatformObjectInstanceFoundation {
  @visibleForTesting
  final methodChannel = const MethodChannel('platform_object_channel_foundation');

  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
