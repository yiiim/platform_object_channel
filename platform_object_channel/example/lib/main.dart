import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:platform_object_channel/platform_object_channel.dart';

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

  @override
  void initState() {
    super.initState();
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
});
Future(() async {
  await for (var element in platformObjectInstance.invokeMethodStream("sayHi_10", "im flutter, 10")) {
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
