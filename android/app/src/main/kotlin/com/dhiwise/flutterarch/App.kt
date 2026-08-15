package com.helpcare.app

import android.app.Application
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ApplicationInfo
import android.os.Build
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * 상주(cached) FlutterEngine.
 * 프로세스가 살아있는 한 엔진(=Dart isolate, BLE 포함)을 유지한다.
 * Activity가 파괴/재생성돼도 MainActivity가 이 캐시 엔진에 재부착 →
 * main() 재실행/스플래시 재등장 없이 BLE 수신·로컬저장이 그대로 유지된다.
 *
 * 또한 OS의 화면 ON/OFF 브로드캐스트를 앱 스코프로 수신해 Dart에 즉시 통지한다.
 * (Flutter 생명주기는 캐시 엔진에서 전달이 지연/불안정 → 화면 OFF 시 서버 폴링을
 *  결정적으로 멈추기 위해 네이티브 브로드캐스트를 사용한다.)
 */
class App : Application() {
    private var screenChannel: MethodChannel? = null
    private var qaChannel: MethodChannel? = null

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> screenChannel?.invokeMethod("screenOff", null)
                Intent.ACTION_SCREEN_ON -> screenChannel?.invokeMethod("screenOn", null)
            }
        }
    }

    /**
     * QA 원격 명령 수신기 (**디버그 빌드 전용**).
     *
     *   adb shell am broadcast -a com.helpcare.app.QA --es cmd <명령> [--es args '<JSON>']
     *
     * 결과는 Dart 에서 문자열로 돌아오며 logcat 태그 `CGMS_QA` 로 찍는다.
     *   adb logcat -s CGMS_QA
     */
    private val qaReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val cmd = intent?.getStringExtra("cmd") ?: return
            val args = intent.getStringExtra("args") ?: ""
            Log.i(TAG_QA, "recv cmd=$cmd args=$args")
            qaChannel?.invokeMethod(cmd, args, object : MethodChannel.Result {
                override fun success(result: Any?) {
                    Log.i(TAG_QA, "ok $cmd -> ${result ?: "null"}")
                }
                override fun error(code: String, message: String?, details: Any?) {
                    Log.e(TAG_QA, "err $cmd -> $code $message")
                }
                override fun notImplemented() {
                    Log.e(TAG_QA, "err $cmd -> notImplemented")
                }
            })
        }
    }

    override fun onCreate() {
        super.onCreate()
        val engine = FlutterEngine(this)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)

        screenChannel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_SCREEN)
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
        }
        // 앱 스코프 등록 → Activity 유무와 무관하게 화면 상태 변화를 항상 수신(프로세스 종료 시 자동 해제).
        registerExported(screenReceiver, filter)

        // 디버그(=debuggable) 빌드에서만 QA 채널을 연다. 릴리스 APK 에는 수신기 자체가 없다.
        val debuggable = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (debuggable) {
            qaChannel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_QA)
            registerExported(qaReceiver, IntentFilter(ACTION_QA))
            Log.i(TAG_QA, "QA command channel ready (action=$ACTION_QA)")
        }
    }

    /** Android 13+ 는 앱 외부(adb 포함) 브로드캐스트를 받으려면 EXPORTED 플래그가 필요하다. */
    private fun registerExported(receiver: BroadcastReceiver, filter: IntentFilter) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(receiver, filter)
        }
    }

    companion object {
        const val ENGINE_ID = "cgms_engine"
        const val CHANNEL_SCREEN = "cgms/screen"
        const val CHANNEL_QA = "cgms/qa"
        const val ACTION_QA = "com.helpcare.app.QA"
        const val TAG_QA = "CGMS_QA"
    }
}
