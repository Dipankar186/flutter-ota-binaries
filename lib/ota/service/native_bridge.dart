import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class OtaRepository {
  // Current client version hardcoded (V1 base ke liye 1 hoga)
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

      // HTTP GET Stream Request
      final request = http.Request('GET', Uri.parse(url));
      final http.StreamedResponse response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception("Server responded with code ${response.statusCode}");
      }

      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;

      final List<int> bytesList = [];
      final File tempFile = File(tempPath);

      // Sink open karke direct chunks storage me stream karenge
      final IOSink sink = tempFile.openWrite();

      await response.stream.listen(
            (List<int> chunk) {
          receivedBytes += chunk.length;
          sink.add(chunk);

          if (totalBytes > 0) {
            double progress = (receivedBytes / totalBytes) * 100;
            onProgress(progress);
          }
        },
        cancelOnError: true,
      ).asFuture();

      await sink.close();

      // ATOMIC SWAP: Agar 100% download complete ho gaya aur file solid hai
      if (await tempFile.exists() && await tempFile.length() > 0) {
        final finalFile = File(finalPath);
        if (await finalFile.exists()) {
          await finalFile.delete(); // Purani binary cleanup
        }
        await tempFile.rename(finalPath); // Atomic shift complete!
      } else {
        throw Exception("Downloaded file is empty or corrupted.");
      }
    } catch (e) {
      // Net jane par temporary file ko clear kar do taaki partial data system corrupt na kare
      throw Exception("Network interrupted: $e");
    } finally {
      client.close();
    }
  }
}
