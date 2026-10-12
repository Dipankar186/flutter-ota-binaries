abstract class OtaState {}

class OtaInitialState extends OtaState {}

class OtaCheckingState extends OtaState {}

class OtaNoUpdateAvailable extends OtaState {}

class OtaDownloadingState extends OtaState {
  final double progress;
  OtaDownloadingState(this.progress);
}

class OtaUpdateStagedSuccess extends OtaState {}

class OtaRollbackErrorState extends OtaState {
  final String message;
  OtaRollbackErrorState(this.message);
}
