import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/app/theme/app_theme.dart';
import 'package:gramx/app/widgets/pill_button.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/channels/domain/channel.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/folders/data/folder_repository.dart';
import 'package:gramx/features/folders/presentation/folders_screen.dart';
import 'package:gramx/features/folders/presentation/widgets/channel_lists_sheet.dart';
import 'package:gramx/features/folders/presentation/widgets/edit_list_sheet.dart';
import 'package:handy_tdlib/api.dart' as td;

class FakeFolderRepository implements FolderRepository {
  List<td.ChatFolderInfo> folders = [];
  Map<int, td.ChatFolder> fullFolders = {};
  Map<int, List<int>> folderChannels = {};

  String? lastCreatedTitle;
  List<int>? lastCreatedChannels;
  String? lastEditedTitle;
  List<int>? lastEditedChannels;
  int? lastDeletedFolderId;
  bool createSuccess = true;
  bool editSuccess = true;
  bool deleteSuccess = true;

  @override
  Future<List<td.ChatFolderInfo>> getFolders() async => folders;

  @override
  Future<List<int>> getFolderChannelChatIds(int folderId) async {
    return folderChannels[folderId] ?? const [];
  }

  @override
  Future<bool> folderExcludesRead(int folderId) async => false;

  @override
  Future<td.ChatFolder?> getChatFolder(int folderId) async {
    return fullFolders[folderId];
  }

  @override
  Future<bool> createFolder(
    String title, {
    List<int> includedChatIds = const [],
  }) async {
    lastCreatedTitle = title;
    lastCreatedChannels = includedChatIds;
    if (createSuccess) {
      final newId = folders.length + 1;
      folders.add(
        td.ChatFolderInfo(
          id: newId,
          title: title,
          icon: const td.ChatFolderIcon(name: 'Custom'),
          colorId: -1,
          isShareable: false,
          hasMyInviteLinks: false,
        ),
      );
      folderChannels[newId] = List.from(includedChatIds);
    }
    return createSuccess;
  }

  @override
  Future<bool> editFolder(
    int folderId, {
    String? title,
    List<int>? includedChatIds,
  }) async {
    lastEditedTitle = title;
    lastEditedChannels = includedChatIds;
    if (editSuccess) {
      if (includedChatIds != null) {
        folderChannels[folderId] = List.from(includedChatIds);
      }
    }
    return editSuccess;
  }

  @override
  Future<bool> deleteFolder(int folderId) async {
    lastDeletedFolderId = folderId;
    if (deleteSuccess) {
      folders.removeWhere((f) => f.id == folderId);
      folderChannels.remove(folderId);
    }
    return deleteSuccess;
  }

  @override
  Future<bool> toggleChannelInFolder(
    int folderId,
    int chatId, {
    required bool include,
  }) async {
    final list = List<int>.from(folderChannels[folderId] ?? const []);
    if (include) {
      list.add(chatId);
    } else {
      list.remove(chatId);
    }
    folderChannels[folderId] = list;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const channel1 = Channel(
    id: '101',
    chatId: 101,
    title: 'Flutter Devs',
    username: 'flutterdev',
  );

  const channel2 = Channel(
    id: '102',
    chatId: 102,
    title: 'Tech News Daily',
    username: 'technews',
  );

  group('EditListSheet UI', () {
    testWidgets('renders create list UI with channel selection', (
      tester,
    ) async {
      final fakeRepo = FakeFolderRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            folderRepositoryProvider.overrideWithValue(fakeRepo),
            channelsProvider.overrideWith((ref) => [channel1, channel2]),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const Scaffold(body: EditListSheet()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.listsCreateTitle), findsOneWidget);
      expect(find.text(AppStrings.listsCreateAction), findsOneWidget);
      expect(find.text(AppStrings.listsNameLabel), findsOneWidget);
      expect(find.text('Flutter Devs'), findsOneWidget);
      expect(find.text('Tech News Daily'), findsOneWidget);
      expect(find.text('0 selected'), findsOneWidget);

      // Select channel1
      await tester.tap(find.text('Flutter Devs'));
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);

      // Enter list title
      await tester.enterText(
        find.widgetWithText(TextField, AppStrings.listsNameLabel),
        'Tech Dev',
      );

      // Tap create
      await tester.tap(find.text(AppStrings.listsCreateAction));
      await tester.pumpAndSettle();

      expect(fakeRepo.lastCreatedTitle, 'Tech Dev');
      expect(fakeRepo.lastCreatedChannels, [101]);
    });

    testWidgets('validates empty list name', (tester) async {
      final fakeRepo = FakeFolderRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            folderRepositoryProvider.overrideWithValue(fakeRepo),
            channelsProvider.overrideWith((ref) => [channel1]),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const Scaffold(body: EditListSheet()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap create with empty title
      await tester.tap(find.text(AppStrings.listsCreateAction));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.listsNameRequired), findsOneWidget);
      expect(fakeRepo.lastCreatedTitle, isNull);
    });
  });

  group('ChannelListsSheet UI', () {
    testWidgets('displays lists and allows toggling membership', (
      tester,
    ) async {
      final fakeRepo = FakeFolderRepository();
      fakeRepo.folders = [
        const td.ChatFolderInfo(
          id: 1,
          title: 'News',
          icon: td.ChatFolderIcon(name: 'Custom'),
          colorId: -1,
          isShareable: false,
          hasMyInviteLinks: false,
        ),
      ];
      fakeRepo.folderChannels = {
        1: [102], // channel2 is currently in folder 1
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            folderRepositoryProvider.overrideWithValue(fakeRepo),
            foldersProvider.overrideWith(
              (ref) => Stream.value(fakeRepo.folders),
            ),
            folderChannelIdsProvider(1).overrideWith(
              (ref) =>
                  fakeRepo.folderChannels[1]!.map((e) => e.toString()).toSet(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const Scaffold(
              body: ChannelListsSheet(
                chatId: 101, // channel1 is not in folder 1
                title: 'Flutter Devs',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.channelAddToList), findsOneWidget);
      expect(find.text('Flutter Devs'), findsOneWidget);
      expect(find.text('News'), findsOneWidget);
      expect(find.text(AppStrings.listsCreateTitle), findsOneWidget);

      // Checkbox is unchecked for channel1
      final checkboxFinder = find.byType(Checkbox);
      expect(checkboxFinder, findsOneWidget);
      expect((tester.widget(checkboxFinder) as Checkbox).value, isFalse);

      // Tap list tile to toggle
      await tester.tap(find.text('News'));
      await tester.pumpAndSettle();

      expect(fakeRepo.folderChannels[1], contains(101));
    });
  });

  group('FoldersScreen UI', () {
    testWidgets('shows custom lists and allows deleting', (tester) async {
      final fakeRepo = FakeFolderRepository();
      fakeRepo.folders = [
        const td.ChatFolderInfo(
          id: 1,
          title: 'Daily Tech',
          icon: td.ChatFolderIcon(name: 'Custom'),
          colorId: -1,
          isShareable: false,
          hasMyInviteLinks: false,
        ),
      ];
      fakeRepo.folderChannels = {
        1: [101, 102],
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            folderRepositoryProvider.overrideWithValue(fakeRepo),
            foldersProvider.overrideWith(
              (ref) => Stream.value(fakeRepo.folders),
            ),
            folderChannelIdsProvider(1).overrideWith(
              (ref) =>
                  fakeRepo.folderChannels[1]!.map((e) => e.toString()).toSet(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const FoldersScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.listsTitle), findsOneWidget);
      expect(find.text('Daily Tech'), findsOneWidget);
      expect(find.text('2 channels'), findsOneWidget);

      // Tap popup menu
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.listsEditTitle), findsOneWidget);
      expect(find.text(AppStrings.listsDeleteAction), findsOneWidget);

      // Tap delete
      await tester.tap(find.text(AppStrings.listsDeleteAction));
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.text(AppStrings.listsDeleteTitle), findsOneWidget);
      expect(find.text(AppStrings.listsDeleteConfirm), findsOneWidget);

      // Confirm delete in dialog
      await tester.tap(
        find.widgetWithText(PillButton, AppStrings.listsDeleteAction),
      );
      await tester.pumpAndSettle();

      expect(fakeRepo.lastDeletedFolderId, 1);
    });
  });
}
