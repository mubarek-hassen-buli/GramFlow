import 'dart:math' as math;
import 'package:gramx/features/feed/domain/feed_thread.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/reader/domain/reader_article.dart';

/// Transforms posts and threads into structured editorial articles for Reader Mode.
class ReaderArticleBuilder {
  const ReaderArticleBuilder._();

  /// Standard words per minute reading speed.
  static const int wordsPerMinute = 200;

  /// Counts the words in [text], ignoring multiple spaces and line breaks.
  static int countWords(String? text) {
    if (text == null || text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
  }

  /// Calculates reading time in minutes based on total word count.
  /// Always returns at least 1 minute for any non-empty content.
  static int calculateReadMinutes(int wordCount) {
    if (wordCount <= 0) return 1;
    return math.max(1, (wordCount / wordsPerMinute).ceil());
  }

  /// Builds a [ReaderArticle] from a single [Post].
  static ReaderArticle fromPost(Post post) {
    final text = post.text ?? '';
    final words = countWords(text);
    final readMinutes = calculateReadMinutes(words);

    final section = ReaderSection(
      messageId: post.messageId,
      text: text,
      entities: post.entities,
      media: post.media,
      publishedAt: post.publishedAt,
      wordCount: words,
    );

    return ReaderArticle(
      id: post.id,
      chatId: post.chatId,
      channelTitle: post.channelTitle,
      channelUsername: post.channelUsername,
      channelAvatarUrl: post.channelAvatarUrl,
      channelAvatarFileId: post.channelAvatarFileId,
      channelAvatarColor: post.channelAvatarColor,
      sections: [section],
      totalWordCount: words,
      estimatedReadMinutes: readMinutes,
      isBookmarked: post.isBookmarked,
      publishedAt: post.publishedAt,
    );
  }

  /// Builds a stitched multi-part [ReaderArticle] from a [FeedThread].
  static ReaderArticle fromThread(FeedThread thread) {
    final root = thread.root;
    final posts = thread.allPosts;

    final sections = <ReaderSection>[];
    var totalWords = 0;

    for (final post in posts) {
      final text = post.text ?? '';
      final words = countWords(text);
      totalWords += words;

      sections.add(
        ReaderSection(
          messageId: post.messageId,
          text: text,
          entities: post.entities,
          media: post.media,
          publishedAt: post.publishedAt,
          wordCount: words,
        ),
      );
    }

    final readMinutes = calculateReadMinutes(totalWords);

    return ReaderArticle(
      id: root.id,
      chatId: root.chatId,
      channelTitle: root.channelTitle,
      channelUsername: root.channelUsername,
      channelAvatarUrl: root.channelAvatarUrl,
      channelAvatarFileId: root.channelAvatarFileId,
      channelAvatarColor: root.channelAvatarColor,
      sections: sections,
      totalWordCount: totalWords,
      estimatedReadMinutes: readMinutes,
      isBookmarked: root.isBookmarked || posts.any((p) => p.isBookmarked),
      publishedAt: root.publishedAt,
    );
  }
}
