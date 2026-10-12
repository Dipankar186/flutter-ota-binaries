abstract class OtaEvent {}

class CheckForUpdatesEvent extends OtaEvent {}

class StartDownloadEvent extends OtaEvent {
  final String url;
  StartDownloadEvent(this.url);
}

class UpdateProgressEvent extends OtaEvent {
  final double progress;
  UpdateProgressEvent(this.progress);
}

class OtaFailureEvent extends OtaEvent {
  final String errorMessage;
  OtaFailureEvent(this.errorMessage);
}
