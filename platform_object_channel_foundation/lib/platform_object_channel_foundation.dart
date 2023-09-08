import 'dart:async';

import 'package:flutter/services.dart';
import 'package:platform_object_channel_interface/platform_object_channel_interface.dart';

class FoundationPlatformObjectMessenger extends PlatformObjectMessenger {
  FoundationPlatformObjectMessenger._(this._instanceManager, this._methodChannel, this._objectIdentifier, this._name, this.ref);

  final PlatformObjectChannelFoundation _instanceManager;
  final MethodChannel _methodChannel;
  final int _objectIdentifier;
  final String _name;
  final Map<String, int> _streamMethodNextIdentifier = {};
  final Map<String, Map<int, Completer>> _streamMethodCompleters = {};
  Future Function(String method, dynamic arguments)? _onPlatformObjectMethodCallHandler;

  @override
  void setPlatformObjectMethodCallHandler(Future Function(String method, dynamic arguments) handler) {
    _onPlatformObjectMethodCallHandler = handler;
  }

  @override
  Future<dynamic> invokeMethod(String method, [dynamic arguments]) {
    return _methodChannel.invokeMethod(
      "invokeMethod",
      <String, dynamic>{
        'objectIdentifier': _objectIdentifier,
        'objectType': _name,
        'arguments': arguments,
        'method': method,
      },
    );
  }

  @override
  Stream invokeMethodStream(String method, [dynamic arguments]) async* {
    _streamMethodCompleters[method] ??= {};
    var identifier = _nextUniqueIdentifier(method);
    var completer = Completer();
    _streamMethodCompleters[method]![identifier] = completer;
    _methodChannel.invokeMethod(
      "invokeMethod",
      <String, dynamic>{
        'objectIdentifier': _objectIdentifier,
        'streamMethodIdentifier': identifier,
        'objectType': _name,
        'arguments': arguments,
        'method': method,
      },
    );
    while (true) {
      var complete = _streamMethodCompleters[method]![identifier];
      if (complete != null) {
        yield await complete.future;
      } else {
        break;
      }
    }
  }

  Future _handlePlatformObjectInvokeMethod(String method, dynamic arguments) async {
    if (method == "stream") {
      String streamMethod = arguments['method'];
      if (arguments is Map && arguments['streamMethodIdentifier'] != null) {
        var identifier = arguments['streamMethodIdentifier'];
        var completer = _streamMethodCompleters[streamMethod]![identifier];
        if (completer != null) {
          var result = arguments['result'];
          if (result is Map) {
            _streamMethodCompleters[streamMethod]![identifier] = Completer();
            if (result['isStreamComplete'] == true) {
              _streamMethodCompleters[streamMethod]!.remove(identifier);
            } else if (result['isStreamError'] == true) {
              _streamMethodCompleters[streamMethod]!.remove(identifier);
              completer.completeError(result['data']);
            } else {
              completer.complete(result['data']);
            }
          }
        }
      }
    } else if (method == "invokeMethod") {
      return await _onPlatformObjectMethodCallHandler?.call(arguments['method'], arguments['arguments']);
    }
  }

  int _nextUniqueIdentifier(String method) {
    int identifier = _streamMethodNextIdentifier[method] ?? 0;
    _streamMethodNextIdentifier[method] = identifier + 1;
    return identifier;
  }

  @override
  Future dispose() async {
    await _instanceManager.disposePlatformObject(this);
  }

  @override
  final PlatformObjectRef ref;
}

class FoundationPlatformObjectRef extends PlatformObjectRef {
  FoundationPlatformObjectRef({required this.objectIdentifier, required this.objectType});
  final int objectIdentifier;
  final String objectType;
}

class PlatformObjectChannelFoundation extends PlatformObjectChannelInterface {
  static void registerWith() {
    PlatformObjectChannelInterface.instance = PlatformObjectChannelFoundation();
  }

  final Map<String, Map<int, FoundationPlatformObjectMessenger>> _objects = {};
  final Map<String, int> _objectNextIdentifier = {};
  late final _methodChannel = const MethodChannel('platform_object_channel_foundation', StandardMethodCodec(PlatformObjectChannelFoundationMessageCodec()))
    ..setMethodCallHandler(
      (MethodCall call) async {
        final objectIdentifier = call.arguments['objectIdentifier'];
        final type = call.arguments['objectType'];
        final arguments = call.arguments['arguments'];
        final object = _objects[type]?[objectIdentifier];
        if (object == null) {
          throw Exception('No object found for identifier: $objectIdentifier');
        }
        return object._handlePlatformObjectInvokeMethod(call.method, arguments);
      },
    );

  @override
  PlatformObjectMessenger createPlatformObjectChannel(String objectType, dynamic arguments) {
    var identifier = _nextUniqueIdentifier(objectType);
    _methodChannel.invokeMethod(
      "createObject",
      {
        "objectType": objectType,
        "objectIdentifier": identifier,
        "arguments": arguments,
      },
    ).then(
      (value) {
        if (value != 0) {
          throw Exception('Failed to create platform object.\n$value');
        }
      },
    );
    var platformObject = FoundationPlatformObjectMessenger._(
      this,
      _methodChannel,
      identifier,
      objectType,
      FoundationPlatformObjectRef(objectIdentifier: identifier, objectType: objectType),
    );
    _objects[objectType] ??= {};
    _objects[objectType]![identifier] = platformObject;
    return platformObject;
  }

  Future disposePlatformObject(PlatformObjectMessenger object) async {
    if (object is! FoundationPlatformObjectMessenger) {
      throw Exception('Invalid platform object');
    }
    await _methodChannel.invokeMethod(
      "disposeObject",
      {
        "objectType": object._name.toString(),
        "objectIdentifier": object._objectIdentifier,
      },
    );
    _objects[object._name]!.remove(object._objectIdentifier);
  }

  int _nextUniqueIdentifier(String name) {
    int identifier = _objectNextIdentifier[name] ?? 0;
    _objectNextIdentifier[name] = identifier + 1;
    return identifier;
  }
}

class PlatformObjectChannelFoundationMessageCodec extends StandardMessageCodec {
  static const int _valuePlatformObjectRef = 128;
  const PlatformObjectChannelFoundationMessageCodec();
  @override
  void writeValue(WriteBuffer buffer, Object? value) {
    if (value is FoundationPlatformObjectRef) {
      buffer.putUint8(_valuePlatformObjectRef);
      writeValue(buffer, value.objectIdentifier);
      writeValue(buffer, value.objectType);
    } else {
      super.writeValue(buffer, value);
    }
  }
}
