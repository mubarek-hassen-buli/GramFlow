import 'package:flutter/material.dart';

/// Paths to the brand artwork. Launcher icons are Android resources under
/// `android/app/src/main/res` and are not loaded through Flutter.
abstract class BrandAssets {
  /// The animated GramFlow SVG loader asset path.
  static const String loaderSvg = 'assets/brand/GramFlow-Loader.svg';

  /// Legacy mark animation WebP path.
  static const String markAnimation = 'assets/brand/gramx_mark.webp';

  /// Primary GramFlow brand logo and app icon.
  static const String gramFlowLogo = 'assets/brand/GramFlow.png';

  /// Primary GramFlow app icon.
  static const String appIcon = 'assets/brand/GramFlow.png';

  /// The flat monochrome mark for the feed header.
  static const String _glyphOnDark = 'assets/brand/glyph_on_dark.png';
  static const String _glyphOnLight = 'assets/brand/glyph_on_light.png';

  /// The glyph that reads against `brightness` (`dim` counts as dark).
  static String glyphFor(Brightness brightness) =>
      brightness == Brightness.dark ? _glyphOnDark : _glyphOnLight;

  /// Named for the surface they sit on, not for their own colour.
  static const String _appIconOnDark = 'assets/brand/app_icon_on_dark.png';
  static const String _appIconOnLight = 'assets/brand/app_icon_on_light.png';

  /// The framed icon that reads against `brightness` (`dim` counts as dark).
  static String appIconFor(Brightness brightness) =>
      brightness == Brightness.dark ? _appIconOnDark : _appIconOnLight;
}
