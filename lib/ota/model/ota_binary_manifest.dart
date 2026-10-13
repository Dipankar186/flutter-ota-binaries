/// Data model representing the architectural binary target from Remote Config.
class OtaBinaryManifest {
  final int version;
  final String abi;
  final String downloadUrl;
  final String expectedSha256;
  final int expectedSizeBytes;

  const OtaBinaryManifest({
    required this.version,
    required this.abi,
    required this.downloadUrl,
    required this.expectedSha256,
    required this.expectedSizeBytes,
  });

  factory OtaBinaryManifest.fromJson({
    required int version,
    required String abi,
    required Map<String, dynamic> json,
  }) {
    return OtaBinaryManifest(
      version: version,
      abi: abi,
      downloadUrl: json['url'] as String? ?? '',
      expectedSha256: (json['sha256'] as String? ?? '').toLowerCase(),
      expectedSizeBytes: json['size'] as int? ?? 0,
    );
  }
}
