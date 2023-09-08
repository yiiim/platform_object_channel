#if os(iOS)
  import Flutter
#elseif os(macOS)
  import FlutterMacOS
#else
  #error("Unsupported platform.")
#endif

enum PlatformObjectChannelFoundationError : Error{
    case codecReaderFail
}
class PlatformObjectChannelFoundationCodecReaderWriter : FlutterStandardReaderWriter {
    init(_ instanceManager : PlatformObjectChannelInstanceManager) {
        self.instanceManager = instanceManager
        super.init()
    }
    let instanceManager : PlatformObjectChannelInstanceManager
    override func reader(with data: Data) -> FlutterStandardReader {
        return PlatformObjectChannelFoundationCodecReader(self.instanceManager, data)
    }
}
class PlatformObjectChannelFoundationCodecReader : FlutterStandardReader{
    init(_ objectInstance : PlatformObjectChannelInstanceManager,_ data : Data) {
        self.objectInstance = objectInstance
        super.init(data: data)
    }
    let objectInstance : PlatformObjectChannelInstanceManager
    override func readValue(ofType type: UInt8) -> Any? {
        if type == 128 {
            guard let identifier = readValue(ofType: readByte()) as? Int else {
                return nil
            }
            guard let objectType = readValue(ofType: readByte()) as? String else {
                return nil
            }
            return self.objectInstance.findInstance(identifier, objectType)
        }
        return super.readValue(ofType: type)
    }
}

class PlatformObjectChannelInstanceManager {
    fileprivate var objects : [String:[Int:FoundationPlatformObject]] = [:]
    fileprivate var identifiers : [ObjectIdentifier:(Int,String)] = [:]
    func findInstance(_ identifier : Int, _ objectType : String) -> FoundationPlatformObject? {
        return self.objects[objectType]?[identifier]
    }
    func findIdentifierAndType(_ object: FoundationPlatformObject) -> (Int, String)? {
        return self.identifiers[ObjectIdentifier(object)]
    }
    func addInstance(_ identifier : Int, _ objectType : String, _ object: FoundationPlatformObject) {
        if self.objects[objectType] == nil {
            self.objects[objectType] = [:]
        }
        identifiers[ObjectIdentifier(object)] = (identifier,objectType)
        self.objects[objectType]![identifier] = object
    }
    func disposeInstance(_ identifier : Int, _ objectType : String, _ object: FoundationPlatformObject) {
        object.dispose()
        self.objects[objectType]?.removeValue(forKey: identifier)
    }
}

public class PlatformObjectChannelFoundationPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instanceManager = PlatformObjectChannelInstanceManager()
#if os(iOS)
    let messenger = registrar.messenger()
#else
    let messenger = registrar.messenger
#endif
        let channel = FlutterMethodChannel(name: "platform_object_channel_foundation", binaryMessenger: messenger,codec: FlutterStandardMethodCodec(readerWriter: PlatformObjectChannelFoundationCodecReaderWriter(instanceManager)))
        pluginInstance = PlatformObjectChannelFoundationPlugin(channel, instanceManager)
        registrar.addMethodCallDelegate(pluginInstance!, channel: channel)
    }
    init(_ channel: FlutterMethodChannel,_ instanceManager : PlatformObjectChannelInstanceManager) {
        self.channel = channel
        self.instanceManager = instanceManager
    }
    static var pluginInstance : PlatformObjectChannelFoundationPlugin?
    
    fileprivate let instanceManager : PlatformObjectChannelInstanceManager
    fileprivate let channel : FlutterMethodChannel
    
    class handleResultCode {
        static let success = 0
        static let callArgsError = "arguments error, please report a bug to me: "
        static let objectNotFound = "object not found"
        static let createObjectInitFail = "init method fail"
        static let objectInstanceNotFound = "instance not found"
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String:Any] else {
            result(handleResultCode.callArgsError)
            return
        }
        guard let objectIdentifier = args["objectIdentifier"] as? Int else {
            result(handleResultCode.callArgsError)
            return
        }
        guard let objectType =  args["objectType"] as? String else {
            result(handleResultCode.callArgsError)
            return
        }
        if call.method == "createObject" {
            guard let className = NSClassFromString(objectType) as? FoundationPlatformObject.Type else{
                result(handleResultCode.objectNotFound)
                return
            }
            do {
                let messager = FoundationPlatformObjectMessenger.init { method, methodArgs in
                    return await withUnsafeContinuation { continuation in
                        self.channel.invokeMethod(
                            "invokeMethod",
                            arguments: [
                                "arguments": [
                                    "method": method,
                                    "arguments": methodArgs
                                ],
                                "objectType": objectType,
                                "objectIdentifier": objectIdentifier
                            ] as [String : Any],
                            result: { methodResult  in
                                continuation.resume(returning: methodResult)
                            }
                        )
                    }
                }
                let instance = try className.init(args["arguments"], messager)
                self.instanceManager.addInstance(objectIdentifier, objectType, instance)
                result(handleResultCode.success)
            } catch {
                result("\(handleResultCode.createObjectInitFail)\n\(error)")
            }
        } else {
            guard let instance = self.instanceManager.findInstance(objectIdentifier, objectType) else {
                result(handleResultCode.objectInstanceNotFound)
                return
            }
            if call.method == "invokeMethod" {
                guard let method = args["method"] as? String else {
                    result(handleResultCode.callArgsError)
                    return
                }
                if let streamMethodIdentifier = args["streamMethodIdentifier"] as? Int {
                    instance.handleFlutterStreamMethodCall(
                        method,
                        args["arguments"],
                        FoundationPlatformStreamMethodSink(
                            channel: channel,
                            objectIdentifier: objectIdentifier,
                            objectType: objectType,
                            streamMethodIdentifier: streamMethodIdentifier,
                            method: method
                        )
                    )
                    result(handleResultCode.success)
                } else {
                    Task {
                        let handleResult = await instance.handleFlutterMethodCall(method, args["arguments"])
                        OperationQueue.main.addOperation {
                            result(handleResult)
                        }
                    }
                }
            } else if call.method == "dispose"{
                self.instanceManager.disposeInstance(objectIdentifier, objectType, instance)
                result(handleResultCode.success)
            }
        }
    }
}

