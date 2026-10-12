package com.example.flutter_ota

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.loader.FlutterLoader
import java.io.File

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Private internal storage folder reference setup
        val updateFile = File(filesDir, "ota/libapp.so")

        // 🛠️ SAFE BOUNDARY CHECK:
        // File exist karni chahiye aur uska size kam se kam 100KB hona chahiye.
        // Isse aapki 1MB, 5MB, ya 10MB tak ki file aaram se load ho jayegi, koi blocking nahi hogi!
        if (updateFile.exists() && updateFile.length() > 100 * 1024) {
            val loader = FlutterLoader()

            // Explicitly native engine ko command do dynamic binary run karne ke liye
            val args = arrayOf(
                "--aot-shared-library-name=" + updateFile.absolutePath,
                "--snapshot-kind=app-aot-elf" // Yeh line zaroori hai taaki flutter engine size dekh kar reject na kare
            )

            loader.startInitialization(applicationContext)
            loader.ensureInitializationComplete(applicationContext, args)
        }

        super.onCreate(savedInstanceState)
    }
}
