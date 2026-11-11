import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/app/widgets/pill_button.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/channels/domain/channel.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/folders/data/folder_repository.dart';

/// Modal bottom sheet for creating or editing a custom channel list (folder).
class EditListSheet extends ConsumerStatefulWidget {
  /// The folder ID if editing an existing list; null if creating a new one.
  final int? folderId;

  /// The initial list title if editing.
  final String? initialTitle;

  /// The initial channel chat IDs included in this list if editing.
  final List<int>? initialChatIds;

  const EditListSheet({
    super.key,
    this.folderId,
    this.initialTitle,
    this.initialChatIds,
  });

  static Future<bool?> show(
    BuildContext context, {
    int? folderId,
    String? initialTitle,
    List<int>? initialChatIds,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => EditListSheet(
        folderId: folderId,
        initialTitle: initialTitle,
        initialChatIds: initialChatIds,
      ),
    );
  }

  @override
  ConsumerState<EditListSheet> createState() => _EditListSheetState();
}

class _EditListSheetState extends ConsumerState<EditListSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _searchController;
  late final Set<int> _selectedChatIds;

  String _searchQuery = '';
  bool _isSaving = false;
  bool _isLoadingInitial = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _searchController = TextEditingController();
    _selectedChatIds = Set<int>.from(widget.initialChatIds ?? const []);

    if (widget.folderId != null && widget.initialChatIds == null) {
      _loadFolderChannels();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFolderChannels() async {
    setState(() => _isLoadingInitial = true);
    final repo = ref.read(folderRepositoryProvider);
    final folder = await repo.getChatFolder(widget.folderId!);
    if (mounted) {
      setState(() {
        if (folder != null) {
          _selectedChatIds.addAll(folder.includedChatIds);
          if (_titleController.text.isEmpty) {
            _titleController.text = folder.title;
          }
        }
        _isLoadingInitial = false;
      });
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final messenger = ScaffoldMessenger.of(context);

    if (title.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(AppStrings.listsNameRequired),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (title.length > 12) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(AppStrings.listsNameTooLong),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final repo = ref.read(folderRepositoryProvider);
    final isEditing = widget.folderId != null;

    final success = isEditing
        ? await repo.editFolder(
            widget.folderId!,
            title: title,
            includedChatIds: _selectedChatIds.toList(),
          )
        : await repo.createFolder(
            title,
            includedChatIds: _selectedChatIds.toList(),
          );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      // Invalidate folder providers so home tabs update immediately
      ref.invalidate(foldersProvider);
      if (widget.folderId != null) {
        ref.invalidate(folderChannelIdsProvider(widget.folderId!));
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isEditing ? AppStrings.listsUpdated : AppStrings.listsCreated,
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(AppStrings.listsSaveFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _toggleChannel(int chatId) {
    setState(() {
      if (_selectedChatIds.contains(chatId)) {
        _selectedChatIds.remove(chatId);
      } else {
        _selectedChatIds.add(chatId);
      }
    });
  }

  List<Channel> _filterChannels(List<Channel> channels) {
    if (_searchQuery.isEmpty) return channels;
    final query = _searchQuery.toLowerCase();
    return channels.where((c) {
      final matchesTitle = c.title.toLowerCase().contains(query);
      final matchesUsername =
          c.username != null && c.username!.toLowerCase().contains(query);
      return matchesTitle || matchesUsername;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final channelsAsync = ref.watch(channelsProvider);
    final isEditing = widget.folderId != null;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.postPadding,
        right: AppSpacing.postPadding,
        top: AppSpacing.xs,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Title and Save button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isEditing
                    ? AppStrings.listsEditTitle
                    : AppStrings.listsCreateTitle,
                style: AppTypography.heading(color: primary),
              ),
              PillButton(
                label: isEditing
                    ? AppStrings.listsSaveAction
                    : AppStrings.listsCreateAction,
                style: PillStyle.filled,
                isBusy: _isSaving,
                onPressed: _save,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Name field (max 12 chars per Telegram spec)
          TextField(
            controller: _titleController,
            maxLength: 12,
            style: AppTypography.body(color: primary),
            decoration: InputDecoration(
              labelText: AppStrings.listsNameLabel,
              hintText: AppStrings.listsNameHint,
              labelStyle: AppTypography.body(color: secondary),
              hintStyle: AppTypography.body(
                color: secondary.withValues(alpha: 0.7),
              ),
              border: const OutlineInputBorder(),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.accent, width: 2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Section header with selected count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.listsChannelsSection,
                style: AppTypography.subheading(color: primary),
              ),
              Text(
                AppStrings.listsSelectedCount(_selectedChatIds.length),
                style: AppTypography.actionCount(color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          // Search channels input
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            style: AppTypography.body(color: primary),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              hintText: AppStrings.listsSearchChannelsHint,
              hintStyle: AppTypography.body(
                color: secondary.withValues(alpha: 0.7),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Channel picker list
          Expanded(
            child: _isLoadingInitial
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  )
                : channelsAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                    error: (err, _) => Center(
                      child: Text(
                        AppStrings.channelsError(err),
                        style: AppTypography.body(color: AppColors.error),
                      ),
                    ),
                    data: (channels) {
                      final filtered = _filterChannels(channels);
                      if (filtered.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Text(
                              _searchQuery.isEmpty
                                  ? AppStrings.listsNoChannelsSelected
                                  : AppStrings.searchNoResults,
                              style: AppTypography.body(color: secondary),
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final channel = filtered[index];
                          final isSelected = _selectedChatIds.contains(
                            channel.chatId,
                          );

                          return InkWell(
                            onTap: () => _toggleChannel(channel.chatId),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.xs,
                                horizontal: AppSpacing.xs,
                              ),
                              child: Row(
                                children: [
                                  ChannelAvatar(
                                    title: channel.title,
                                    avatarPath: channel.avatarUrl,
                                    avatarFileId: channel.avatarFileId,
                                    avatarColorHex: channel.avatarColor,
                                    radius: 20,
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          channel.title,
                                          style: AppTypography.subheading(
                                            color: primary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (channel.username != null)
                                          Text(
                                            '@${channel.username}',
                                            style: AppTypography.actionCount(
                                              color: secondary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: isSelected
                                        ? AppColors.accent
                                        : secondary,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
