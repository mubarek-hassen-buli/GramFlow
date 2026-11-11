import 'package:flutter/foundation.dart';
import 'package:gramx/features/reader/domain/reader_theme.dart';

/// Immutable user preferences for Reader Mode.
@immutable
class ReaderSettings {
  final ReaderTheme theme;
  final ReaderFont font;
  final double fontSize;
  final double lineHeight;
  final bool showProgressBar;

  const ReaderSettings({
    this.theme = ReaderTheme.sepia,
    this.font = ReaderFont.serif,
    this.fontSize = 18.0,
    this.lineHeight = 1.65,
    this.showProgressBar = true,
  });

  ReaderSettings copyWith({
    ReaderTheme? theme,
    ReaderFont? font,
    double? fontSize,
    double? lineHeight,
    bool? showProgressBar,
  }) {
    return ReaderSettings(
      theme: theme ?? this.theme,
      font: font ?? this.font,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      showProgressBar: showProgressBar ?? this.showProgressBar,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReaderSettings &&
          runtimeType == other.runtimeType &&
          theme == other.theme &&
          font == other.font &&
          fontSize == other.fontSize &&
          lineHeight == other.lineHeight &&
          showProgressBar == other.showProgressBar;

  @override
  int get hashCode =>
      Object.hash(theme, font, fontSize, lineHeight, showProgressBar);
}
