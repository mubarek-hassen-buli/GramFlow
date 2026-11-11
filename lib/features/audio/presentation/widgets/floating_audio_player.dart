import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/audio/presentation/audio_player_notifier.dart';
import 'package:gramx/features/audio/presentation/widgets/audio_now_playing_sheet.dart';

/// Floating mini-player docked above the bottom navigation bar.
class FloatingAudioPlayer extends ConsumerWidget {
  const FloatingAudioPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioPlayerProvider);
    final track = state.currentTrack;

    if (track == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.onSurface;
    final secondaryColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final total = state.duration;
    final progress = total > Duration.zero
        ? (state.position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(14),
        color: isDark ? AppColors.darkSurface : AppColors.lightSurfaceVariant,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => AudioNowPlayingSheet.show(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      // Avatar / Music icon
                      if (track.channelTitle != null)
                        ChannelAvatar(
                          title: track.channelTitle!,
                          avatarPath: track.channelAvatarUrl,
                          avatarFileId: track.channelAvatarFileId,
                          avatarColorHex: track.channelAvatarColor,
                          radius: 18,
                        )
                      else
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            track.isVoice
                                ? Icons.mic_rounded
                                : Icons.music_note_rounded,
                            color: AppColors.accent,
                            size: 20,
                          ),
                        ),
                      const SizedBox(width: AppSpacing.sm),

                      // Track and channel title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              track.title,
                              style: AppTypography.subheading(
                                color: primaryColor,
                              ).copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (track.channelTitle != null)
                              Text(
                                track.channelTitle!,
                                style: AppTypography.actionCount(
                                  color: secondaryColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),

                      // Play/Pause button
                      IconButton(
                        icon: state.isBuffering
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.accent,
                                ),
                              )
                            : Icon(
                                state.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: primaryColor,
                                size: 28,
                              ),
                        tooltip: state.isPlaying
                            ? AppStrings.audioPause
                            : AppStrings.audioPlay,
                        onPressed: () =>
                            ref.read(audioPlayerProvider.notifier).togglePlay(),
                      ),

                      // Close button
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: secondaryColor,
                          size: 20,
                        ),
                        tooltip: AppStrings.audioClose,
                        onPressed: () =>
                            ref.read(audioPlayerProvider.notifier).stop(),
                      ),
                    ],
                  ),
                ),

                // Mini progress line
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 2.5,
                  backgroundColor: theme.dividerColor.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
