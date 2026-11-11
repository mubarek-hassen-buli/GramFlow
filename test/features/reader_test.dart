import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/feed/domain/feed_thread.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/reader/data/reader_article_builder.dart';
import 'package:gramx/features/reader/domain/reader_theme.dart';
import 'package:gramx/features/reader/presentation/editorial_reader_screen.dart';
import 'package:gramx/features/reader/presentation/reader_settings_notifier.dart';
import 'package:gramx/features/reader/presentation/widgets/reader_badge.dart';
import 'package:gramx/features/reader/presentation/widgets/reader_progress_bar.dart';
import 'package:gramx/features/reader/presentation/widgets/reader_settings_sheet.dart';

void main() {
  final samplePost1 = Post(
    id: 'post_101',
    chatId: 12345,
    channelId: 'telegram_tech',
    messageId: 101,
    channelTitle: 'Telegram Tech News',
    channelUsername: 'tele_tech',
    text:
        'Telegram is rolling out a massive new update today featuring major improvements '
        'to channel management, custom feeds, audio podcast playback, and full editorial reader mode. '
        'This architectural overhaul allows subscribers to read long articles in distraction-free serenity.',
    publishedAt: DateTime(2026, 11, 7, 14, 30),
    isBookmarked: false,
  );

  final samplePost2 = Post(
    id: 'post_102',
    chatId: 12345,
    channelId: 'telegram_tech',
    messageId: 102,
    channelTitle: 'Telegram Tech News',
    channelUsername: 'tele_tech',
    text:
        'Part 2 continues the exploration into high-performance local SQLite caching, '
        'optimistic feed updates, and elegant typography rendering across multiple platforms.',
    publishedAt: DateTime(2026, 11, 7, 14, 35),
    replyToMessageId: 101,
  );

  group('ReaderArticleBuilder unit tests', () {
    test('countWords accurately counts words ignoring spacing', () {
      expect(ReaderArticleBuilder.countWords(null), 0);
      expect(ReaderArticleBuilder.countWords(''), 0);
      expect(ReaderArticleBuilder.countWords('   \n  \t '), 0);
      expect(ReaderArticleBuilder.countWords('Hello world'), 2);
      expect(
        ReaderArticleBuilder.countWords('  Flutter   Riverpod \n TDLib\t '),
        3,
      );
    });

    test('calculateReadMinutes calculates 200 WPM estimation', () {
      expect(ReaderArticleBuilder.calculateReadMinutes(0), 1);
      expect(ReaderArticleBuilder.calculateReadMinutes(50), 1);
      expect(ReaderArticleBuilder.calculateReadMinutes(200), 1);
      expect(ReaderArticleBuilder.calculateReadMinutes(201), 2);
      expect(ReaderArticleBuilder.calculateReadMinutes(600), 3);
    });

    test('fromPost constructs a valid ReaderArticle', () {
      final article = ReaderArticleBuilder.fromPost(samplePost1);

      expect(article.id, 'post_101');
      expect(article.channelTitle, 'Telegram Tech News');
      expect(article.channelUsername, 'tele_tech');
      expect(article.sections.length, 1);
      expect(article.isThread, isFalse);
      expect(article.totalWordCount, greaterThan(20));
      expect(article.estimatedReadMinutes, greaterThanOrEqualTo(1));
    });

    test('fromThread stitches multi-part posts root-first', () {
      final thread = FeedThread(root: samplePost1, replies: [samplePost2]);

      final article = ReaderArticleBuilder.fromThread(thread);

      expect(article.id, 'post_101');
      expect(article.sections.length, 2);
      expect(article.isThread, isTrue);
      expect(
        article.totalWordCount,
        samplePost1.text!.split(' ').length +
            samplePost2.text!.split(' ').length,
      );
      expect(article.sections[0].messageId, 101);
      expect(article.sections[1].messageId, 102);
    });
  });

  group('ReaderSettingsNotifier unit tests', () {
    test('initial state defaults to Sepia, Serif, and 18.0 pt', () {
      final container = ProviderContainer();
      final state = container.read(readerSettingsProvider);

      expect(state.theme, ReaderTheme.sepia);
      expect(state.font, ReaderFont.serif);
      expect(state.fontSize, 18.0);
      expect(state.lineHeight, 1.65);
      expect(state.showProgressBar, isTrue);
    });

    test('setTheme and setFont update state properly', () {
      final container = ProviderContainer();
      final notifier = container.read(readerSettingsProvider.notifier);

      notifier.setTheme(ReaderTheme.dark);
      expect(container.read(readerSettingsProvider).theme, ReaderTheme.dark);

      notifier.setFont(ReaderFont.sans);
      expect(container.read(readerSettingsProvider).font, ReaderFont.sans);

      notifier.setFontSize(24.0);
      expect(container.read(readerSettingsProvider).fontSize, 24.0);

      notifier.setLineHeight(1.9);
      expect(container.read(readerSettingsProvider).lineHeight, 1.9);

      notifier.toggleProgressBar();
      expect(container.read(readerSettingsProvider).showProgressBar, isFalse);
    });

    test('fontSize clamps to valid range 14-28', () {
      final container = ProviderContainer();
      final notifier = container.read(readerSettingsProvider.notifier);

      notifier.setFontSize(10.0);
      expect(container.read(readerSettingsProvider).fontSize, 14.0);

      notifier.setFontSize(35.0);
      expect(container.read(readerSettingsProvider).fontSize, 28.0);
    });
  });

  group('Reader UI widget tests', () {
    testWidgets('ReaderBadge renders minutes and triggers tap', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderBadge(estimatedMinutes: 4, onTap: () => tapped = true),
          ),
        ),
      );

      expect(find.text(AppStrings.readerModeBadge(4)), findsOneWidget);
      await tester.tap(find.byType(ReaderBadge));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('ReaderProgressBar renders with progress', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReaderProgressBar(
              progress: 0.5,
              color: Colors.blue,
              backgroundColor: Colors.grey,
            ),
          ),
        ),
      );

      expect(find.byType(ReaderProgressBar), findsOneWidget);
    });

    testWidgets('ReaderSettingsSheet allows switching themes and fonts', (
      tester,
    ) async {
      final container = ProviderContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: ReaderSettingsSheet())),
        ),
      );

      expect(find.text(AppStrings.readerSettingsTitle), findsOneWidget);
      expect(find.text(AppStrings.readerThemePaper), findsOneWidget);
      expect(find.text(AppStrings.readerThemeDark), findsOneWidget);
      expect(find.text(AppStrings.readerFontSans), findsOneWidget);

      // Tap Dark theme
      await tester.tap(find.text(AppStrings.readerThemeDark));
      await tester.pumpAndSettle();

      expect(container.read(readerSettingsProvider).theme, ReaderTheme.dark);

      // Tap Sans font
      await tester.tap(find.text(AppStrings.readerFontSans));
      await tester.pumpAndSettle();

      expect(container.read(readerSettingsProvider).font, ReaderFont.sans);
    });

    testWidgets('EditorialReaderScreen renders article header and sections', (
      tester,
    ) async {
      final article = ReaderArticleBuilder.fromPost(samplePost1);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: EditorialReaderScreen(article: article)),
        ),
      );

      // Channel header
      expect(find.text('Telegram Tech News'), findsWidgets);
      expect(find.text(AppStrings.handle('tele_tech')), findsOneWidget);

      // Badge metadata
      expect(
        find.text(AppStrings.readerModeBadge(article.estimatedReadMinutes)),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.readerModeWordCount(article.totalWordCount)),
        findsOneWidget,
      );

      // Article body text
      expect(
        find.textContaining('Telegram is rolling out a massive new update'),
        findsOneWidget,
      );

      // End ornament
      expect(find.text('• • •'), findsOneWidget);
    });
  });
}
