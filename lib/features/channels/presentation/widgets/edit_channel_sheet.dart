import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/app/widgets/pill_button.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/channels/data/channel_repository.dart';
import 'package:gramx/features/channels/domain/channel.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';

/// Modal bottom sheet for editing channel details (name, bio, photo, invite link).
class EditChannelSheet extends ConsumerStatefulWidget {
  final Channel channel;

  const EditChannelSheet({super.key, required this.channel});

  static Future<void> show(BuildContext context, Channel channel) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => EditChannelSheet(channel: channel),
    );
  }

  @override
  ConsumerState<EditChannelSheet> createState() => _EditChannelSheetState();
}

class _EditChannelSheetState extends ConsumerState<EditChannelSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  String? _pickedPhotoPath;
  String? _inviteLink;
  bool _isLoadingLink = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.channel.title);
    _descriptionController = TextEditingController(
      text: widget.channel.description ?? '',
    );
    _loadInviteLink();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadInviteLink() async {
    final link = await ref
        .read(channelRepositoryProvider)
        .getChannelInviteLink(
          widget.channel.chatId,
          username: widget.channel.username,
        );
    if (mounted) {
      setState(() {
        _inviteLink = link;
        _isLoadingLink = false;
      });
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (image != null && mounted) {
      setState(() => _pickedPhotoPath = image.path);
    }
  }

  Future<void> _copyInviteLink() async {
    final link = _inviteLink;
    if (link == null || link.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(AppStrings.channelInviteLinkCopied),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.channelNameRequired),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final repo = ref.read(channelRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    var success = true;

    // 1. Update photo if selected
    if (_pickedPhotoPath != null) {
      final photoOk = await repo.updateChannelPhoto(
        widget.channel.chatId,
        _pickedPhotoPath!,
      );
      if (!photoOk) success = false;
    }

    // 2. Update title if changed
    if (title != widget.channel.title) {
      final titleOk = await repo.updateChannelTitle(
        widget.channel.chatId,
        title,
      );
      if (!titleOk) success = false;
    }

    // 3. Update description if changed
    final description = _descriptionController.text.trim();
    if (description != (widget.channel.description ?? '')) {
      final descOk = await repo.updateChannelDescription(
        widget.channel.chatId,
        description,
      );
      if (!descOk) success = false;
    }

    // Invalidate details provider to refresh UI
    ref.invalidate(channelDetailProvider(widget.channel.id));

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(AppStrings.channelSaved),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        navigator.pop();
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(AppStrings.channelSaveFailed),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.postPadding,
        right: AppSpacing.postPadding,
        top: AppSpacing.sm,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: Title and Save button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppStrings.channelEditTitle,
                  style: AppTypography.heading(color: primary),
                ),
                PillButton(
                  label: AppStrings.channelSaveAction,
                  style: PillStyle.filled,
                  isBusy: _isSaving,
                  onPressed: _save,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Avatar picker
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: _pickedPhotoPath != null
                        ? CircleAvatar(
                            radius: 46,
                            backgroundImage: FileImage(File(_pickedPhotoPath!)),
                          )
                        : ChannelAvatar(
                            title: widget.channel.title,
                            avatarPath: widget.channel.avatarUrl,
                            avatarFileId: widget.channel.avatarFileId,
                            avatarColorHex: widget.channel.avatarColor,
                            radius: 46,
                          ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickPhoto,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.scaffoldBackgroundColor,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Name field
            TextField(
              controller: _titleController,
              maxLength: 128,
              style: AppTypography.body(color: primary),
              decoration: InputDecoration(
                labelText: AppStrings.channelNameLabel,
                labelStyle: AppTypography.body(color: secondary),
                border: const OutlineInputBorder(),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.accent, width: 2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Description field
            TextField(
              controller: _descriptionController,
              maxLength: 255,
              maxLines: 3,
              style: AppTypography.body(color: primary),
              decoration: InputDecoration(
                labelText: AppStrings.channelDescriptionLabel,
                hintText: AppStrings.channelDescriptionHint,
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
            const SizedBox(height: AppSpacing.md),

            // Invite link section
            Text(
              AppStrings.channelInviteLink,
              style: AppTypography.subheading(color: primary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.link_rounded,
                    size: 20,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _isLoadingLink
                        ? const Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accent,
                              ),
                            ),
                          )
                        : Text(
                            _inviteLink ?? AppStrings.channelUnavailable,
                            style: AppTypography.body(
                              color: _inviteLink != null
                                  ? AppColors.accent
                                  : secondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                  if (_inviteLink != null)
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: AppStrings.channelCopyInviteLink,
                      color: secondary,
                      onPressed: _copyInviteLink,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
