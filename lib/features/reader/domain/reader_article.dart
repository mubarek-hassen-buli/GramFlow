import 'package:flutter/foundation.dart';
import 'package:gramx/features/feed/domain/media_item.dart';
import 'package:gramx/features/feed/domain/text_entity.dart';

/// One section of an article (corresponds to one post or thread entry).
@immutable
class ReaderSection {
  final int messageId;
  final String text;
  final List<TextEntity> entities;
  final List<MediaItem> media;
  final DateTime publishedAt;
  final int wordCount;

  const ReaderSection({
    required this.messageId,
    required this.text,
    required this.entities,
    required this.media,
    required this.publishedAt,
    required this.wordCount,
  });
}

/// Unified long-read article stitched from a single post or a thread.
@immutable
class ReaderArticle {
  final String id;
  final int chatId;
  final String channelTitle;
  final String? channelUsername;
  final String? channelAvatarUrl;
  final int? channelAvatarFileId;
  final String? channelAvatarColor;
  final List<ReaderSection> sections;
  final int totalWordCount;
  final int estimatedReadMinutes;
  final bool isBookmarked;
  final DateTime publishedAt;

  const ReaderArticle({
    required this.id,
    required this.chatId,
    required this.channelTitle,
    this.channelUsername,
    this.channelAvatarUrl,
    this.channelAvatarFileId,
    this.channelAvatarColor,
    required this.sections,
    required this.totalWordCount,
    required this.estimatedReadMinutes,
    required this.isBookmarked,
    required this.publishedAt,
  });

  bool get isThread => sections.length > 1;

  ReaderArticle copyWith({
    String? id,
    int? chatId,
    String? channelTitle,
    String? channelUsername,
    String? channelAvatarUrl,
    int? channelAvatarFileId,
    String? channelAvatarColor,
    List<ReaderSection>? sections,
    int? totalWordCount,
    int? estimatedReadMinutes,
    bool? isBookmarked,
    DateTime? publishedAt,
  }) {
    return ReaderArticle(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      channelTitle: channelTitle ?? this.channelTitle,
      channelUsername: channelUsername ?? this.channelUsername,
      channelAvatarUrl: channelAvatarUrl ?? this.channelAvatarUrl,
      channelAvatarFileId: channelAvatarFileId ?? this.channelAvatarFileId,
      channelAvatarColor: channelAvatarColor ?? this.channelAvatarColor,
      sections: sections ?? this.sections,
      totalWordCount: totalWordCount ?? this.totalWordCount,
      estimatedReadMinutes: estimatedReadMinutes ?? this.estimatedReadMinutes,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      publishedAt: publishedAt ?? this.publishedAt,
    );
  }
}
