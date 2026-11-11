import 'package:flutter/material.dart';
import 'package:gramx/core/l10n/app_strings.dart';

/// An elegant inline pill badge indicating that a post or thread is eligible
/// for Editorial Reader Mode.
class ReaderBadge extends StatelessWidget {
  final int estimatedMinutes;
  final bool isThread;
  final VoidCallback onTap;

  const ReaderBadge({
    super.key,
    required this.estimatedMinutes,
    this.isThread = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final badgeBg = isDark ? const Color(0xFF202327) : const Color(0xFFF0F3F4);
    final badgeBorder = isDark
        ? const Color(0xFF2F3336)
        : const Color(0xFFE1E8ED);
    final badgeFg = isDark ? const Color(0xFFE7E9EA) : const Color(0xFF0F1419);
    final iconColor = const Color(0xFF1D9BF0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: badgeBorder, width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_stories_rounded, size: 14, color: iconColor),
              const SizedBox(width: 5),
              Text(
                AppStrings.readerModeBadge(estimatedMinutes),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: badgeFg,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 14,
                color: badgeFg.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
