import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';

/// Screen where users can view and copy the developer's payment details
/// to support GramFlow development.
class SupportDeveloperScreen extends StatelessWidget {
  /// The root route for this screen.
  static const String route = '/support';

  const SupportDeveloperScreen({super.key});

  void _copyToClipboard(
    BuildContext context, {
    required String value,
    required String message,
  }) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.supportTitle,
          style: AppTypography.heading(color: primary),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Divider(height: 1, thickness: 0.5, color: borderColor),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xl,
        ),
        children: [
          // Header hero card
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 0.5),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.volunteer_activism_rounded,
                    color: AppColors.accent,
                    size: 32,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  AppStrings.supportHeaderTitle,
                  style: AppTypography.heading(
                    color: primary,
                  ).copyWith(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppStrings.supportHeaderBody,
                  style: AppTypography.body(
                    color: secondary,
                  ).copyWith(height: 1.45),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Section title
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs,
            ),
            child: Text(
              AppStrings.supportSectionMethods,
              style: TextStyle(
                color: secondary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // CBE Account Card
          _PaymentAccountCard(
            title: AppStrings.supportCbeTitle,
            subtitle: AppStrings.supportCbeSubtitle,
            badge: AppStrings.supportCbeBadge,
            accountNumber: AppStrings.supportCbeAccount,
            holderLabel: AppStrings.supportAccountHolderLabel,
            holderName: AppStrings.supportAccountHolderName,
            icon: Icons.account_balance_rounded,
            primaryColor: primary,
            secondaryColor: secondary,
            borderColor: borderColor,
            cardBg: cardBg,
            onCopy: () => _copyToClipboard(
              context,
              value: AppStrings.supportCbeAccount,
              message: AppStrings.supportCbeCopied,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Telebirr Account Card
          _PaymentAccountCard(
            title: AppStrings.supportTelebirrTitle,
            subtitle: AppStrings.supportTelebirrSubtitle,
            badge: AppStrings.supportTelebirrBadge,
            accountNumber: AppStrings.supportTelebirrAccount,
            holderLabel: AppStrings.supportAccountHolderLabel,
            holderName: AppStrings.supportAccountHolderName,
            icon: Icons.phone_android_rounded,
            primaryColor: primary,
            secondaryColor: secondary,
            borderColor: borderColor,
            cardBg: cardBg,
            onCopy: () => _copyToClipboard(
              context,
              value: AppStrings.supportTelebirrAccount,
              message: AppStrings.supportTelebirrCopied,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Footer thank you card
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.25),
                width: 0.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  color: AppColors.accent,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    AppStrings.supportFooterNote,
                    style: AppTypography.body(
                      color: primary,
                    ).copyWith(fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _PaymentAccountCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final String accountNumber;
  final String holderLabel;
  final String holderName;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;
  final Color borderColor;
  final Color cardBg;
  final VoidCallback onCopy;

  const _PaymentAccountCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.accountNumber,
    required this.holderLabel,
    required this.holderName,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.borderColor,
    required this.cardBg,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onCopy,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.accent, size: 24),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: AppTypography.subheading(
                                color: primaryColor,
                              ).copyWith(fontSize: 16),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTypography.actionCount(color: secondaryColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Divider(height: 1, thickness: 0.5, color: borderColor),
            const SizedBox(height: AppSpacing.md),

            // Account holder
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  holderLabel,
                  style: AppTypography.actionCount(color: secondaryColor),
                ),
                Text(
                  holderName,
                  style: AppTypography.body(
                    color: primaryColor,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Account number box with copy action
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: borderColor.withValues(alpha: 0.7),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      accountNumber,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onCopy,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: Text(
                      AppStrings.supportCopyAction,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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
