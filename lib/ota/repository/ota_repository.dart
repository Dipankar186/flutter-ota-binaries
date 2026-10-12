import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class OtaRepository {
  // Current client version hardcoded (V1 base ke liye 1 hoga)
  final int currentLocalVersion = 2;

// 📁 Path: lib/ota/repository/ota_repository.dart

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

      // 🛠️ FIX: Base Client setup jo redirect automatic follow karega
      final request = http.Request('GET', Uri.parse(url));

      // GitHub locations ke redirect follow karne ke liye setting true karo
      request.followRedirects = true;
      request.maxRedirects = 5;

      final http.StreamedResponse response = await client.send(request);

      // Agar 302/301 redirect milta hai, toh manually naya URL fetch karo
      String finalDownloadUrl = url;
      if (response.statusCode == 301 || response.statusCode == 302) {
        finalDownloadUrl = response.headers['location'] ?? url;
      }

      // Dobara final clear direct request bhejo redirect engine ko
      final finalResponse = await client.send(http.Request('GET', Uri.parse(finalDownloadUrl)));

      if (finalResponse.statusCode != 200) {
        throw Exception("Server map failed with code ${finalResponse.statusCode}");
      }

      final totalBytes = finalResponse.contentLength ?? 0;
      int receivedBytes = 0;

      final File tempFile = File(tempPath);
      final IOSink sink = tempFile.openWrite();

      // Byte stream processing chunks
      await finalResponse.stream.listen(
            (List<int> chunk) {
          receivedBytes += chunk.length;
          sink.add(chunk);

          if (totalBytes > 0) {
            double progress = (receivedBytes / totalBytes) * 100;
            onProgress(progress); // Live UI progression pointer
          }
        },
        cancelOnError: true,
      ).asFuture();

      await sink.close();

      // Verification check constraint
      if (await tempFile.exists() && await tempFile.length() > 1024 * 1024) { // Min 1MB validation check
        final finalFile = File(finalPath);
        if (await finalFile.exists()) {
          await finalFile.delete();
        }
        await tempFile.rename(finalPath);
        print("🎉 Internal Swap execution ready!");
      } else {
        throw Exception("File verification block mismatch.");
      }
    } catch (e) {
      throw Exception("Stream breakdown: $e");
    } finally {
      client.close();
    }
  }

}
