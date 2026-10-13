import 'dart:io';
import 'package:flutter/services.dart';

/// Native bridge for OTA Engine operations (ABI Resolution & Hard Process Termination)
class NativeBridge {
  static const MethodChannel _channel = MethodChannel('com.example.flutter_ota/native');

  /// Dynamic Multiclass Architecture Resolver:
  /// Queries native Android Build.SUPPORTED_ABIS to get the exact primary ABI runtime
  /// specification (e.g. 'arm64-v8a', 'armeabi-v7a', 'x86_64').
  static Future<String> getDeviceAbi() async {
    if (!Platform.isAndroid) {
      return 'unsupported';
    }

    try {
      final String? abi = await _channel.invokeMethod<String>('getDeviceAbi');
      if (abi != null && abi.isNotEmpty) {
        return abi.trim();
      }
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('⚠️ NativeBridge: Failed to get ABI from native channel: ${e.message}');
    }

    // Default conservative fallback
    return 'arm64-v8a';
  }

  /// Complete Native Memory Hard-Kill Process:
  /// Triggers a native Activity crash-restart and immediate process kill
  /// using `android.os.Process.killProcess(android.os.Process.myPid())` to purge
  /// all dynamic VM memory segments and boot fresh with new AOT symbols.
  static Future<void> restartAndHardKillProcess() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      await _channel.invokeMethod('restartAndHardKill');
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('⚠️ NativeBridge: Hard-kill invocation failed: ${e.message}');
      // Fallback exit if native bridge fails
      exit(0);
    }
  }
}
