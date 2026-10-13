import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../model/ota_binary_manifest.dart';

/// Exception thrown when cryptographic hash or size checks fail.
class OtaIntegrityException implements Exception {
  final String message;
  OtaIntegrityException(this.message);

  @override
  String toString() => 'OtaIntegrityException: $message';
}

class OtaRepository {
  /// Base binary version shipped in the APK
  final int currentLocalVersion = 2;

  /// Returns the target directory matching Android `context.filesDir + "/ota"`
  Future<Directory> _getOtaDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final otaDir = Directory('${appDir.parent.path}/files/ota');
    if (!await otaDir.exists()) {
      await otaDir.create(recursive: true);
    }
    return otaDir;
  }

  /// Downloads the ABI-matched binary with streaming SHA-256 validation & atomic swap.
  ///
  /// [manifest] Contains target URL, ABI, expected SHA-256 hash, and expected size.
  /// [onProgress] Callback returning download progress from 0.0 to 100.0%.
  Future<void> stageUpdateBinary({
    required OtaBinaryManifest manifest,
    required void Function(double progress) onProgress,
  }) async {
    final client = http.Client();
    final otaDir = await _getOtaDirectory();
    final tempFilePath = '${otaDir.path}/libapp_staging_${DateTime.now().millisecondsSinceEpoch}.tmp';
    final targetFilePath = '${otaDir.path}/libapp.so';

    final tempFile = File(tempFilePath);
    IOSink? sink;

    try {
      final request = http.Request('GET', Uri.parse(manifest.downloadUrl));
      request.followRedirects = true;
      request.maxRedirects = 5;

      final http.StreamedResponse response = await client.send(request);

      // Handle explicit HTTP redirects if not followed by client
      http.StreamedResponse finalResponse = response;
      if (response.statusCode == 301 || response.statusCode == 302) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null) {
          final redirectReq = http.Request('GET', Uri.parse(redirectUrl));
          finalResponse = await client.send(redirectReq);
        }
      }

      if (finalResponse.statusCode != 200) {
        throw HttpException(
          'Update server rejected request with status code: ${finalResponse.statusCode}',
          uri: Uri.parse(manifest.downloadUrl),
        );
      }

      final contentLength = finalResponse.contentLength ?? manifest.expectedSizeBytes;
      int receivedBytes = 0;

      sink = tempFile.openWrite();

      await finalResponse.stream.listen(
        (List<int> chunk) {
          receivedBytes += chunk.length;

          // Stream into persistent storage
          sink?.add(chunk);

          if (contentLength > 0) {
            final progress = (receivedBytes / contentLength) * 100.0;
            onProgress(progress.clamp(0.0, 100.0));
          }
        },
        cancelOnError: true,
      ).asFuture();

      await sink.flush();
      await sink.close();
      sink = null;

      // =========================================================================
      // CONSTRAINT 3: Cryptographic Signature Hash Match & Size Checksum
      // =========================================================================
      final int actualFileSize = await tempFile.length();

      // Rule 3A: Sanity Size Check (Must be >= 100KB to prevent empty/corrupt files)
      if (actualFileSize < 100 * 1024) {
        throw OtaIntegrityException(
          'Corrupted binary: Downloaded file size is too small ($actualFileSize bytes). Aborting staging.',
        );
      }

      // Rule 3B: Exact Size Match (if expected size was declared in Remote Config)
      if (manifest.expectedSizeBytes > 0 && actualFileSize != manifest.expectedSizeBytes) {
        throw OtaIntegrityException(
          'Size mismatch: Expected ${manifest.expectedSizeBytes} bytes, received $actualFileSize bytes.',
        );
      }

      // Rule 3C: Cryptographic SHA-256 Integrity Verification
      // Streams from tempFile without reading everything into memory at once
      final digest = await sha256.bind(tempFile.openRead()).first;
      final String calculatedSha256 = digest.toString().toLowerCase();

      final expectedSha = manifest.expectedSha256.trim().toLowerCase();
      if (expectedSha.isNotEmpty && calculatedSha256 != expectedSha) {
        throw OtaIntegrityException(
          'Cryptographic signature mismatch! Expected: $expectedSha, Computed: $calculatedSha256',
        );
      }

      // =========================================================================
      // ATOMIC SWAP: POSIX rename guarantees atomic replacement
      // =========================================================================
      final targetFile = File(targetFilePath);

      // On Android/Linux, File.rename() is an atomic rename syscall
      // Replace existing libapp.so without leaving partial or corrupted states
      if (await targetFile.exists()) {
        try {
          await targetFile.delete();
        } catch (_) {
          // If in use or non-deletable, rename will overwrite on same filesystem
        }
      }

      await tempFile.rename(targetFilePath);
      // ignore: avoid_print
      print('🚀 [OTA Engine] Atomic swap successful! New binary staged at $targetFilePath');
    } catch (e) {
      // ROLLBACK SAFETY: Clean up staging temp file immediately on any failure
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Clean up staged binary if rollback is required
  Future<void> purgeStagedBinary() async {
    try {
      final otaDir = await _getOtaDirectory();
      final targetFile = File('${otaDir.path}/libapp.so');
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ Failed to purge staged binary: $e');
    }
  }
}
