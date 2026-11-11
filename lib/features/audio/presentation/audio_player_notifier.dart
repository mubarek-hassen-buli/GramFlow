import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:gramx/core/audio/playable_audio.dart';
import 'package:gramx/features/audio/domain/audio_playback_state.dart';
import 'package:gramx/features/audio/domain/audio_track.dart';

/// Global application-level audio playback controller.
class AudioPlayerNotifier extends Notifier<AudioPlaybackState> {
  final AudioPlaybackState? _initialStateForTesting;
  VideoPlayerController? _controller;
  bool _isDisposed = false;

  AudioPlayerNotifier([this._initialStateForTesting]);

  @override
  AudioPlaybackState build() {
    ref.onDispose(() {
      _isDisposed = true;
      _disposeController();
    });
    return _initialStateForTesting ?? const AudioPlaybackState();
  }

  void _disposeController() {
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    _controller = null;
  }

  void _onControllerUpdate() {
    final controller = _controller;
    if (controller == null || _isDisposed) return;

    final value = controller.value;
    final position = value.position;
    final duration = value.duration;
    final isPlaying = value.isPlaying;
    final isBuffering = value.isBuffering;

    // Check for track completion
    if (duration > Duration.zero && position >= duration) {
      if (state.hasNext) {
        skipNext();
        return;
      }
    }

    state = state.copyWith(
      position: position,
      duration: duration > Duration.zero
          ? duration
          : (state.currentTrack != null
                ? Duration(seconds: state.currentTrack!.durationSeconds)
                : Duration.zero),
      isPlaying: isPlaying,
      isBuffering: isBuffering,
    );
  }

  /// Starts or resumes playing [track].
  Future<void> playTrack(AudioTrack track, {List<AudioTrack>? queue}) async {
    final localPath = track.localPath;
    if (localPath == null || localPath.isEmpty) {
      debugPrint(
        '[AudioPlayerNotifier] Cannot play track with empty localPath',
      );
      return;
    }

    // If same track is already loaded, toggle or resume
    if (state.currentTrack?.id == track.id && _controller != null) {
      if (!state.isPlaying) {
        await _controller!.play();
      }
      return;
    }

    _disposeController();

    final newQueue = queue ?? (state.queue.isEmpty ? [track] : state.queue);
    var index = newQueue.indexWhere((t) => t.id == track.id);
    if (index < 0) {
      newQueue.add(track);
      index = newQueue.length - 1;
    }

    state = state.copyWith(
      currentTrack: track,
      isBuffering: true,
      isPlaying: false,
      position: Duration.zero,
      duration: Duration(seconds: track.durationSeconds),
      queue: newQueue,
      currentIndex: index,
    );

    try {
      final playable = await playableAudioPath(localPath);
      if (_isDisposed) return;

      final controller = VideoPlayerController.file(File(playable));
      await controller.initialize();
      if (_isDisposed) {
        await controller.dispose();
        return;
      }

      await controller.setPlaybackSpeed(state.speed);
      controller.addListener(_onControllerUpdate);
      _controller = controller;

      await controller.play();

      state = state.copyWith(
        isBuffering: false,
        isPlaying: true,
        duration: controller.value.duration,
      );
    } catch (e) {
      debugPrint('[AudioPlayerNotifier] Play error: $e');
      _disposeController();
      state = state.copyWith(isBuffering: false, isPlaying: false);
    }
  }

  /// Toggles between play and pause.
  Future<void> togglePlay() async {
    final controller = _controller;
    if (controller == null) return;

    if (controller.value.isPlaying) {
      await controller.pause();
      state = state.copyWith(isPlaying: false);
    } else {
      await controller.play();
      state = state.copyWith(isPlaying: true);
    }
  }

  Future<void> pause() async {
    if (_controller?.value.isPlaying == true) {
      await _controller!.pause();
      state = state.copyWith(isPlaying: false);
    }
  }

  Future<void> resume() async {
    if (_controller != null && !_controller!.value.isPlaying) {
      await _controller!.play();
      state = state.copyWith(isPlaying: true);
    }
  }

  Future<void> seekTo(Duration target) async {
    final controller = _controller;
    if (controller == null) return;

    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > state.duration ? state.duration : target);

    await controller.seekTo(clamped);
    state = state.copyWith(position: clamped);
  }

  Future<void> skipBack15() async {
    final target = state.position - const Duration(seconds: 15);
    await seekTo(target < Duration.zero ? Duration.zero : target);
  }

  Future<void> skipForward30() async {
    final target = state.position + const Duration(seconds: 30);
    await seekTo(target);
  }

  Future<void> setSpeed(double speed) async {
    state = state.copyWith(speed: speed);
    await _controller?.setPlaybackSpeed(speed);
  }

  Future<void> skipNext() async {
    if (!state.hasNext) return;
    final nextIndex = state.currentIndex + 1;
    final nextTrack = state.queue[nextIndex];
    await playTrack(nextTrack, queue: state.queue);
  }

  Future<void> skipPrevious() async {
    if (state.position > const Duration(seconds: 3)) {
      await seekTo(Duration.zero);
      return;
    }
    if (!state.hasPrevious) return;
    final prevIndex = state.currentIndex - 1;
    final prevTrack = state.queue[prevIndex];
    await playTrack(prevTrack, queue: state.queue);
  }

  /// Stops playback, clears the active track, and dismisses the player.
  void stop() {
    _disposeController();
    state = state.copyWith(clearTrack: true);
  }

  @visibleForTesting
  void updateStateForTesting(AudioPlaybackState newState) {
    state = newState;
  }
}

final audioPlayerProvider =
    NotifierProvider<AudioPlayerNotifier, AudioPlaybackState>(
      AudioPlayerNotifier.new,
    );
