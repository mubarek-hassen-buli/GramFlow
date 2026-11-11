import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/app/app_shell.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/app/widgets/app_dialog.dart';
import 'package:gramx/app/widgets/pill_button.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/folders/data/folder_repository.dart';
import 'package:gramx/features/folders/presentation/widgets/edit_list_sheet.dart';

class FoldersScreen extends ConsumerWidget {
  const FoldersScreen({super.key});

  /// Opens a folder as its feed tab. This screen sits above the shell, so it
  /// navigates to the feed route and requests the tab.
  void openFolderTab(BuildContext context, WidgetRef ref, int folderId) {
    ref.read(requestedFolderProvider.notifier).request(folderId.toString());
    context.go(ShellTab.home.path);
  }

  Future<void> _deleteFolder(
    BuildContext context,
    WidgetRef ref,
    int folderId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showAppDialog<bool>(
      context,
      title: AppStrings.listsDeleteTitle,
      body: AppStrings.listsDeleteConfirm,
      actions: [
        const AppDialogAction(
          label: AppStrings.listsDeleteAction,
          value: true,
          isDestructive: true,
          isPrimary: true,
        ),
        const AppDialogAction.cancel(AppStrings.listsCancelAction),
      ],
    );

    if (confirm == true) {
      final repo = ref.read(folderRepositoryProvider);
      final ok = await repo.deleteFolder(folderId);
      if (ok) {
        ref.invalidate(foldersProvider);
        messenger.showSnackBar(
          const SnackBar(
            content: Text(AppStrings.listsDeleted),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(AppStrings.listsDeleteFailed),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.onSurface;
    final secondaryColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final foldersAsync = ref.watch(foldersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.listsTitle,
          style: AppTypography.heading(color: primaryColor),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: AppStrings.listsCreateTitle,
            onPressed: () => EditListSheet.show(context),
          ),
        ],
      ),
      body: foldersAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (err, _) => Center(child: Text(AppStrings.foldersError(err))),
        data: (folders) {
          if (folders.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.playlist_add_rounded,
                      color: AppColors.accent,
                      size: 80,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      AppStrings.foldersEmptyTitle,
                      style: AppTypography.heading(
                        color: primaryColor,
                      ).copyWith(fontSize: 22),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      AppStrings.listsEmptyState,
                      style: AppTypography.body(color: secondaryColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PillButton(
                      label: AppStrings.listsCreateAction,
                      icon: Icons.add,
                      style: PillStyle.filled,
                      onPressed: () => EditListSheet.show(context),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: folders.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final folder = folders[index];
              final countAsync = ref.watch(folderChannelIdsProvider(folder.id));

              return ListTile(
                leading: const Icon(
                  Icons.playlist_play_rounded,
                  color: AppColors.accent,
                  size: 28,
                ),
                title: Text(
                  parseFolderTitle(folder.title),
                  style: AppTypography.subheading(color: primaryColor),
                ),
                subtitle: Text(
                  countAsync.when(
                    data: (ids) => AppStrings.folderChannelCount(ids.length),
                    loading: () => AppStrings.foldersCounting,
                    error: (_, _) => AppStrings.foldersCountUnavailable,
                  ),
                  style: AppTypography.actionCount(color: secondaryColor),
                ),
                trailing: PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: secondaryColor),
                  tooltip: AppStrings.listsManageTitle,
                  onSelected: (action) {
                    if (action == 'open') {
                      openFolderTab(context, ref, folder.id);
                    } else if (action == 'edit') {
                      EditListSheet.show(
                        context,
                        folderId: folder.id,
                        initialTitle: folder.title,
                      );
                    } else if (action == 'delete') {
                      _deleteFolder(context, ref, folder.id);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'open',
                      child: Row(
                        children: [
                          const Icon(Icons.launch_rounded, size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Text(AppStrings.foldersTitle),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 20),
                          SizedBox(width: AppSpacing.sm),
                          Text(AppStrings.listsEditTitle),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: AppColors.error,
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Text(
                            AppStrings.listsDeleteAction,
                            style: TextStyle(color: AppColors.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                onTap: () => openFolderTab(context, ref, folder.id),
              );
            },
          );
        },
      ),
    );
  }
}
