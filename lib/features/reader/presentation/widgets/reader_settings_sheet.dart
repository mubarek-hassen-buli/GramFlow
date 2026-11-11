import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/reader/domain/reader_theme.dart';
import 'package:gramx/features/reader/presentation/reader_settings_notifier.dart';

/// Shows the Reader Mode appearance configuration sheet.
Future<void> showReaderSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const ReaderSettingsSheet(),
  );
}

/// Interactive sheet to customize Reader Mode theme, typeface, font size, and line height.
class ReaderSettingsSheet extends ConsumerWidget {
  const ReaderSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);
    final notifier = ref.read(readerSettingsProvider.notifier);
    final theme = settings.theme;

    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: theme.dividerColor, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.secondaryTextColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              Text(
                AppStrings.readerSettingsTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.primaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),

              // Theme palette selector
              Row(
                children: [
                  _ThemeButton(
                    theme: ReaderTheme.paper,
                    label: AppStrings.readerThemePaper,
                    isSelected: settings.theme == ReaderTheme.paper,
                    onTap: () => notifier.setTheme(ReaderTheme.paper),
                  ),
                  const SizedBox(width: 8),
                  _ThemeButton(
                    theme: ReaderTheme.sepia,
                    label: AppStrings.readerThemeSepia,
                    isSelected: settings.theme == ReaderTheme.sepia,
                    onTap: () => notifier.setTheme(ReaderTheme.sepia),
                  ),
                  const SizedBox(width: 8),
                  _ThemeButton(
                    theme: ReaderTheme.dark,
                    label: AppStrings.readerThemeDark,
                    isSelected: settings.theme == ReaderTheme.dark,
                    onTap: () => notifier.setTheme(ReaderTheme.dark),
                  ),
                  const SizedBox(width: 8),
                  _ThemeButton(
                    theme: ReaderTheme.black,
                    label: AppStrings.readerThemeBlack,
                    isSelected: settings.theme == ReaderTheme.black,
                    onTap: () => notifier.setTheme(ReaderTheme.black),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Font selector
              Row(
                children: [
                  _FontButton(
                    font: ReaderFont.serif,
                    label: AppStrings.readerFontSerif,
                    isSelected: settings.font == ReaderFont.serif,
                    theme: theme,
                    onTap: () => notifier.setFont(ReaderFont.serif),
                  ),
                  const SizedBox(width: 8),
                  _FontButton(
                    font: ReaderFont.sans,
                    label: AppStrings.readerFontSans,
                    isSelected: settings.font == ReaderFont.sans,
                    theme: theme,
                    onTap: () => notifier.setFont(ReaderFont.sans),
                  ),
                  const SizedBox(width: 8),
                  _FontButton(
                    font: ReaderFont.mono,
                    label: AppStrings.readerFontMono,
                    isSelected: settings.font == ReaderFont.mono,
                    theme: theme,
                    onTap: () => notifier.setFont(ReaderFont.mono),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Text size controls
              Row(
                children: [
                  Text(
                    'A',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.secondaryTextColor,
                    ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: theme.primaryTextColor,
                        inactiveTrackColor: theme.dividerColor,
                        thumbColor: theme.primaryTextColor,
                        overlayColor: theme.primaryTextColor.withValues(
                          alpha: 0.1,
                        ),
                        trackHeight: 2.5,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7,
                        ),
                      ),
                      child: Slider(
                        value: settings.fontSize,
                        min: 14.0,
                        max: 26.0,
                        divisions: 6,
                        onChanged: notifier.setFontSize,
                      ),
                    ),
                  ),
                  Text(
                    'A',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: theme.primaryTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Line spacing controls
              Row(
                children: [
                  Text(
                    AppStrings.readerLineSpacing,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: theme.secondaryTextColor,
                    ),
                  ),
                  const Spacer(),
                  _SpacingButton(
                    label: '1.4x',
                    value: 1.4,
                    currentValue: settings.lineHeight,
                    theme: theme,
                    onTap: () => notifier.setLineHeight(1.4),
                  ),
                  const SizedBox(width: 6),
                  _SpacingButton(
                    label: '1.65x',
                    value: 1.65,
                    currentValue: settings.lineHeight,
                    theme: theme,
                    onTap: () => notifier.setLineHeight(1.65),
                  ),
                  const SizedBox(width: 6),
                  _SpacingButton(
                    label: '1.9x',
                    value: 1.9,
                    currentValue: settings.lineHeight,
                    theme: theme,
                    onTap: () => notifier.setLineHeight(1.9),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeButton extends StatelessWidget {
  final ReaderTheme theme;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeButton({
    required this.theme,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: theme.backgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF1D9BF0) : theme.dividerColor,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                'Aa',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.primaryTextColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: theme.secondaryTextColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FontButton extends StatelessWidget {
  final ReaderFont font;
  final String label;
  final bool isSelected;
  final ReaderTheme theme;
  final VoidCallback onTap;

  const _FontButton({
    required this.font,
    required this.label,
    required this.isSelected,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? theme.backgroundColor : theme.surfaceColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF1D9BF0) : theme.dividerColor,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: font.style(
                fontSize: 13,
                lineHeight: 1.2,
                color: isSelected
                    ? theme.primaryTextColor
                    : theme.secondaryTextColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpacingButton extends StatelessWidget {
  final String label;
  final double value;
  final double currentValue;
  final ReaderTheme theme;
  final VoidCallback onTap;

  const _SpacingButton({
    required this.label,
    required this.value,
    required this.currentValue,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = (currentValue - value).abs() < 0.05;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? theme.backgroundColor : theme.surfaceColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFF1D9BF0) : theme.dividerColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected
                ? theme.primaryTextColor
                : theme.secondaryTextColor,
          ),
        ),
      ),
    );
  }
}
