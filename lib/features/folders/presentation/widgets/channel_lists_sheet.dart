import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/app/widgets/pill_button.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/channels/domain/channel.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/folders/data/folder_repository.dart';
import 'package:gramx/features/folders/presentation/widgets/edit_list_sheet.dart';

/// Modal bottom sheet to quickly toggle a channel's membership across custom lists.
class ChannelListsSheet extends ConsumerWidget {
  final int chatId;
  final String title;
  final String? avatarUrl;
  final int? avatarFileId;
  final String? avatarColor;

  const ChannelListsSheet({
    super.key,
    required this.chatId,
    required this.title,
    this.avatarUrl,
    this.avatarFileId,
    this.avatarColor,
  });

  static Future<void> show(BuildContext context, {required Channel channel}) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ChannelListsSheet(
        chatId: channel.chatId,
        title: channel.title,
        avatarUrl: channel.avatarUrl,
        avatarFileId: channel.avatarFileId,
        avatarColor: channel.avatarColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final foldersAsync = ref.watch(foldersProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.postPadding,
        right: AppSpacing.postPadding,
        top: AppSpacing.xs,
        bottom: MediaQuery.viewPaddingOf(context).bottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with channel identity
          Row(
            children: [
              ChannelAvatar(
                title: title,
                avatarPath: avatarUrl,
                avatarFileId: avatarFileId,
                avatarColorHex: avatarColor,
                radius: 20,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.channelAddToList,
                      style: AppTypography.heading(color: primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      title,
                      style: AppTypography.actionCount(color: secondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Lists
          Expanded(
            child: foldersAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
              error: (err, _) => Center(
                child: Text(
                  AppStrings.foldersError(err),
                  style: AppTypography.body(color: AppColors.error),
                ),
              ),
              data: (folders) {
                if (folders.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(
                        AppStrings.listsEmptyState,
                        style: AppTypography.body(color: secondary),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: folders.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final folder = folders[index];
                    final channelIdsAsync = ref.watch(
                      folderChannelIdsProvider(folder.id),
                    );
                    final channelIds = channelIdsAsync.value ?? const {};
                    final isInList = channelIds.contains(chatId.toString());

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.playlist_play_rounded,
                        color: AppColors.accent,
                        size: 24,
                      ),
                      title: Text(
                        parseFolderTitle(folder.title),
                        style: AppTypography.subheading(color: primary),
                      ),
                      subtitle: Text(
                        AppStrings.folderChannelCount(channelIds.length),
                        style: AppTypography.actionCount(color: secondary),
                      ),
                      trailing: Checkbox(
                        value: isInList,
                        activeColor: AppColors.accent,
                        onChanged: (checked) async {
                          final repo = ref.read(folderRepositoryProvider);
                          final ok = await repo.toggleChannelInFolder(
                            folder.id,
                            chatId,
                            include: checked ?? false,
                          );
                          if (ok) {
                            ref.invalidate(folderChannelIdsProvider(folder.id));
                            ref.invalidate(foldersProvider);
                          }
                        },
                      ),
                      onTap: () async {
                        final repo = ref.read(folderRepositoryProvider);
                        final ok = await repo.toggleChannelInFolder(
                          folder.id,
                          chatId,
                          include: !isInList,
                        );
                        if (ok) {
                          ref.invalidate(folderChannelIdsProvider(folder.id));
                          ref.invalidate(foldersProvider);
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),

          const SizedBox(height: AppSpacing.sm),
          // Create new list button
          PillButton(
            label: AppStrings.listsCreateTitle,
            icon: Icons.add,
            style: PillStyle.outlined,
            onPressed: () {
              Navigator.of(context).pop();
              EditListSheet.show(context, initialChatIds: [chatId]);
            },
          ),
        ],
      ),
    );
  }
}
