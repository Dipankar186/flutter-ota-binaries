package com.example.flutter_ota

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.loader.FlutterLoader
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {

    private val CHANNEL = "com.example.flutter_ota/native"

    override fun onCreate(savedInstanceState: Bundle?) {
        // Private internal storage folder reference setup
        val updateFile = File(filesDir, "ota/libapp.so")

        // 🛠️ SAFE BOUNDARY CHECK:
        // File must exist and exceed minimum threshold size (100KB)
        // If file is corrupted or missing, fallback to base APK bundle safely
        if (updateFile.exists() && updateFile.length() > 100 * 1024) {
            val loader = FlutterLoader()

            // Pass dynamic AOT ELF shared library parameters directly to Flutter Engine
            val args = arrayOf(
                "--aot-shared-library-name=" + updateFile.absolutePath,
                "--snapshot-kind=app-aot-elf"
            )

            loader.startInitialization(applicationContext)
            loader.ensureInitializationComplete(applicationContext, args)
        }

        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // =============================================================
                // CONSTRAINT 1: Dynamic ABI Resolution
                // =============================================================
                "getDeviceAbi" -> {
                    val primaryAbi = if (Build.SUPPORTED_ABIS.isNotEmpty()) {
                        Build.SUPPORTED_ABIS[0]
                    } else {
                        @Suppress("DEPRECATION")
                        Build.CPU_ABI ?: "arm64-v8a"
                    }
                    result.success(primaryAbi)
                }

                // =============================================================
                // CONSTRAINT 2: Complete Native Memory Hard-Kill Process
                // Clears dynamic cache memory segments and forces crash-restart
                // =============================================================
                "restartAndHardKill" -> {
                    result.success(true)

                    // 1. Arm AlarmManager to trigger cold boot of MainActivity
                    val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                    if (launchIntent != null) {
                        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
                        val restartIntent = PendingIntent.getActivity(
                            applicationContext,
                            1001,
                            launchIntent,
                            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_CANCEL_CURRENT
                        )
                        val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                        alarmManager?.setExact(
                            AlarmManager.ELAPSED_REALTIME,
                            SystemClock.elapsedRealtime() + 250,
                            restartIntent
                        )
                    }

                    // 2. Immediate Hard-Kill of current process to purge all loaded VM/AOT mappings
                    android.os.Process.killProcess(android.os.Process.myPid())
                    System.exit(0)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
