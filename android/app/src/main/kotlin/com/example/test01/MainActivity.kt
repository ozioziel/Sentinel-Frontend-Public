package com.example.test01

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.test01/app_branding"

    private val launcherAliases by lazy {
        val packageName = applicationContext.packageName
        mapOf(
            "sentinel" to "$packageName.LauncherDefault",
            "agenda" to "$packageName.LauncherAgenda",
            "notas" to "$packageName.LauncherNotas",
            "tareas" to "$packageName.LauncherTareas",
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "applyPreset" -> {
                    val presetId = call.argument<String>("presetId")
                    if (presetId.isNullOrBlank()) {
                        result.error(
                            "invalid_preset",
                            "No se recibio un preset valido.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    val aliasClassName = launcherAliases[presetId]
                    if (aliasClassName == null) {
                        result.error(
                            "unknown_preset",
                            "El preset $presetId no existe.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    updateLauncherAlias(aliasClassName)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun updateLauncherAlias(selectedAliasClassName: String) {
        val packageManager = applicationContext.packageManager
        val allAliases = launcherAliases.values.toSet()

        val selectedComponent = ComponentName(this, selectedAliasClassName)
        packageManager.setComponentEnabledSetting(
            selectedComponent,
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )

        allAliases
            .filter { it != selectedAliasClassName }
            .forEach { aliasClassName ->
                val component = ComponentName(this, aliasClassName)
                packageManager.setComponentEnabledSetting(
                    component,
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP,
                )
            }
    }
}
