package com.example.flutter_ota

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.loader.FlutterLoader
import java.io.File

class  MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Private internal storage folder check karo
        val updateFile = File(filesDir, "ota/libapp.so")

        // ROLLBACK SAFETY: Agar file completely download nahi hui ya size 0 hai,
        // toh custom path ignore hoga aur app default APK bundle se safe chalegi.
        if (updateFile.exists() && updateFile.length() > 100 * 1024) { // Min 1MB verification
            val loader = FlutterLoader()
            val args = arrayOf("--aot-shared-library-name=" + updateFile.absolutePath)

            loader.startInitialization(applicationContext)
            loader.ensureInitializationComplete(applicationContext, args)
        }

        super.onCreate(savedInstanceState)
    }
}
