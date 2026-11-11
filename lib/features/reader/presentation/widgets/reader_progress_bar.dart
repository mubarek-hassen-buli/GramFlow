import 'package:flutter/material.dart';

/// A sleek, subtle top progress bar indicating reading depth through an article.
class ReaderProgressBar extends StatelessWidget {
  final double progress;
  final Color color;
  final Color backgroundColor;

  const ReaderProgressBar({
    super.key,
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 2.5,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barWidth = constraints.maxWidth * progress.clamp(0.0, 1.0);
          return Stack(
            children: [
              Container(width: constraints.maxWidth, color: backgroundColor),
              AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                curve: Curves.easeOut,
                width: barWidth,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(2),
                    bottomRight: Radius.circular(2),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
