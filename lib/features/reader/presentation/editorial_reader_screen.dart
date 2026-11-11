import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/time/time_utils.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/core/widgets/text_entity_renderer.dart';
import 'package:gramx/features/bookmarks/presentation/bookmark_providers.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/domain/feed_thread.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/widgets/post_media_grid.dart';
import 'package:gramx/features/guest/data/guest_post_mapper.dart';
import 'package:gramx/core/telegram/telegram_ids.dart';
import 'package:gramx/features/reader/domain/reader_article.dart';
import 'package:gramx/features/reader/domain/reader_settings.dart';
import 'package:gramx/features/reader/domain/reader_theme.dart';
import 'package:gramx/features/reader/presentation/reader_settings_notifier.dart';
import 'package:gramx/features/reader/presentation/widgets/reader_progress_bar.dart';
import 'package:gramx/features/reader/presentation/widgets/reader_settings_sheet.dart';

/// Distraction-free, long-form editorial reading canvas for Telegram channel posts and threads.
class EditorialReaderScreen extends ConsumerStatefulWidget {
  final ReaderArticle article;
  final Post? post;
  final FeedThread? thread;

  const EditorialReaderScreen({
    super.key,
    required this.article,
    this.post,
    this.thread,
  });

  @override
  ConsumerState<EditorialReaderScreen> createState() =>
      _EditorialReaderScreenState();
}

class _EditorialReaderScreenState extends ConsumerState<EditorialReaderScreen> {
  late final ScrollController _scrollController;
  double _progress = 0.0;
  late bool _isBookmarked;

  @override
  void initState({double? progress}) {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _isBookmarked = widget.article.isBookmarked;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    if (maxScroll > 0) {
      final newProgress = (current / maxScroll).clamp(0.0, 1.0);
      if ((newProgress - _progress).abs() > 0.01) {
        setState(() {
          _progress = newProgress;
        });
      }
    }
  }

  Future<void> _toggleBookmark() async {
    final nextState = !_isBookmarked;
    setState(() {
      _isBookmarked = nextState;
    });

    final post = widget.post ?? widget.thread?.root;
    if (post != null) {
      await ref
          .read(bookmarkControllerProvider.notifier)
          .set(post, bookmarked: nextState);
    } else {
      await ref
          .read(feedRepositoryProvider)
          .setBookmarked(
            widget.article.chatId,
            widget.article.sections.first.messageId,
            bookmarked: nextState,
          );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nextState
              ? AppStrings.readerBookmarked
              : AppStrings.readerUnbookmarked,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _shareArticle() async {
    final post = widget.post ?? widget.thread?.root;
    String? link;
    if (post != null) {
      if (GuestPostMapper.isSynthetic(post.chatId)) {
        link = GuestPostMapper.postLink(post);
      } else {
        link =
            await ref.read(feedRepositoryProvider).postLink(post) ??
            TelegramIds.postLink(
              chatId: post.chatId,
              messageId: post.messageId,
              username: post.channelUsername,
            );
      }
    }

    final shareText = link ?? widget.article.channelTitle;
    await Clipboard.setData(ClipboardData(text: shareText));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(AppStrings.postLinkCopied),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readerSettingsProvider);
    final theme = settings.theme;
    final article = widget.article;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: theme.brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: theme.backgroundColor,
        appBar: AppBar(
          backgroundColor: theme.backgroundColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: theme.primaryTextColor),
            tooltip: AppStrings.readerClose,
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            article.channelTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.primaryTextColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isBookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: _isBookmarked
                    ? const Color(0xFF1D9BF0)
                    : theme.secondaryTextColor,
              ),
              tooltip: AppStrings.readerToggleBookmark,
              onPressed: _toggleBookmark,
            ),
            IconButton(
              icon: Icon(Icons.share_outlined, color: theme.secondaryTextColor),
              tooltip: AppStrings.readerShare,
              onPressed: _shareArticle,
            ),
            IconButton(
              icon: Icon(
                Icons.text_format_rounded,
                color: theme.secondaryTextColor,
              ),
              tooltip: AppStrings.readerSettings,
              onPressed: () => showReaderSettingsSheet(context),
            ),
          ],
          bottom: settings.showProgressBar
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2.5),
                  child: ReaderProgressBar(
                    progress: _progress,
                    color: const Color(0xFF1D9BF0),
                    backgroundColor: theme.dividerColor.withValues(alpha: 0.3),
                  ),
                )
              : null,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Channel Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ChannelAvatar(
                        title: article.channelTitle,
                        avatarPath: article.channelAvatarUrl,
                        avatarFileId: article.channelAvatarFileId,
                        avatarColorHex: article.channelAvatarColor,
                        radius: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              article.channelTitle,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: theme.primaryTextColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (article.channelUsername != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                AppStrings.handle(article.channelUsername!),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.secondaryTextColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Reading metadata
                  Row(
                    children: [
                      Text(
                        AppStrings.readerModeBadge(
                          article.estimatedReadMinutes,
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.secondaryTextColor,
                        ),
                      ),
                      Text(
                        AppStrings.inlineSeparator,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.secondaryTextColor,
                        ),
                      ),
                      Text(
                        AppStrings.readerModeWordCount(article.totalWordCount),
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.secondaryTextColor,
                        ),
                      ),
                      Text(
                        AppStrings.inlineSeparator,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.secondaryTextColor,
                        ),
                      ),
                      Text(
                        TimeUtils.shortDate(article.publishedAt),
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: theme.dividerColor, height: 1, thickness: 1),
                  const SizedBox(height: 24),

                  // Stitched article sections
                  for (var i = 0; i < article.sections.length; i++) ...[
                    _buildSection(
                      context,
                      section: article.sections[i],
                      index: i,
                      total: article.sections.length,
                      settings: settings,
                      theme: theme,
                    ),
                    if (i < article.sections.length - 1) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                          child: Text(
                            '❖',
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.dividerColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],

                  // End ornament
                  Padding(
                    padding: const EdgeInsets.only(top: 48, bottom: 24),
                    child: Center(
                      child: Text(
                        '• • •',
                        style: TextStyle(
                          fontSize: 18,
                          letterSpacing: 6,
                          color: theme.secondaryTextColor.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required ReaderSection section,
    required int index,
    required int total,
    required ReaderSettings settings,
    required ReaderTheme theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (total > 1) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              AppStrings.readerThreadSection(index + 1, total).toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: theme.secondaryTextColor,
              ),
            ),
          ),
        ],

        // Media items
        if (section.media.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: PostMediaGrid(
                media: section.media,
                post: widget.post,
                maxVisualHeight: 420,
              ),
            ),
          ),
        ],

        // Editorial prose
        if (section.text.isNotEmpty)
          TextEntityRenderer(
            text: section.text,
            entities: section.entities,
            selectable: true,
            linkColor: const Color(0xFF1D9BF0),
            style: settings.font.style(
              fontSize: settings.fontSize,
              lineHeight: settings.lineHeight,
              color: theme.primaryTextColor,
            ),
          ),
      ],
    );
  }
}
