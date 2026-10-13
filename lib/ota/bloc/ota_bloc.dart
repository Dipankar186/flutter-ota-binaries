import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import '../model/ota_binary_manifest.dart';
import '../repository/ota_repository.dart';
import '../service/native_bridge.dart';
import 'ota_event.dart';
import 'ota_state.dart';

class OtaBloc extends Bloc<OtaEvent, OtaState> {
  final OtaRepository repository;

  OtaBloc({required this.repository}) : super(OtaInitialState()) {

    on<CheckForUpdatesEvent>((event, emit) async {
      emit(OtaCheckingState());
      try {
        // =====================================================================
        // CONSTRAINT 1: Dynamic Multiclass Architecture Resolver
        // Detect the device's exact ABI runtime specification (arm64-v8a, armeabi-v7a, x86_64)
        // =====================================================================
        final String deviceAbi = await NativeBridge.getDeviceAbi();
        // ignore: avoid_print
        print('📱 [OTA Resolver] Target device runtime ABI resolved: $deviceAbi');

        final remoteConfig = FirebaseRemoteConfig.instance;
        await remoteConfig.setConfigSettings(RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 15),
          minimumFetchInterval: Duration.zero,
        ));
        await remoteConfig.fetchAndActivate();

        OtaBinaryManifest? manifest = _resolveManifest(remoteConfig, deviceAbi);

        if (manifest == null) {
          emit(OtaNoUpdateAvailable("No compatible update configuration found for ABI: $deviceAbi"));
          return;
        }

        if (manifest.version > repository.currentLocalVersion && manifest.downloadUrl.isNotEmpty) {
          // ignore: avoid_print
          print('📦 [OTA Resolver] Update available: v${manifest.version} for $deviceAbi');
          add(StartDownloadEvent(manifest));
        } else {
          emit(OtaNoUpdateAvailable("Device is running current latest version (v${repository.currentLocalVersion})"));
        }
      } catch (e) {
        emit(OtaRollbackErrorState("Remote Config resolution failure: $e"));
      }
    });

    on<StartDownloadEvent>((event, emit) async {
      final manifest = event.manifest;
      emit(OtaDownloadingState(0.0, abi: manifest.abi));
      try {
        await repository.stageUpdateBinary(
          manifest: manifest,
          onProgress: (progress) {
            add(UpdateProgressEvent(progress, abi: manifest.abi));
          },
        );

        // Emit staged success state
        emit(OtaUpdateStagedSuccess(
          abi: manifest.abi,
          version: manifest.version,
        ));
      } catch (e) {
        // Rollback safety: Abort and maintain running baseline
        emit(OtaRollbackErrorState("Binary staging aborted: $e"));
      }
    });

    on<UpdateProgressEvent>((event, emit) {
      emit(OtaDownloadingState(event.progress, abi: event.abi));
    });
  }

  /// Resolves the exact architectural binary manifest from Firebase Remote Config.
  /// Supports both multiclass JSON string map and fallback flat key-value pairs.
  OtaBinaryManifest? _resolveManifest(FirebaseRemoteConfig rc, String deviceAbi) {
    // 1. Try parsing dynamic multiclass JSON architecture map: `ota_architectures_config`
    final String jsonConfig = rc.getString('ota_architectures_config');
    if (jsonConfig.isNotEmpty) {
      try {
        final decoded = json.decode(jsonConfig) as Map<String, dynamic>;
        final int targetVersion = decoded['version'] as int? ?? rc.getInt('ota_version');
        final Map<String, dynamic>? binariesMap = decoded['binaries'] as Map<String, dynamic>?;

        if (binariesMap != null) {
          // Check exact ABI match or alias (e.g., arm64-v8a vs arm64)
          final abiData = binariesMap[deviceAbi] ??
              binariesMap[_normalizeAbi(deviceAbi)];

          if (abiData != null && abiData is Map<String, dynamic>) {
            return OtaBinaryManifest.fromJson(
              version: targetVersion,
              abi: deviceAbi,
              json: abiData,
            );
          }
        }
      } catch (e) {
        // ignore: avoid_print
        print('⚠️ Failed to parse ota_architectures_config JSON: $e');
      }
    }

    // 2. Fallback to individual Remote Config keys for the resolved ABI
    final safeAbiKey = deviceAbi.replaceAll('-', '_'); // e.g. arm64_v8a
    final int version = rc.getInt('ota_version');
    final String abiUrl = rc.getString('ota_url_$safeAbiKey');
    final String fallbackUrl = rc.getString('ota_url');
    final String downloadUrl = abiUrl.isNotEmpty ? abiUrl : fallbackUrl;

    if (downloadUrl.isEmpty) {
      return null;
    }

    final String sha256 = rc.getString('ota_sha256_$safeAbiKey').isNotEmpty
        ? rc.getString('ota_sha256_$safeAbiKey')
        : rc.getString('ota_sha256');

    final int size = rc.getInt('ota_size_$safeAbiKey') > 0
        ? rc.getInt('ota_size_$safeAbiKey')
        : rc.getInt('ota_size');

    return OtaBinaryManifest(
      version: version,
      abi: deviceAbi,
      downloadUrl: downloadUrl,
      expectedSha256: sha256,
      expectedSizeBytes: size,
    );
  }

  String _normalizeAbi(String abi) {
    switch (abi) {
      case 'arm64-v8a':
        return 'arm64';
      case 'armeabi-v7a':
        return 'arm';
      case 'x86_64':
        return 'x64';
      default:
        return abi;
    }
  }
}
