import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import '../service/native_bridge.dart';
import 'ota_event.dart';
import 'ota_state.dart';

class OtaBloc extends Bloc<OtaEvent, OtaState> {
  final OtaRepository repository;

  OtaBloc({required this.repository}) : super(OtaInitialState()) {

    on<CheckForUpdatesEvent>((event, emit) async {
      emit(OtaCheckingState());
      try {
        final remoteConfig = FirebaseRemoteConfig.instance;
        await remoteConfig.setConfigSettings(RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 15),
          minimumFetchInterval: Duration.zero, // Demo ke liye instantaneous tracking
        ));
        await remoteConfig.fetchAndActivate();

        int serverVersion = remoteConfig.getInt('ota_version');
        String serverUrl = remoteConfig.getString('ota_url');

        if (serverVersion > repository.currentLocalVersion && serverUrl.isNotEmpty) {
          add(StartDownloadEvent(serverUrl));
        } else {
          emit(OtaNoUpdateAvailable());
        }
      } catch (e) {
        // Network connection error ya Firebase issue hone par silent fallback
        emit(OtaRollbackErrorState("Internet connectivity issue. Running base engine securely."));
      }
    });

    on<StartDownloadEvent>((event, emit) async {
      emit(OtaDownloadingState(0.0));
      try {
        await repository.downloadNewBinary(
          url: event.url,
          onProgress: (progress) {
            add(UpdateProgressEvent(progress));
          },
        );
        emit(OtaUpdateStagedSuccess());
      } catch (e) {
        // Rollback Trigger: Error aane par purani stable things chalti rahengi
        emit(OtaRollbackErrorState("Download aborted halfway. Safely rolled back to old code."));
      }
    });

    on<UpdateProgressEvent>((event, emit) {
      emit(OtaDownloadingState(event.progress));
    });
  }
}
