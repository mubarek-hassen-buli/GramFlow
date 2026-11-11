import 'package:flutter/foundation.dart';

/// Immutable model representing an audio track or voice message.
@immutable
class AudioTrack {
  final String id;
  final String title;
  final String? localPath;
  final int durationSeconds;
  final bool isVoice;
  final String? channelTitle;
  final String? channelAvatarUrl;
  final int? channelAvatarFileId;
  final String? channelAvatarColor;

  const AudioTrack({
    required this.id,
    required this.title,
    required this.localPath,
    required this.durationSeconds,
    this.isVoice = false,
    this.channelTitle,
    this.channelAvatarUrl,
    this.channelAvatarFileId,
    this.channelAvatarColor,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioTrack &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          localPath == other.localPath;

  @override
  int get hashCode => id.hashCode ^ (localPath?.hashCode ?? 0);
}
