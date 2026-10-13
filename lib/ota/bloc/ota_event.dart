import '../model/ota_binary_manifest.dart';

abstract class OtaEvent {}

class CheckForUpdatesEvent extends OtaEvent {}

class StartDownloadEvent extends OtaEvent {
  final OtaBinaryManifest manifest;
  StartDownloadEvent(this.manifest);
}

class UpdateProgressEvent extends OtaEvent {
  final double progress;
  final String abi;
  UpdateProgressEvent(this.progress, {this.abi = ''});
}

class OtaFailureEvent extends OtaEvent {
  final String errorMessage;
  OtaFailureEvent(this.errorMessage);
}
