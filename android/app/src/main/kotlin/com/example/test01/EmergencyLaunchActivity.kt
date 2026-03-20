package com.example.test01

import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity

class EmergencyLaunchActivity : FlutterActivity() {
    companion object {
        fun createIntent(context: Context): Intent {
            return FlutterActivity.NewEngineIntentBuilder(EmergencyLaunchActivity::class.java)
                .initialRoute("/emergency")
                .build(context)
                .apply {
                    flags =
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP
                }
        }
    }
}
