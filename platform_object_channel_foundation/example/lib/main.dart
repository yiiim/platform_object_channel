import 'package:flutter/material.dart';
import 'dart:async';
import 'package:platform_object_channel_foundation/platform_object_channel_foundation.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  dynamic _methodResult = 'Unknown';
  dynamic _streamMethodResult = 'Unknown';
  final _platformObjectInstanceFoundationPlugin = PlatformObjectChannelFoundation();

  @override
  void initState() {
    super.initState();
    var object = _platformObjectInstanceFoundationPlugin.createPlatformObjectChannel("TestObject", "TestObject");
    object.setPlatformObjectMethodCallHandler(
      (method, arguments) async {
        print("from platform: $method $arguments");
        return "im flutter";
      },
    );
    Future(() async {
      _methodResult = await object.invokeMethod("method");
    });
    Future(() async {
      await for (var element in object.invokeMethodStream("method")) {
        setState(() {
          _streamMethodResult = element;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Column(
          children: [
            Text("method result: $_methodResult"),
            Text("stream method result: $_streamMethodResult"),
          ],
        ),
      ),
    );
  }
}
