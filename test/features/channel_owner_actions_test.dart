import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/app/theme/app_theme.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/channels/data/channel_repository.dart';
import 'package:gramx/features/channels/domain/channel.dart';
import 'package:gramx/features/channels/presentation/widgets/channel_header.dart';
import 'package:gramx/features/channels/presentation/widgets/edit_channel_sheet.dart';
import 'package:gramx/infrastructure/telegram/tdlib_mappers.dart';

import '../support/td_fixtures.dart';

class FakeChannelRepository implements ChannelRepository {
  String? inviteLink = 'https://t.me/test_invite_link';
  String? updatedTitle;
  String? updatedDescription;
  String? updatedPhoto;
  bool updateTitleSuccess = true;
  bool updateDescriptionSuccess = true;
  bool updatePhotoSuccess = true;

  @override
  Future<String?> getChannelInviteLink(int chatId, {String? username}) async {
    return inviteLink;
  }

  @override
  Future<bool> updateChannelTitle(int chatId, String title) async {
    updatedTitle = title;
    return updateTitleSuccess;
  }

  @override
  Future<bool> updateChannelDescription(int chatId, String description) async {
    updatedDescription = description;
    return updateDescriptionSuccess;
  }

  @override
  Future<bool> updateChannelPhoto(int chatId, String photoPath) async {
    updatedPhoto = photoPath;
    return updatePhotoSuccess;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('TdlibMappers.mapChatToChannel permissions', () {
    test('maps channel creator as owner and postable', () {
      final chat = TdFixtures.chat(id: -100123, mainOrder: 10);
      final supergroup = TdFixtures.supergroup(
        id: 123,
        isChannel: true,
        status: TdFixtures.creatorStatus(),
      ).supergroup;

      final channel = TdlibMappers.mapChatToChannel(
        chat,
        supergroup: supergroup,
      );

      expect(channel.isOwner, isTrue);
      expect(channel.isAdmin, isFalse);
      expect(channel.canPost, isTrue);
    });

    test('maps channel admin with posting rights as admin and postable', () {
      final chat = TdFixtures.chat(id: -100123, mainOrder: 10);
      final supergroup = TdFixtures.supergroup(
        id: 123,
        isChannel: true,
        status: TdFixtures.adminStatus(canPostMessages: true),
      ).supergroup;

      final channel = TdlibMappers.mapChatToChannel(
        chat,
        supergroup: supergroup,
      );

      expect(channel.isOwner, isFalse);
      expect(channel.isAdmin, isTrue);
      expect(channel.canPost, isTrue);
    });

    test('maps channel admin without posting rights as not postable', () {
      final chat = TdFixtures.chat(id: -100123, mainOrder: 10);
      final supergroup = TdFixtures.supergroup(
        id: 123,
        isChannel: true,
        status: TdFixtures.adminStatus(canPostMessages: false),
      ).supergroup;

      final channel = TdlibMappers.mapChatToChannel(
        chat,
        supergroup: supergroup,
      );

      expect(channel.isOwner, isFalse);
      expect(channel.isAdmin, isTrue);
      expect(channel.canPost, isFalse);
    });

    test('regular member cannot post and is neither owner nor admin', () {
      final chat = TdFixtures.chat(id: -100123, mainOrder: 10);
      final supergroup = TdFixtures.supergroup(
        id: 123,
        isChannel: true,
      ).supergroup;

      final channel = TdlibMappers.mapChatToChannel(
        chat,
        supergroup: supergroup,
      );

      expect(channel.isOwner, isFalse);
      expect(channel.isAdmin, isFalse);
      expect(channel.canPost, isFalse);
    });
  });

  group('ChannelCover Post button vs Join button', () {
    testWidgets('renders Post button when canPost is true', (tester) async {
      var postPressed = false;
      const channel = Channel(
        id: '123',
        chatId: 123,
        title: 'My Channel',
        canPost: true,
        isOwner: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              controller: ScrollController(),
              child: ChannelCover(
                channel: channel,
                geometry: const ChannelProfileGeometry(0),
                scroll: ScrollController(),
                isMuted: false,
                muteTooltip: 'Mute',
                onMutePressed: () {},
                onSharePressed: null,
                isActionBusy: false,
                onJoinPressed: () {},
                onPostPressed: () => postPressed = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text(AppStrings.channelPostAction), findsOneWidget);
      expect(find.text(AppStrings.channelJoinedAction), findsNothing);
      expect(find.text(AppStrings.channelJoinAction), findsNothing);

      await tester.tap(find.text(AppStrings.channelPostAction));
      expect(postPressed, isTrue);
    });

    testWidgets('renders Joined button when canPost is false and joined', (
      tester,
    ) async {
      const channel = Channel(
        id: '123',
        chatId: 123,
        title: 'Someone else channel',
        canPost: false,
        isJoined: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              controller: ScrollController(),
              child: ChannelCover(
                channel: channel,
                geometry: const ChannelProfileGeometry(0),
                scroll: ScrollController(),
                isMuted: false,
                muteTooltip: 'Mute',
                onMutePressed: () {},
                onSharePressed: null,
                isActionBusy: false,
                onJoinPressed: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text(AppStrings.channelPostAction), findsNothing);
      expect(find.text(AppStrings.channelJoinedAction), findsOneWidget);
    });
  });

  group('ChannelIdentity Owner / Admin badge', () {
    testWidgets('renders Owner badge when isOwner is true', (tester) async {
      const channel = Channel(
        id: '123',
        chatId: 123,
        title: 'My Channel',
        isOwner: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: ChannelIdentity(channel: channel)),
        ),
      );

      expect(find.text(AppStrings.channelOwnerBadge), findsOneWidget);
      expect(find.text(AppStrings.channelAdminBadge), findsNothing);
    });

    testWidgets('renders Admin badge when isAdmin is true and not owner', (
      tester,
    ) async {
      const channel = Channel(
        id: '123',
        chatId: 123,
        title: 'Admin Channel',
        isAdmin: true,
        isOwner: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: ChannelIdentity(channel: channel)),
        ),
      );

      expect(find.text(AppStrings.channelAdminBadge), findsOneWidget);
      expect(find.text(AppStrings.channelOwnerBadge), findsNothing);
    });

    testWidgets('renders no badge for regular channel', (tester) async {
      const channel = Channel(
        id: '123',
        chatId: 123,
        title: 'Public Channel',
        isAdmin: false,
        isOwner: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: ChannelIdentity(channel: channel)),
        ),
      );

      expect(find.text(AppStrings.channelOwnerBadge), findsNothing);
      expect(find.text(AppStrings.channelAdminBadge), findsNothing);
    });
  });

  group('ChannelCover & ChannelProfileBar Edit button', () {
    testWidgets(
      'renders Edit button in ChannelCover when onEditPressed is supplied',
      (tester) async {
        var editPressed = false;
        const channel = Channel(
          id: '123',
          chatId: 123,
          title: 'My Channel',
          canPost: true,
          isOwner: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark(),
            home: Scaffold(
              body: SingleChildScrollView(
                controller: ScrollController(),
                child: ChannelCover(
                  channel: channel,
                  geometry: const ChannelProfileGeometry(0),
                  scroll: ScrollController(),
                  isMuted: false,
                  muteTooltip: 'Mute',
                  onMutePressed: () {},
                  onSharePressed: null,
                  isActionBusy: false,
                  onJoinPressed: () {},
                  onPostPressed: () {},
                  onEditPressed: () => editPressed = true,
                ),
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
        await tester.tap(find.byIcon(Icons.edit_outlined));
        expect(editPressed, isTrue);
      },
    );

    testWidgets(
      'renders Edit button in ChannelProfileBar when onEditPressed is supplied',
      (tester) async {
        var editPressed = false;
        const channel = Channel(
          id: '123',
          chatId: 123,
          title: 'My Channel',
          canPost: true,
          isOwner: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark(),
            home: Scaffold(
              body: ChannelProfileBar(
                channel: channel,
                geometry: const ChannelProfileGeometry(0),
                scroll: ScrollController(),
                onEditPressed: () => editPressed = true,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
        await tester.tap(find.byIcon(Icons.edit_outlined));
        expect(editPressed, isTrue);
      },
    );
  });

  group('EditChannelSheet UI', () {
    testWidgets('renders channel name, description and save button', (
      tester,
    ) async {
      const channel = Channel(
        id: '123',
        chatId: 123,
        title: 'Tech News Daily',
        description: 'Daily curated tech news',
        canPost: true,
        isOwner: true,
      );

      final fakeRepo = FakeChannelRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [channelRepositoryProvider.overrideWithValue(fakeRepo)],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const Scaffold(body: EditChannelSheet(channel: channel)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.channelEditTitle), findsOneWidget);
      expect(find.text(AppStrings.channelSaveAction), findsOneWidget);
      expect(find.text('Tech News Daily'), findsOneWidget);
      expect(find.text('Daily curated tech news'), findsOneWidget);
      expect(find.text(AppStrings.channelInviteLink), findsOneWidget);
      expect(find.text('https://t.me/test_invite_link'), findsOneWidget);
    });

    testWidgets('saving updates title and description via repository', (
      tester,
    ) async {
      const channel = Channel(
        id: '123',
        chatId: 123,
        title: 'Old Title',
        description: 'Old Description',
        canPost: true,
        isOwner: true,
      );

      final fakeRepo = FakeChannelRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [channelRepositoryProvider.overrideWithValue(fakeRepo)],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const Scaffold(body: EditChannelSheet(channel: channel)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter new title
      await tester.enterText(
        find.widgetWithText(TextField, 'Old Title'),
        'New Awesome Title',
      );
      // Enter new description
      await tester.enterText(
        find.widgetWithText(TextField, 'Old Description'),
        'New Awesome Description',
      );

      // Tap save
      await tester.tap(find.text(AppStrings.channelSaveAction));
      await tester.pumpAndSettle();

      expect(fakeRepo.updatedTitle, 'New Awesome Title');
      expect(fakeRepo.updatedDescription, 'New Awesome Description');
    });
  });
}
