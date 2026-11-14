import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/feed/data/feed_repository.dart';
import 'package:gramx/infrastructure/telegram/available_reactions_resolver.dart';

class ReactionOverlay extends ConsumerStatefulWidget {
  final int chatId;
  final int messageId;
  final ValueChanged<String> onEmojiSelected;
  final Widget child;

  const ReactionOverlay({
    super.key,
    required this.chatId,
    this.messageId = 0,
    required this.onEmojiSelected,
    required this.child,
  });

  @override
  ConsumerState<ReactionOverlay> createState() => _ReactionOverlayState();
}

class _ReactionOverlayState extends ConsumerState<ReactionOverlay> {
  OverlayEntry? _overlayEntry;
  List<String>? _availableReactions;
  bool _isLoading = false;

  void _showOverlay(BuildContext context) async {
    if (_overlayEntry != null) return;

    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);

    setState(() {
      _isLoading = true;
    });

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          GestureDetector(
            onTap: _hideOverlay,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
          Positioned(
            left: offset.dx,
            top: offset.dy - 60, // Above the button
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkSurfaceVariant
                      : AppColors.lightSurfaceVariant,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _isLoading && _availableReactions == null
                    ? const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: (_availableReactions ?? []).take(8).map((
                            emoji,
                          ) {
                            return InkWell(
                              onTap: () {
                                widget.onEmojiSelected(emoji);
                                _hideOverlay();
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);

    if (_availableReactions == null) {
      final result = await ref
          .read(feedRepositoryProvider)
          .getAvailableReactions(widget.chatId, messageId: widget.messageId);
      if (!mounted) return;
      switch (result) {
        case AvailableReactionsAllowed(:final emojis):
          setState(() {
            _availableReactions = emojis;
            _isLoading = false;
          });
          _overlayEntry?.markNeedsBuild();
        case AvailableReactionsOff():
          _hideOverlay();
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(this.context).showSnackBar(
            const SnackBar(
              content: Text(AppStrings.reactionsOff),
              behavior: SnackBarBehavior.floating,
            ),
          );
        case AvailableReactionsCustomOnly():
          _hideOverlay();
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(this.context).showSnackBar(
            const SnackBar(
              content: Text(AppStrings.reactionsCustomOnly),
              behavior: SnackBarBehavior.floating,
            ),
          );
        case AvailableReactionsFailed():
          _hideOverlay();
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(this.context).showSnackBar(
            const SnackBar(
              content: Text(AppStrings.reactionFailed),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hideOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _showOverlay(context),
      child: widget.child,
    );
  }
}
