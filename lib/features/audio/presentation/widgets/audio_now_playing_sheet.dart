import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/audio/presentation/audio_player_notifier.dart';

/// Modal bottom sheet providing full podcast-grade playback controls and queue.
class AudioNowPlayingSheet extends ConsumerStatefulWidget {
  const AudioNowPlayingSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const AudioNowPlayingSheet(),
    );
  }

  @override
  ConsumerState<AudioNowPlayingSheet> createState() =>
      _AudioNowPlayingSheetState();
}

class _AudioNowPlayingSheetState extends ConsumerState<AudioNowPlayingSheet> {
  double? _dragFraction;

  static const List<double> _speeds = [1.0, 1.25, 1.5, 2.0];

  void _cycleSpeed(double current) {
    var nextIndex = _speeds.indexOf(current) + 1;
    if (nextIndex >= _speeds.length) nextIndex = 0;
    ref.read(audioPlayerProvider.notifier).setSpeed(_speeds[nextIndex]);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(audioPlayerProvider);
    final track = state.currentTrack;

    if (track == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.onSurface;
    final secondaryColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final total = state.duration;
    final playedFraction = total > Duration.zero
        ? (state.position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final barFraction = _dragFraction ?? playedFraction;

    final shownPosition = _dragFraction == null
        ? state.position
        : Duration(
            milliseconds: (total.inMilliseconds * _dragFraction!).round(),
          );

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.postPadding,
        right: AppSpacing.postPadding,
        top: AppSpacing.xs,
        bottom: MediaQuery.viewPaddingOf(context).bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            Center(
              child: Text(
                AppStrings.audioNowPlaying,
                style: AppTypography.heading(color: primaryColor),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Big Avatar / Album art
            Center(
              child: track.channelTitle != null
                  ? ChannelAvatar(
                      title: track.channelTitle!,
                      avatarPath: track.channelAvatarUrl,
                      avatarFileId: track.channelAvatarFileId,
                      avatarColorHex: track.channelAvatarColor,
                      radius: 54,
                    )
                  : Container(
                      width: 108,
                      height: 108,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        track.isVoice
                            ? Icons.mic_rounded
                            : Icons.music_note_rounded,
                        color: AppColors.accent,
                        size: 48,
                      ),
                    ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Track name & Channel
            Text(
              track.title,
              style: AppTypography.heading(color: primaryColor),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (track.channelTitle != null) ...[
              const SizedBox(height: 4),
              Text(
                track.channelTitle!,
                style: AppTypography.subheading(color: secondaryColor),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),

            // Scrubber
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.accent,
                inactiveTrackColor: theme.dividerColor.withValues(alpha: 0.3),
                thumbColor: AppColors.accent,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                trackHeight: 3.5,
              ),
              child: Slider(
                value: barFraction,
                onChanged: (val) => setState(() => _dragFraction = val),
                onChangeEnd: (val) {
                  final target = Duration(
                    milliseconds: (total.inMilliseconds * val).round(),
                  );
                  ref.read(audioPlayerProvider.notifier).seekTo(target);
                  setState(() => _dragFraction = null);
                },
              ),
            ),

            // Time stamps
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    TimeUtils.formatDuration(shownPosition.inSeconds),
                    style: AppTypography.actionCount(color: secondaryColor),
                  ),
                  Text(
                    TimeUtils.formatDuration(total.inSeconds),
                    style: AppTypography.actionCount(color: secondaryColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Playback controls row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Speed pill button
                InkWell(
                  onTap: () => _cycleSpeed(state.speed),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.dividerColor.withValues(alpha: 0.4),
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      AppStrings.audioSpeedLabel(state.speed),
                      style: AppTypography.actionCount(
                        color: primaryColor,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                // Rewind 15s
                IconButton(
                  icon: const Icon(Icons.replay_10_rounded),
                  iconSize: 28,
                  tooltip: AppStrings.audioSkipBack15,
                  color: primaryColor,
                  onPressed: () =>
                      ref.read(audioPlayerProvider.notifier).skipBack15(),
                ),

                // Previous track
                IconButton(
                  icon: const Icon(Icons.skip_previous_rounded),
                  iconSize: 32,
                  tooltip: AppStrings.audioPreviousTrack,
                  color: state.hasPrevious
                      ? primaryColor
                      : secondaryColor.withValues(alpha: 0.4),
                  onPressed: state.hasPrevious
                      ? () => ref
                            .read(audioPlayerProvider.notifier)
                            .skipPrevious()
                      : null,
                ),

                // Main Play/Pause circular button
                Material(
                  color: AppColors.accent,
                  shape: const CircleBorder(),
                  elevation: 4,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () =>
                        ref.read(audioPlayerProvider.notifier).togglePlay(),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: state.isBuffering
                          ? const SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              state.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 32,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),

                // Next track
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded),
                  iconSize: 32,
                  tooltip: AppStrings.audioNextTrack,
                  color: state.hasNext
                      ? primaryColor
                      : secondaryColor.withValues(alpha: 0.4),
                  onPressed: state.hasNext
                      ? () => ref.read(audioPlayerProvider.notifier).skipNext()
                      : null,
                ),

                // Fast Forward 30s
                IconButton(
                  icon: const Icon(Icons.forward_30_rounded),
                  iconSize: 28,
                  tooltip: AppStrings.audioSkipForward30,
                  color: primaryColor,
                  onPressed: () =>
                      ref.read(audioPlayerProvider.notifier).skipForward30(),
                ),
              ],
            ),

            // Queue section if more than 1 track
            if (state.queue.length > 1) ...[
              const SizedBox(height: AppSpacing.xl),
              Text(
                AppStrings.audioQueue,
                style: AppTypography.subheading(color: primaryColor),
              ),
              const SizedBox(height: AppSpacing.sm),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.queue.length,
                itemBuilder: (context, index) {
                  final qTrack = state.queue[index];
                  final isCurrent = index == state.currentIndex;

                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      isCurrent
                          ? Icons.volume_up_rounded
                          : Icons.music_note_rounded,
                      color: isCurrent ? AppColors.accent : secondaryColor,
                      size: 20,
                    ),
                    title: Text(
                      qTrack.title,
                      style:
                          AppTypography.body(
                            color: isCurrent ? AppColors.accent : primaryColor,
                          ).copyWith(
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: qTrack.channelTitle != null
                        ? Text(
                            qTrack.channelTitle!,
                            style: AppTypography.actionCount(
                              color: secondaryColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    trailing: Text(
                      TimeUtils.formatDuration(qTrack.durationSeconds),
                      style: AppTypography.actionCount(color: secondaryColor),
                    ),
                    onTap: () => ref
                        .read(audioPlayerProvider.notifier)
                        .playTrack(qTrack, queue: state.queue),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
