package com.example.folio

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode

class MainActivity : FlutterActivity() {
    // The default SurfaceView is painted BLACK until Flutter draws its first
    // frame, which is the black screen seen at start-up. A TextureView stays
    // see-through, so the app's tinted launch background shows instead.
    override fun getRenderMode(): RenderMode = RenderMode.texture
}
