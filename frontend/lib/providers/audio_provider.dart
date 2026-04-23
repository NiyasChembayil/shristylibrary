import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

enum PlayerStatus { playing, paused, stopped, loading }

class AudioPlayerState {
  final PlayerStatus status;
  final Duration position;
  final Duration totalDuration;
  final dynamic currentMediaItem;
  final double playbackSpeed;

  AudioPlayerState({
    this.status = PlayerStatus.stopped,
    this.position = Duration.zero,
    this.totalDuration = Duration.zero,
    this.currentMediaItem,
    this.playbackSpeed = 1.0,
  });

  AudioPlayerState copyWith({
    PlayerStatus? status,
    Duration? position,
    Duration? totalDuration,
    dynamic currentMediaItem,
    double? playbackSpeed,
  }) {
    return AudioPlayerState(
      status: status ?? this.status,
      position: position ?? this.position,
      totalDuration: totalDuration ?? this.totalDuration,
      currentMediaItem: currentMediaItem ?? this.currentMediaItem,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    );
  }
}

class PlayerNotifier extends StateNotifier<AudioPlayerState> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  PlayerNotifier() : super(AudioPlayerState()) {
    _initStreams();
  }

  void _initStreams() {
    _audioPlayer.onPlayerStateChanged.listen((playbackState) {
      if (playbackState == PlayerState.playing) {
        state = state.copyWith(status: PlayerStatus.playing);
      } else if (playbackState == PlayerState.paused) {
        state = state.copyWith(status: PlayerStatus.paused);
      } else if (playbackState == PlayerState.stopped || playbackState == PlayerState.completed) {
        state = state.copyWith(status: PlayerStatus.stopped, position: Duration.zero);
      }
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      state = state.copyWith(totalDuration: newDuration);
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      state = state.copyWith(position: newPosition);
    });
  }

  Future<void> play(dynamic item) async {
    // Expect item to be a String representing the secure HTTPS URL
    if (item is String && item.isNotEmpty) {
      state = state.copyWith(status: PlayerStatus.loading, currentMediaItem: item);
      try {
        await _audioPlayer.play(UrlSource(item));
        state = state.copyWith(status: PlayerStatus.playing);
      } catch (e) {
        debugPrint("Error playing audio: $e");
        state = state.copyWith(status: PlayerStatus.stopped);
      }
    }
  }

  Future<void> togglePlay() async {
    if (state.status == PlayerStatus.playing) {
      await _audioPlayer.pause();
    } else if (state.status == PlayerStatus.paused) {
      await _audioPlayer.resume();
    }
  }

  Future<void> seek(Duration pos) async {
    await _audioPlayer.seek(pos);
  }

  Future<void> setSpeed(double speed) async {
    await _audioPlayer.setPlaybackRate(speed);
    state = state.copyWith(playbackSpeed: speed);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}

final playerNotifierProvider = StateNotifierProvider<PlayerNotifier, AudioPlayerState>((ref) {
  return PlayerNotifier();
});
