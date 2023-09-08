//
//  FoundationPlatformObject.swift
//  platform_object_channel_foundation
//
//  Created by ybz on 2023/9/3.
//

public protocol FoundationPlatformObject: NSObject {
    init(_ flutterArgs: Any?, _ messager: FoundationPlatformObjectMessenger) throws;
    func handleFlutterMethodCall(_ method: String, _ arguments: Any?) async -> Any?;
    func handleFlutterStreamMethodCall(_ method: String, _ arguments: Any?, _ sink: FoundationPlatformStreamMethodSink);
    func dispose();
}
