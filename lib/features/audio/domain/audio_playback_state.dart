import 'package:flutter/foundation.dart';
import 'package:gramx/features/audio/domain/audio_track.dart';

/// Immutable state of the audio player engine.
@immutable
class AudioPlaybackState {
  final AudioTrack? currentTrack;
  final bool isPlaying;
  final bool isBuffering;
  final Duration position;
  final Duration duration;
  final double speed;
  final List<AudioTrack> queue;
  final int currentIndex;

  const AudioPlaybackState({
    this.currentTrack,
    this.isPlaying = false,
    this.isBuffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.speed = 1.0,
    this.queue = const [],
    this.currentIndex = -1,
  });

  bool get hasTrack => currentTrack != null;
  bool get hasNext => currentIndex >= 0 && currentIndex + 1 < queue.length;
  bool get hasPrevious => currentIndex > 0;

  AudioPlaybackState copyWith({
    AudioTrack? currentTrack,
    bool? isPlaying,
    bool? isBuffering,
    Duration? position,
    Duration? duration,
    double? speed,
    List<AudioTrack>? queue,
    int? currentIndex,
    bool clearTrack = false,
  }) {
    return AudioPlaybackState(
      currentTrack: clearTrack ? null : (currentTrack ?? this.currentTrack),
      isPlaying: clearTrack ? false : (isPlaying ?? this.isPlaying),
      isBuffering: clearTrack ? false : (isBuffering ?? this.isBuffering),
      position: clearTrack ? Duration.zero : (position ?? this.position),
      duration: clearTrack ? Duration.zero : (duration ?? this.duration),
      speed: speed ?? this.speed,
      queue: queue ?? this.queue,
      currentIndex: clearTrack ? -1 : (currentIndex ?? this.currentIndex),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioPlaybackState &&
          runtimeType == other.runtimeType &&
          currentTrack == other.currentTrack &&
          isPlaying == other.isPlaying &&
          isBuffering == other.isBuffering &&
          position == other.position &&
          duration == other.duration &&
          speed == other.speed &&
          currentIndex == other.currentIndex;

  @override
  int get hashCode => Object.hash(
    currentTrack,
    isPlaying,
    isBuffering,
    position,
    duration,
    speed,
    currentIndex,
  );
}
