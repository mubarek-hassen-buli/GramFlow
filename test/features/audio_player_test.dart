import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/app/theme/app_theme.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/audio/domain/audio_playback_state.dart';
import 'package:gramx/features/audio/domain/audio_track.dart';
import 'package:gramx/features/audio/presentation/audio_player_notifier.dart';
import 'package:gramx/features/audio/presentation/widgets/audio_now_playing_sheet.dart';
import 'package:gramx/features/audio/presentation/widgets/floating_audio_player.dart';

void main() {
  const track1 = AudioTrack(
    id: 'track_1',
    title: 'Episode 42: Flutter Revolution',
    localPath: '/tmp/track1.mp3',
    durationSeconds: 180,
    channelTitle: 'Tech Talk Daily',
  );

  const track2 = AudioTrack(
    id: 'track_2',
    title: 'Voice note from Pavel',
    localPath: '/tmp/voice.ogg',
    durationSeconds: 45,
    isVoice: true,
    channelTitle: 'Durov Channel',
  );

  group('AudioPlaybackState unit tests', () {
    test('initial state has no track', () {
      const state = AudioPlaybackState();
      expect(state.hasTrack, isFalse);
      expect(state.hasNext, isFalse);
      expect(state.hasPrevious, isFalse);
      expect(state.isPlaying, isFalse);
      expect(state.speed, 1.0);
    });

    test('hasNext and hasPrevious reflect queue position', () {
      final state = AudioPlaybackState(
        currentTrack: track1,
        queue: [track1, track2],
        currentIndex: 0,
      );
      expect(state.hasTrack, isTrue);
      expect(state.hasNext, isTrue);
      expect(state.hasPrevious, isFalse);

      final nextState = state.copyWith(currentTrack: track2, currentIndex: 1);
      expect(nextState.hasNext, isFalse);
      expect(nextState.hasPrevious, isTrue);
    });

    test('clearTrack resets playback values', () {
      final state = AudioPlaybackState(
        currentTrack: track1,
        isPlaying: true,
        position: const Duration(seconds: 30),
        duration: const Duration(seconds: 180),
        queue: [track1],
        currentIndex: 0,
      );

      final cleared = state.copyWith(clearTrack: true);
      expect(cleared.hasTrack, isFalse);
      expect(cleared.isPlaying, isFalse);
      expect(cleared.position, Duration.zero);
      expect(cleared.currentIndex, -1);
    });
  });

  group('FloatingAudioPlayer widget', () {
    testWidgets('renders nothing when no track is active', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(bottomNavigationBar: FloatingAudioPlayer()),
          ),
        ),
      );

      expect(find.byType(FloatingAudioPlayer), findsOneWidget);
      expect(find.text('Episode 42: Flutter Revolution'), findsNothing);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });

    testWidgets('renders mini player and controls when track is active', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioPlayerProvider.overrideWith(
              () => AudioPlayerNotifier(
                const AudioPlaybackState(
                  currentTrack: track1,
                  isPlaying: true,
                  duration: Duration(seconds: 180),
                  position: Duration(seconds: 60),
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const Scaffold(bottomNavigationBar: FloatingAudioPlayer()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Episode 42: Flutter Revolution'), findsOneWidget);
      expect(find.text('Tech Talk Daily'), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });
  });

  group('AudioNowPlayingSheet widget', () {
    testWidgets('renders full player with podcast controls and queue', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioPlayerProvider.overrideWith(
              () => AudioPlayerNotifier(
                const AudioPlaybackState(
                  currentTrack: track1,
                  isPlaying: true,
                  duration: Duration(seconds: 180),
                  position: Duration(seconds: 60),
                  speed: 1.5,
                  queue: [track1, track2],
                  currentIndex: 0,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const Scaffold(body: AudioNowPlayingSheet()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.audioNowPlaying), findsOneWidget);
      expect(
        find.text('Episode 42: Flutter Revolution'),
        findsNWidgets(2),
      ); // in header & queue
      expect(find.text('Tech Talk Daily'), findsNWidgets(2));
      expect(find.text('1.5x'), findsOneWidget);
      expect(find.text(AppStrings.audioQueue), findsOneWidget);
      expect(find.text('Voice note from Pavel'), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.byIcon(Icons.replay_10_rounded), findsOneWidget);
      expect(find.byIcon(Icons.forward_30_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
    });
  });
}
