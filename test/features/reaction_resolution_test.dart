import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/widgets/reaction_control.dart';
import 'package:gramx/features/feed/presentation/widgets/reaction_overlay.dart';
import 'package:gramx/infrastructure/telegram/available_reactions_resolver.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';
import 'package:handy_tdlib/api.dart' as td;

import '../support/td_fixtures.dart';

td.AvailableReaction _emoji(String emoji) => td.AvailableReaction(
  type: td.ReactionTypeEmoji(emoji: emoji),
  needsPremium: false,
);

td.AvailableReaction _custom(int id) => td.AvailableReaction(
  type: td.ReactionTypeCustomEmoji(customEmojiId: id),
  needsPremium: true,
);

const td.AvailableReaction _paid = td.AvailableReaction(
  type: td.ReactionTypePaid(),
  needsPremium: false,
);

td.AvailableReactions _available({
  List<td.AvailableReaction> top = const [],
  List<td.AvailableReaction> recent = const [],
  List<td.AvailableReaction> popular = const [],
}) => td.AvailableReactions(
  topReactions: top,
  recentReactions: recent,
  popularReactions: popular,
  allowCustomEmoji: false,
  areTags: false,
  unavailabilityReason: null,
);

class _ReactionsTdlib implements TdlibService {
  final List<td.TdFunction> requests = [];
  bool failMessageReactions = false;
  bool hydratePopulatesReactions = false;
  bool _hydrated = false;
  td.AvailableReactions response = _available();

  @override
  Future<td.TdObject> sendRequest(
    td.TdFunction function, {
    String? extraId,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    requests.add(function);
    if (function is td.GetMessageAvailableReactions) {
      if (failMessageReactions) {
        throw const TdlibRequestException(500, 'Network failure');
      }
      if (hydratePopulatesReactions && _hydrated) {
        return _available(top: [_emoji('👍'), _emoji('🔥')]);
      }
      return response;
    }
    if (function is td.GetChat) {
      return TdFixtures.chat(id: function.chatId);
    }
    if (function is td.GetSupergroupFullInfo) {
      _hydrated = true;
      return const td.Ok();
    }
    throw UnimplementedError('Unexpected ${function.runtimeType}');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

class _FakeFeedRepository implements FeedRepository {
  AvailableReactionsResult result;
  ({int chatId, int messageId})? lastRequested;

  _FakeFeedRepository(this.result);

  @override
  Future<AvailableReactionsResult> getAvailableReactions(
    int chatId, {
    required int messageId,
    int rowSize = defaultReactionRowSize,
  }) async {
    lastRequested = (chatId: chatId, messageId: messageId);
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

Post _samplePost() => Post(
  id: '-100123_42',
  chatId: -100123,
  channelId: '-100123',
  messageId: 42,
  channelTitle: 'GramFlow News',
  publishedAt: DateTime(2026, 11, 1),
);

void main() {
  group('classifyAvailableReactions', () {
    test(
      'returns AvailableReactionsAllowed with deduplicated standard emojis',
      () {
        final result = classifyAvailableReactions(
          _available(
            top: [_emoji('👍'), _custom(100), _emoji('❤️')],
            recent: [_emoji('👍'), _paid, _emoji('🔥')],
            popular: [_emoji('🎉')],
          ),
        );

        expect(result, isA<AvailableReactionsAllowed>());
        expect((result as AvailableReactionsAllowed).emojis, [
          '👍',
          '❤️',
          '🔥',
          '🎉',
        ]);
      },
    );

    test(
      'returns AvailableReactionsCustomOnly when only custom or paid reactions exist',
      () {
        final result = classifyAvailableReactions(
          _available(top: [_custom(101), _paid]),
        );

        expect(result, isA<AvailableReactionsCustomOnly>());
      },
    );

    test(
      'returns AvailableReactionsOff when Telegram returns zero reactions',
      () {
        final result = classifyAvailableReactions(_available());

        expect(result, isA<AvailableReactionsOff>());
      },
    );
  });

  group('resolveMessageAvailableReactions', () {
    test(
      'hydrates SupergroupFullInfo once on demand when initially empty',
      () async {
        final tdlib = _ReactionsTdlib()..hydratePopulatesReactions = true;
        final hydrated = <int>{};

        final first = await resolveMessageAvailableReactions(
          tdlib,
          chatId: -100999,
          messageId: 10,
          hydratedSupergroups: hydrated,
        );

        expect(first, isA<AvailableReactionsAllowed>());
        expect((first as AvailableReactionsAllowed).emojis, ['👍', '🔥']);
        expect(
          tdlib.requests.whereType<td.GetSupergroupFullInfo>().length,
          1,
          reason: 'hydrates channel full info on first empty response',
        );

        // A second post in the same channel should not re-fetch SupergroupFullInfo.
        tdlib.hydratePopulatesReactions = false;
        tdlib.response = _available();
        final second = await resolveMessageAvailableReactions(
          tdlib,
          chatId: -100999,
          messageId: 11,
          hydratedSupergroups: hydrated,
        );

        expect(second, isA<AvailableReactionsOff>());
        expect(
          tdlib.requests.whereType<td.GetSupergroupFullInfo>().length,
          1,
          reason: 'supergroup full info is only fetched once per session',
        );
      },
    );

    test('returns AvailableReactionsFailed when the request throws', () async {
      final tdlib = _ReactionsTdlib()..failMessageReactions = true;

      final result = await resolveMessageAvailableReactions(
        tdlib,
        chatId: -100123,
        messageId: 42,
      );

      expect(result, isA<AvailableReactionsFailed>());
    });
  });

  group('ReactionControl widget states', () {
    Future<void> pumpControl(
      WidgetTester tester,
      _FakeFeedRepository repo,
      ValueChanged<String> onSelected,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [feedRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: ReactionControl(
                  post: _samplePost(),
                  color: Colors.grey,
                  onSelectReaction: onSelected,
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('opens picker when standard emojis are allowed', (
      tester,
    ) async {
      final repo = _FakeFeedRepository(
        const AvailableReactionsAllowed(['👍', '❤️', '🔥']),
      );
      String? picked;

      await pumpControl(tester, repo, (emoji) => picked = emoji);
      await tester.tap(find.byType(ReactionControl));
      await tester.pumpAndSettle();

      expect(repo.lastRequested, (chatId: -100123, messageId: 42));
      expect(find.text('👍'), findsOneWidget);
      expect(find.text('🔥'), findsOneWidget);

      await tester.tap(find.text('🔥'));
      await tester.pumpAndSettle();
      expect(picked, '🔥');
    });

    testWidgets('shows reactionsOff when Telegram returns zero reactions', (
      tester,
    ) async {
      final repo = _FakeFeedRepository(const AvailableReactionsOff());

      await pumpControl(tester, repo, (_) {});
      await tester.tap(find.byType(ReactionControl));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.reactionsOff), findsOneWidget);
    });

    testWidgets(
      'shows reactionsCustomOnly when only Premium or custom reactions are allowed',
      (tester) async {
        final repo = _FakeFeedRepository(const AvailableReactionsCustomOnly());

        await pumpControl(tester, repo, (_) {});
        await tester.tap(find.byType(ReactionControl));
        await tester.pumpAndSettle();

        expect(find.text(AppStrings.reactionsCustomOnly), findsOneWidget);
      },
    );

    testWidgets('shows reactionFailed when the request fails', (tester) async {
      final repo = _FakeFeedRepository(const AvailableReactionsFailed());

      await pumpControl(tester, repo, (_) {});
      await tester.tap(find.byType(ReactionControl));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.reactionFailed), findsOneWidget);
    });
  });

  group('ReactionOverlay widget states', () {
    Future<void> pumpOverlay(
      WidgetTester tester,
      _FakeFeedRepository repo,
      ValueChanged<String> onSelected,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [feedRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: ReactionOverlay(
                  chatId: -100123,
                  messageId: 42,
                  onEmojiSelected: onSelected,
                  child: const SizedBox(width: 80, height: 40),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('opens overlay when standard emojis are allowed', (
      tester,
    ) async {
      final repo = _FakeFeedRepository(
        const AvailableReactionsAllowed(['👍', '🎉']),
      );
      String? picked;

      await pumpOverlay(tester, repo, (emoji) => picked = emoji);
      await tester.longPress(find.byType(ReactionOverlay));
      await tester.pumpAndSettle();

      expect(repo.lastRequested, (chatId: -100123, messageId: 42));
      expect(find.text('🎉'), findsOneWidget);

      await tester.tap(find.text('🎉'));
      await tester.pumpAndSettle();
      expect(picked, '🎉');
    });

    testWidgets('shows reactionsOff when Telegram returns zero reactions', (
      tester,
    ) async {
      final repo = _FakeFeedRepository(const AvailableReactionsOff());

      await pumpOverlay(tester, repo, (_) {});
      await tester.longPress(find.byType(ReactionOverlay));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.reactionsOff), findsOneWidget);
    });

    testWidgets(
      'shows reactionsCustomOnly when only Premium or custom reactions are allowed',
      (tester) async {
        final repo = _FakeFeedRepository(const AvailableReactionsCustomOnly());

        await pumpOverlay(tester, repo, (_) {});
        await tester.longPress(find.byType(ReactionOverlay));
        await tester.pumpAndSettle();

        expect(find.text(AppStrings.reactionsCustomOnly), findsOneWidget);
      },
    );

    testWidgets('shows reactionFailed when the request fails', (tester) async {
      final repo = _FakeFeedRepository(const AvailableReactionsFailed());

      await pumpOverlay(tester, repo, (_) {});
      await tester.longPress(find.byType(ReactionOverlay));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.reactionFailed), findsOneWidget);
    });
  });
}
