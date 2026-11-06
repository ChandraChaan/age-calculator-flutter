package com.chandra.agecalculator

import android.content.Intent
import com.chandra.agecalculator.deviceimport.DeviceImport
import com.chandra.agecalculator.widget.UpcomingWidgetProvider
import com.chandra.agecalculator.widget.WidgetLaunch
import com.chandra.agecalculator.widget.WidgetSnapshot
import com.chandra.agecalculator.widget.WidgetSnapshotStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var deviceImport: DeviceImport? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        deviceImport?.dispose()
        deviceImport = DeviceImport(this, flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WidgetLaunch.CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateSnapshot" -> {
                        val json = call.arguments as? String
                        if (json == null) {
                            result.error("bad_args", "expected JSON string", null)
                            return@setMethodCallHandler
                        }
                        try {
                            WidgetSnapshot.parse(json)
                            WidgetSnapshotStore.save(this, json)
                            UpcomingWidgetProvider.refreshAll(this)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("bad_snapshot", e.message, null)
                        }
                    }
                    "consumeLaunchAction" -> result.success(WidgetLaunch.consume(this))
                    else -> result.notImplemented()
                }
            }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        deviceImport?.dispose()
        deviceImport = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (deviceImport?.onRequestPermissionsResult(requestCode, grantResults) != true) {
            super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        WidgetLaunch.dispatchWarm(this, intent, flutterEngine)
    }
}
