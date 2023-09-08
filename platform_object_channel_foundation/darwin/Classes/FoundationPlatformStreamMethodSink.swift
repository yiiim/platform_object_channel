//
//  FoundationPlatformStreamMethodSink.swift
//  platform_object_channel_foundation
//
//  Created by ybz on 2023/9/3.
//

import Foundation
#if os(iOS)
  import Flutter
#elseif os(macOS)
  import FlutterMacOS
#else
  #error("Unsupported platform.")
#endif

public struct FoundationPlatformStreamMethodSink {
    let channel : FlutterMethodChannel
    let objectIdentifier : Int
    let objectType : String
    let streamMethodIdentifier : Int
    let method : String
    
    public func add(_ event: Any){
        OperationQueue.main.addOperation {
            channel.invokeMethod("stream", arguments: [
                "objectIdentifier" : objectIdentifier,
                "objectType": objectType,
                "arguments": [
                    "method": method,
                    "streamMethodIdentifier": streamMethodIdentifier,
                    "result": [
                        "data": event
                    ]
                ] as [String : Any]
            ] as [String : Any])
        }
    }
    public func done() {
        OperationQueue.main.addOperation {
            channel.invokeMethod("stream", arguments: [
                "objectIdentifier" : objectIdentifier,
                "objectType": objectType,
                "arguments": [
                    "method": method,
                    "streamMethodIdentifier": streamMethodIdentifier,
                    "result": [
                        "isStreamComplete": true,
                    ]
                ] as [String : Any]
            ] as [String : Any])
        }
    }
    public func error(_ error: Any?){
        OperationQueue.main.addOperation {
            channel.invokeMethod("stream", arguments: [
                "objectIdentifier" : objectIdentifier,
                "objectType": objectType,
                "arguments": [
                    "method": method,
                    "streamMethodIdentifier": streamMethodIdentifier,
                    "result": [
                        "isStreamError": true,
                        "error": error
                    ]
                ] as [String : Any]
            ] as [String : Any])
        }
    }
}
