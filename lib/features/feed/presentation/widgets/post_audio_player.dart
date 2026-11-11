import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/features/audio/domain/audio_track.dart';
import 'package:gramx/features/audio/presentation/audio_player_notifier.dart';
import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/infrastructure/sync/sync_service.dart';
import 'package:gramx/infrastructure/telegram/file_download_provider.dart';

/// A voice message or music track. While downloading, the bar shows download
/// progress from `UpdateFile`; once downloaded, it synchronizes with the
/// global [audioPlayerProvider] so playback continues across the app.
class PostAudioPlayer extends ConsumerStatefulWidget {
  final MediaItem item;
  final String? channelTitle;
  final String? channelAvatarUrl;
  final int? channelAvatarFileId;
  final String? channelAvatarColor;

  const PostAudioPlayer({
    super.key,
    required this.item,
    this.channelTitle,
    this.channelAvatarUrl,
    this.channelAvatarFileId,
    this.channelAvatarColor,
  });

  @override
  ConsumerState<PostAudioPlayer> createState() => _PostAudioPlayerState();
}

class _PostAudioPlayerState extends ConsumerState<PostAudioPlayer> {
  /// The drag position as a fraction of the track, or null when not dragging.
  double? _scrubFraction;

  void _startDownload(int fileId) {
    ref
        .read(syncServiceProvider)
        .downloadFileWithPriority(fileId, priority: 32);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.onSurface;
    final secondaryColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final surfaceColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurfaceVariant;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final trackColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;

    final fileId = widget.item.fileId;
    FileDownloadProgressState? downloadState;

    if (fileId != null && fileId != 0) {
      downloadState = ref.watch(fileDownloadStatusProvider(fileId)).value;
    }
    final resolvedPath = downloadState?.localPath ?? widget.item.localPath;

    final isDownloaded =
        resolvedPath != null &&
        resolvedPath.isNotEmpty &&
        File(resolvedPath).existsSync();
    final progress = downloadState?.progress ?? 0.0;
    final isDownloading =
        downloadState != null &&
        !downloadState.isCompleted &&
        (progress > 0 || downloadState.downloadedSize > 0);

    final isVoice = widget.item.type == MediaType.voice;
    final title = isVoice
        ? AppStrings.mediaVoice
        : (widget.item.fileName ?? AppStrings.mediaAudio);

    final globalAudio = ref.watch(audioPlayerProvider);
    final isCurrentTrack = globalAudio.currentTrack?.id == widget.item.id;
    final isPlaying = isCurrentTrack && globalAudio.isPlaying;
    final isBuffering = isCurrentTrack && globalAudio.isBuffering;
    final position = isCurrentTrack ? globalAudio.position : Duration.zero;
    final total = isCurrentTrack && globalAudio.duration > Duration.zero
        ? globalAudio.duration
        : Duration(seconds: widget.item.duration);

    final playedFraction = total > Duration.zero
        ? (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final barFraction = _scrubFraction ?? playedFraction;
    final shownPosition = _scrubFraction == null
        ? position
        : Duration(
            milliseconds: (total.inMilliseconds * _scrubFraction!).round(),
          );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Row(
        children: [
          _TransportButton(
            isInitializing: isBuffering,
            isDownloading: isDownloading,
            isDownloaded: isDownloaded,
            isPlaying: isPlaying,
            progress: progress,
            onPressed: () {
              if (isDownloaded) {
                if (isCurrentTrack) {
                  ref.read(audioPlayerProvider.notifier).togglePlay();
                } else {
                  final track = AudioTrack(
                    id: widget.item.id,
                    title: title,
                    localPath: resolvedPath,
                    durationSeconds: widget.item.duration,
                    isVoice: isVoice,
                    channelTitle: widget.channelTitle,
                    channelAvatarUrl: widget.channelAvatarUrl,
                    channelAvatarFileId: widget.channelAvatarFileId,
                    channelAvatarColor: widget.channelAvatarColor,
                  );
                  ref.read(audioPlayerProvider.notifier).playTrack(track);
                }
              } else if (fileId != null && fileId != 0) {
                _startDownload(fileId);
              }
            },
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.body(
                    color: primaryColor,
                  ).copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (isDownloaded)
                  _Scrubber(
                    fraction: barFraction,
                    trackColor: trackColor,
                    onChanged: (value) =>
                        setState(() => _scrubFraction = value),
                    onChangeEnd: (value) {
                      if (isCurrentTrack) {
                        final target = Duration(
                          milliseconds:
                              (total.inMilliseconds * value.clamp(0.0, 1.0))
                                  .round(),
                        );
                        ref.read(audioPlayerProvider.notifier).seekTo(target);
                      }
                      setState(() => _scrubFraction = null);
                    },
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: isDownloading ? progress : 0,
                      minHeight: 4,
                      backgroundColor: trackColor,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.accent,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isDownloaded
                          ? '${TimeUtils.formatDuration(shownPosition.inSeconds)} / '
                                '${TimeUtils.formatDuration(total.inSeconds)}'
                          : TimeUtils.formatDuration(widget.item.duration),
                      style: AppTypography.actionCount(color: secondaryColor),
                    ),
                    Text(
                      isDownloading
                          ? AppStrings.downloadPercent((progress * 100).toInt())
                          : (isVoice
                                ? AppStrings.audioKindVoice
                                : AppStrings.audioKindAudio),
                      style: AppTypography.actionCount(color: secondaryColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The round button on the left: download, then play/pause.
class _TransportButton extends StatelessWidget {
  final bool isInitializing;
  final bool isDownloading;
  final bool isDownloaded;
  final bool isPlaying;
  final double progress;
  final VoidCallback onPressed;

  const _TransportButton({
    required this.isInitializing,
    required this.isDownloading,
    required this.isDownloaded,
    required this.isPlaying,
    required this.progress,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final label = !isDownloaded
        ? AppStrings.audioDownload
        : (isPlaying ? AppStrings.audioPause : AppStrings.audioPlay);

    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
            child: isInitializing
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : isDownloading
                ? Padding(
                    padding: const EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                      value: progress > 0 ? progress : null,
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    !isDownloaded
                        ? Icons.download_rounded
                        : (isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded),
                    color: Colors.white,
                    size: 26,
                  ),
          ),
        ),
      ),
    );
  }
}

/// The draggable position bar: a compact `Slider`, for its hit slop,
/// keyboard handling and accessibility actions.
class _Scrubber extends StatelessWidget {
  final double fraction;
  final Color trackColor;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _Scrubber({
    required this.fraction,
    required this.trackColor,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 4,
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: trackColor,
        thumbColor: AppColors.accent,
        overlayColor: AppColors.accent.withValues(alpha: 0.12),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        trackShape: const RoundedRectSliderTrackShape(),
      ),
      child: SizedBox(
        height: 20,
        child: Slider(
          value: fraction.clamp(0.0, 1.0),
          label: AppStrings.audioSeek,
          semanticFormatterCallback: (value) =>
              AppStrings.downloadPercent((value * 100).round()),
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ),
    );
  }
}
