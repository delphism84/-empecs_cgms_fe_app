package com.helpcare.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode

class MainActivity: FlutterActivity() {
    // 상주(cached) 엔진에 부착 → Activity 재생성 시 main() 재실행/스플래시 없이 재부착.
    override fun getCachedEngineId(): String? = App.ENGINE_ID

    // 캐시 엔진 재부착 시 SurfaceView가 검은 화면으로 멈추는 알려진 버그 회피.
    // TextureView는 detach/reattach에 강건하다(삼성이 백그라운드 Activity를 파괴 후
    // 재진입 시 검은 화면 방지). 약간의 렌더 비용은 이 앱(차트/폼)에서 무시 가능.
    override fun getRenderMode(): RenderMode = RenderMode.texture
}
