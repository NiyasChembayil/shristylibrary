// import 'package:audio_service/audio_service.dart';
// import 'package:just_audio/just_audio.dart';
import 'dart:developer' as developer;

class BaseAudioHandler {}
mixin SeekHandler {}

class SrishtyAudioHandler extends BaseAudioHandler with SeekHandler {
  SrishtyAudioHandler() {
    developer.log("Audio service stub initialized");
  }
}

