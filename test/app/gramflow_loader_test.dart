import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/app/widgets/gramflow_loader.dart';
import 'package:gramx/core/l10n/app_strings.dart';

void main() {
  group('GramFlowPathData', () {
    test('defines viewBox and metrics correctly', () {
      expect(GramFlowPathData.viewBox, const Size(500, 500));
      expect(GramFlowPathData.outerLength, greaterThan(100.0));
      expect(GramFlowPathData.innerLength, greaterThan(100.0));
      expect(GramFlowPathData.fillPath, isNotNull);
      expect(GramFlowPathData.center, const Offset(250.0, 250.0));
    });
  });

  group('GramFlowLoader widget', () {
    testWidgets('provides semantics for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: GramFlowLoader())),
      );
      await tester.pump();

      expect(find.bySemanticsLabel(AppStrings.appName), findsOneWidget);
      handle.dispose();
    });

    testWidgets('holds its configured size', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: GramFlowLoader(size: 140))),
        ),
      );

      expect(tester.getSize(find.byType(GramFlowLoader)), const Size(140, 140));
    });

    testWidgets('paints correctly at different progress keyframes', (
      tester,
    ) async {
      for (final progress in [0.0, 0.25, 0.45, 0.68, 0.85, 0.95, 1.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CustomPaint(
                size: const Size(200, 200),
                painter: GramFlowLoaderPainter(
                  progress: progress,
                  color: Colors.blue,
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('accepts an external animation controller', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestHost(
              childBuilder: (ctrl) => GramFlowLoader(controller: ctrl),
            ),
          ),
        ),
      );

      expect(find.byType(GramFlowLoader), findsOneWidget);
    });
  });
}

class _TestHost extends StatefulWidget {
  final Widget Function(AnimationController controller) childBuilder;

  const _TestHost({required this.childBuilder});

  @override
  State<_TestHost> createState() => _TestHostState();
}

class _TestHostState extends State<_TestHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.childBuilder(_controller);
}
