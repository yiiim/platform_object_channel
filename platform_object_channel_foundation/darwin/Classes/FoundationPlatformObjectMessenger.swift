//
//  FoundationPlatformObjectMessenger.swift
//  platform_object_channel_foundation
//
//  Created by ybz on 2023/9/7.
//

import Foundation


public class FoundationPlatformObjectMessenger {
    init(_ delegate: @escaping (String, Any?) async -> Any?) {
        self.delegate = delegate
    }
    let delegate : (String, Any?) async -> Any?
    
    public func invokeMethod(_ mehtod:String) async -> Any? {
        return await self.invokeMethod(mehtod, nil)
    }
    
    public func invokeMethod(_ mehtod:String, _ arguments: Any?) async -> Any? {
        return await self.delegate(mehtod, arguments)
    }
}
