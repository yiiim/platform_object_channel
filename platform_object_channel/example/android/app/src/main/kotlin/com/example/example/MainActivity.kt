package com.example.example

import android.os.Parcel
import android.os.Parcelable
import com.example.platform_object_channel_android.AndroidPlatformObject
import com.example.platform_object_channel_android.AndroidPlatformObjectMessenger
import com.example.platform_object_channel_android.AndroidPlatformStreamMethodSink
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

class  TestObject() : AndroidPlatformObject {
    constructor(parcel: Parcel) : this() {
    }
    override fun writeToParcel(parcel: Parcel, flags: Int) {
    }
    private lateinit var messager: AndroidPlatformObjectMessenger
    override fun setUp(flutterArgs: Any?, messager: AndroidPlatformObjectMessenger) {
        this.messager = messager
    }

    override suspend fun handleFlutterMethodCall(method: String, arguments: Any?): Any? {
        GlobalScope.launch(Dispatchers.Default) {
            var result = messager.invokeMethod("abc", mapOf("a" to "b"))
            print("flutter return $result")
        }
        return "1"
    }

    override fun handleFlutterStreamMethodCall(
        method: String,
        arguments: Any?,
        sink: AndroidPlatformStreamMethodSink
    ) {
        var count = 0
        // 启动一个协程
        GlobalScope.launch {
            while (true) {
                count++
                if(count > 10){
                    sink.done()
                }else{
                    sink.add(count)
                }
                // 延迟一秒
                delay(1000)
            }
        }
    }

    override fun dispose() {
    }

    override fun describeContents(): Int {
        return 0
    }
    companion object CREATOR : Parcelable.Creator<TestObject> {
        override fun createFromParcel(parcel: Parcel): TestObject {
            return TestObject(parcel)
        }

        override fun newArray(size: Int): Array<TestObject?> {
            return arrayOfNulls(size)
        }
    }
}

class MainActivity: FlutterActivity() {
}
