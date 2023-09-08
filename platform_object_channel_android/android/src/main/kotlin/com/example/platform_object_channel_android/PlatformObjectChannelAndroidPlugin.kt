package com.example.platform_object_channel_android

import android.os.Parcel
import android.os.Parcelable
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.common.StandardMethodCodec
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.nio.ByteBuffer
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlin.coroutines.suspendCoroutine

class PlatformObjectChannelException(message: String) : Exception(message)

class AndroidPlatformObjectMessengerResult (
    private val successCallback: (result: Any?) -> Unit,
    private val errorCallback: (errorCode: String, errorMessage: String?, errorDetails: Any?) -> Unit,
    private val notImplementedCallback: () -> Unit
) : Result {
    override fun success(result: Any?) {
        successCallback.invoke(result)
    }

    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
        errorCallback.invoke(errorCode, errorMessage, errorDetails)
    }

    override fun notImplemented() {
        notImplementedCallback.invoke()
    }
}

class AndroidPlatformObjectMessenger(private val delegate: (String, Any?, Result) -> Unit) {
    suspend fun invokeMethod(method: String, arguments: Any?): Any? {
        return suspendCoroutine { continuation ->
            delegate.invoke(method, arguments, AndroidPlatformObjectMessengerResult(
                { result ->
                    continuation.resume(result)
                },
                { _, errorMessage, _ ->
                    continuation.resumeWithException(PlatformObjectChannelException(errorMessage ?: ""))
                },
                {
                    continuation.resumeWithException(PlatformObjectChannelException("not implemented"))
                }
            ))
        }
    }
}

class AndroidPlatformStreamMethodSink(
    private val channel: MethodChannel,
    private val objectIdentifier: Int,
    private val objectType: String,
    private val streamMethodIdentifier: Int,
    private val method: String
) {
    fun add(event: Any) {
        MainScope().launch {
            withContext(Dispatchers.Main) {
                channel.invokeMethod(
                    "stream", mapOf(
                        "objectIdentifier" to objectIdentifier,
                        "objectType" to objectType,
                        "arguments" to mapOf(
                            "method" to method,
                            "streamMethodIdentifier" to streamMethodIdentifier,
                            "result" to mapOf(
                                "data" to event
                            )
                        )
                    )
                )
            }
        }
    }

    fun done() {
        MainScope().launch {
            withContext(Dispatchers.Main) {
                channel.invokeMethod(
                    "stream", mapOf(
                        "objectIdentifier" to objectIdentifier,
                        "objectType" to objectType,
                        "arguments" to mapOf(
                            "method" to method,
                            "streamMethodIdentifier" to streamMethodIdentifier,
                            "result" to mapOf(
                                "isStreamComplete" to true
                            )
                        )
                    )
                )
            }
        }
    }

    fun error(error: Any?) {
        MainScope().launch {
            withContext(Dispatchers.Main) {
                channel.invokeMethod(
                    "stream", mapOf(
                        "objectIdentifier" to objectIdentifier,
                        "objectType" to objectType,
                        "arguments" to mapOf(
                            "method" to method,
                            "streamMethodIdentifier" to streamMethodIdentifier,
                            "result" to mapOf(
                                "isStreamError" to true,
                                "error" to error
                            )
                        )
                    )
                )
            }
        }
    }
}

interface AndroidPlatformObject : Parcelable {
    fun setUp(flutterArgs: Any?, messager: AndroidPlatformObjectMessenger)
    suspend fun handleFlutterMethodCall(method: String, arguments: Any?): Any?
    fun handleFlutterStreamMethodCall(
        method: String,
        arguments: Any?,
        sink: AndroidPlatformStreamMethodSink
    )

    fun dispose()
}


class PlatformObjectChannelMessageCodec(private val instanceManager: PlatformObjectChannelInstanceManager) :
    StandardMessageCodec(), Parcelable {
    constructor(parcel: Parcel) : this(
        parcel.readParcelable<PlatformObjectChannelInstanceManager>(
            PlatformObjectChannelInstanceManager::class.java.classLoader
        )!!
    )

    override fun writeToParcel(parcel: Parcel, flags: Int) {
        parcel.writeParcelable(instanceManager, flags)
    }

    override fun describeContents(): Int {
        return 0
    }

    companion object CREATOR : Parcelable.Creator<PlatformObjectChannelMessageCodec> {
        override fun createFromParcel(parcel: Parcel): PlatformObjectChannelMessageCodec {
            return PlatformObjectChannelMessageCodec(parcel)
        }

        override fun newArray(size: Int): Array<PlatformObjectChannelMessageCodec?> {
            return arrayOfNulls(size)
        }
    }

    private val objectRef: Byte = 128.toByte()
    override fun readValueOfType(type: Byte, buffer: ByteBuffer): Any? {
        if (type == objectRef) {
            val identifier = readValue(buffer)
            if (identifier !is Int) PlatformObjectChannelException("decode message fail")
            val objectType = readValue(buffer)
            if (objectType !is String) PlatformObjectChannelException("decode message fail")
            return instanceManager.findInstance(identifier as Int, objectType as String)
        }
        return super.readValueOfType(type, buffer)
    }
}

class PlatformObjectChannelInstanceManager() : Parcelable {
    private val objects = mutableMapOf<String, MutableMap<Int, AndroidPlatformObject>>()
    private val identifiers = mutableMapOf<Int, Pair<Int, String>>()

    fun findInstance(identifier: Int, objectType: String): AndroidPlatformObject? {
        val objectMap = objects[objectType] ?: return null
        return objectMap[identifier]
    }

    fun findIdentifierAndType(obj: AndroidPlatformObject): Pair<Int, String>? {
        return identifiers[obj.hashCode()]
    }

    fun addInstance(identifier: Int, objectType: String, obj: AndroidPlatformObject) {
        if (!objects.containsKey(objectType)) {
            objects[objectType] = mutableMapOf<Int, AndroidPlatformObject>()
        }
        objects[objectType]!![identifier] = obj
        identifiers[obj.hashCode()] = Pair(identifier, objectType)
    }

    fun disposeInstance(identifier: Int, objectType: String, obj: AndroidPlatformObject) {
        val objectMap = objects[objectType] ?: return
        objectMap.remove(identifier)
        identifiers.remove(obj.hashCode())
    }

    constructor(parcel: Parcel) : this() {
        val objectsSize = parcel.readInt()
        for (i in 0.until(objectsSize)) {
            val objectType = parcel.readString() ?: ""
            val objectMapSize = parcel.readInt()
            val objectMap = mutableMapOf<Int, AndroidPlatformObject>()
            for (j in 0.until(objectMapSize)) {
                val identifier = parcel.readInt()
                val obj =
                    parcel.readParcelable<AndroidPlatformObject>(AndroidPlatformObject::class.java.classLoader)
                if (obj != null) {
                    objectMap[identifier] = obj
                    identifiers[obj.hashCode()] = Pair(identifier, objectType)
                }
            }
            objects[objectType] = objectMap
        }
    }

    override fun writeToParcel(parcel: Parcel, flags: Int) {
        parcel.writeInt(objects.size)
        for ((objectType, objectMap) in objects) {
            parcel.writeString(objectType)
            parcel.writeInt(objectMap.size)
            for ((identifier, obj) in objectMap) {
                parcel.writeInt(identifier)
                parcel.writeParcelable(obj, flags)
            }
        }
    }

    override fun describeContents(): Int {
        return 0
    }

    companion object CREATOR : Parcelable.Creator<PlatformObjectChannelInstanceManager> {
        override fun createFromParcel(parcel: Parcel): PlatformObjectChannelInstanceManager {
            return PlatformObjectChannelInstanceManager(parcel)
        }

        override fun newArray(size: Int): Array<PlatformObjectChannelInstanceManager?> {
            return arrayOfNulls(size)
        }
    }
}

class PlatformObjectChannelAndroidPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var instanceManager: PlatformObjectChannelInstanceManager

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        instanceManager = PlatformObjectChannelInstanceManager()
        channel =
            MethodChannel(flutterPluginBinding.binaryMessenger, "platform_object_channel_android",StandardMethodCodec(PlatformObjectChannelMessageCodec(instanceManager)))
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<*, *>
        if (args == null) {
            result.error(
                "arguments error",
                "arguments error",
                null
            )
            return
        }

        val objectIdentifier = args["objectIdentifier"] as? Int
        val objectType = args["objectType"] as? String

        if (objectIdentifier == null || objectType == null) {
            result.error(
                "arguments error",
                "arguments error",
                null
            )
            return
        }

        when (call.method) {
            "createObject" -> {
                val clazz = Class.forName(objectType)
                if (AndroidPlatformObject::class.java.isAssignableFrom(clazz)) {
                    val instance: AndroidPlatformObject = clazz.newInstance() as AndroidPlatformObject

                    val instanceMessager =
                        AndroidPlatformObjectMessenger { method, methodArgs, methodResult ->
                            MainScope().launch {
                                withContext(Dispatchers.Main) {
                                    channel.invokeMethod(
                                        /* method = */ "invokeMethod",
                                        /* arguments = */ mapOf(
                                            "arguments" to mapOf(
                                                "method" to method,
                                                "arguments" to methodArgs
                                            ),
                                            "objectType" to objectType,
                                            "objectIdentifier" to objectIdentifier
                                        ),
                                        /* callback = */ methodResult
                                    )
                                }
                            }
                        }
                    instance.setUp(args["arguments"], instanceMessager)
                    this.instanceManager.addInstance(objectIdentifier, objectType, instance)
                    result.success(0)
                } else {
                    result.error(
                        "object not found",
                        "object not found",
                        null
                    )
                    return
                }
            }

            "invokeMethod" -> {
                val instance = this.instanceManager.findInstance(objectIdentifier, objectType)
                if (instance == null) {
                    result.error(
                        "instance not found",
                        "instance not found",
                        null
                    )
                    return
                }

                val method = args["method"] as? String
                if (method == null) {
                    result.error(
                        "arguments error",
                        "arguments error",
                        null
                    )
                    return
                }

                if (args.containsKey("streamMethodIdentifier")) {
                    val streamMethodIdentifier = args["streamMethodIdentifier"] as? Int
                    if (streamMethodIdentifier != null) {
                        instance.handleFlutterStreamMethodCall(
                            method,
                            args["arguments"],
                            AndroidPlatformStreamMethodSink(
                                channel,
                                objectIdentifier,
                                objectType,
                                streamMethodIdentifier,
                                method
                            )
                        )
                        result.success(0)
                    } else {
                        result.error(
                            "arguments error",
                            "arguments error",
                            null
                        )
                    }
                } else {
                    GlobalScope.launch(Dispatchers.Default) {
                        var handleResult = instance.handleFlutterMethodCall(
                            method,
                            args["arguments"]
                        )
                        result.success(handleResult)
                    }
                }
            }

            "dispose" -> {
                val instance = instanceManager.findInstance(objectIdentifier, objectType)
                if (instance != null) {
                    instanceManager.disposeInstance(objectIdentifier, objectType, instance)
                }
                result.success(0)
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
