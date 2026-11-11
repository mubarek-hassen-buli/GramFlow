import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gramx/features/reader/domain/reader_settings.dart';
import 'package:gramx/features/reader/domain/reader_theme.dart';

/// Riverpod provider for Reader Mode settings.
final readerSettingsProvider =
    NotifierProvider<ReaderSettingsNotifier, ReaderSettings>(
      ReaderSettingsNotifier.new,
    );

/// Manages typography and canvas theme preferences for Reader Mode.
class ReaderSettingsNotifier extends Notifier<ReaderSettings> {
  final ReaderSettings? _initialStateForTesting;

  ReaderSettingsNotifier([this._initialStateForTesting]);

  @override
  ReaderSettings build() {
    return _initialStateForTesting ?? const ReaderSettings();
  }

  void setTheme(ReaderTheme theme) {
    state = state.copyWith(theme: theme);
  }

  void setFont(ReaderFont font) {
    state = state.copyWith(font: font);
  }

  void setFontSize(double fontSize) {
    state = state.copyWith(fontSize: fontSize.clamp(14.0, 28.0));
  }

  void setLineHeight(double lineHeight) {
    state = state.copyWith(lineHeight: lineHeight.clamp(1.3, 2.2));
  }

  void toggleProgressBar() {
    state = state.copyWith(showProgressBar: !state.showProgressBar);
  }
}
