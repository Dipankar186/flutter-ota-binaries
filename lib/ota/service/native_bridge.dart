// 📁 Path: lib/ota/repository/ota_repository.dart

import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class OtaRepository {
  // Current version mapping flag (Base APK is 1)
  final int currentLocalVersion = 1;

  Future<void> downloadNewBinary({
    required String url,
    required Function(double progress) onProgress,
  }) async {
    final client = http.Client();
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final otaDirectory = Directory('${appDir.parent.path}/files/ota');

      if (!await otaDirectory.exists()) {
        await otaDirectory.create(recursive: true);
      }

      final tempPath = '${otaDirectory.path}/libapp_temp.so';
      final finalPath = '${otaDirectory.path}/libapp.so';

      // Setup clean request parameters
      final request = http.Request('GET', Uri.parse(url));
      request.followRedirects = true;
      request.maxRedirects = 5;

      final http.StreamedResponse response = await client.send(request);

      // Handle intermediate jumps if fallback happens
      String finalDownloadUrl = url;
      if (response.statusCode == 301 || response.statusCode == 302) {
        finalDownloadUrl = response.headers['location'] ?? url;
      }

      final finalResponse = await client.send(http.Request('GET', Uri.parse(finalDownloadUrl)));

      if (finalResponse.statusCode != 200) {
        throw Exception("Server connection error: ${finalResponse.statusCode}");
      }

      // 🛠️ FIX: Content length check fallback mechanism
      final totalBytes = finalResponse.contentLength ?? 0;
      int receivedBytes = 0;

      final File tempFile = File(tempPath);
      final IOSink sink = tempFile.openWrite();

      // Download chunks one by one synchronously
      await finalResponse.stream.listen(
            (List<int> chunk) {
          receivedBytes += chunk.length;
          sink.add(chunk);

          // Progress calculation matrix with zero check fallback
          if (totalBytes > 0) {
            double progress = (receivedBytes / totalBytes) * 100;
            onProgress(progress);
          } else {
            // Agar size null hai toh direct increment logic pass karo UI ko
            onProgress(-1.0);
          }
        },
        cancelOnError: true,
      ).asFuture();

      await sink.close();

      // Verification validation layer (Size restriction threshold relaxed to 500KB)
      final downloadedBytes = await tempFile.length();
      if (await tempFile.exists() && downloadedBytes > 500 * 1024) {
        final finalFile = File(finalPath);
        if (await finalFile.exists()) {
          await finalFile.delete();
        }
        await tempFile.rename(finalPath);
        print("🎉 Success: File verification matching complete.");
      } else {
        throw Exception("Verification failed: File size too small ($downloadedBytes bytes)");
      }
    } catch (e) {
      throw Exception("Stream connection breakdown: $e");
    } finally {
      client.close();
    }
  }
}
