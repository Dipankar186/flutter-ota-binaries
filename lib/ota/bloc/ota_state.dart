abstract class OtaState {}

class OtaInitialState extends OtaState {}

class OtaCheckingState extends OtaState {}

class OtaNoUpdateAvailable extends OtaState {
  final String? message;
  OtaNoUpdateAvailable([this.message]);
}

class OtaDownloadingState extends OtaState {
  final double progress;
  final String abi;
  OtaDownloadingState(this.progress, {this.abi = ''});
}

class OtaUpdateStagedSuccess extends OtaState {
  final String abi;
  final int version;
  OtaUpdateStagedSuccess({required this.abi, required this.version});
}

class OtaRollbackErrorState extends OtaState {
  final String message;
  OtaRollbackErrorState(this.message);
}
