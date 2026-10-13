package com.example.flutter_ota

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterShellArgs
import java.io.File

class MainActivity: FlutterActivity() {

    override fun getFlutterShellArgs(): FlutterShellArgs {
        val shellArgs = super.getFlutterShellArgs()
        val updateFile = File(filesDir, "ota/libapp.so")
        if (updateFile.exists() && updateFile.length() > 100 * 1024) {
            shellArgs.add("--aot-shared-library-name=" + updateFile.absolutePath)
            shellArgs.add("--snapshot-kind=app-aot-elf")
        }
        return shellArgs
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Private internal storage folder reference setup
        val updateFile = File(filesDir, "ota/libapp.so")

        // 🛠️ SAFE BOUNDARY CHECK:
        // File exist karni chahiye aur uska size kam se kam 100KB hona chahiye.
        if (updateFile.exists() && updateFile.length() > 100 * 1024) {
            val loader = FlutterInjector.instance().flutterLoader()

            // Explicitly native engine ko command do dynamic binary run karne ke liye
            val args = arrayOf(
                "--aot-shared-library-name=" + updateFile.absolutePath,
                "--snapshot-kind=app-aot-elf"
            )

            loader.startInitialization(applicationContext)
            loader.ensureInitializationComplete(applicationContext, args)
        }

        super.onCreate(savedInstanceState)
    }
}
