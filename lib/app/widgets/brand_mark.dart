import 'package:flutter/material.dart';

import 'package:gramx/app/theme/brand_assets.dart';
import 'package:gramx/app/widgets/gramflow_loader.dart';
import 'package:gramx/core/l10n/app_strings.dart';

/// The animated GramFlow mark, looped, for loading screens. It never settles,
/// so tests must not `pumpAndSettle` through it.
class BrandMark extends StatelessWidget {
  /// The side of the square the mark is fitted into.
  final double size;

  /// Optional color override. Defaults to theme onSurface / white.
  final Color? color;

  const BrandMark({super.key, this.size = 96, this.color});

  @override
  Widget build(BuildContext context) {
    return GramFlowLoader(size: size, color: color);
  }
}

/// The flat, still mark used as the feed header's title.
class BrandGlyph extends StatelessWidget {
  final double height;

  const BrandGlyph({super.key, this.height = 32});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      BrandAssets.gramFlowLogo,
      height: height,
      fit: BoxFit.contain,
      semanticLabel: AppStrings.appName,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        BrandAssets.glyphFor(Theme.of(context).brightness),
        height: height,
        fit: BoxFit.contain,
        semanticLabel: AppStrings.appName,
        errorBuilder: (context, error, stackTrace) => Text(
          AppStrings.appName,
          style: TextStyle(
            fontSize: height * 0.75,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
