import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/settings/presentation/support_developer_screen.dart';

void main() {
  group('SupportDeveloperScreen', () {
    testWidgets('renders developer and account details', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: SupportDeveloperScreen()),
      );

      expect(find.text(AppStrings.supportTitle), findsOneWidget);
      expect(find.text(AppStrings.supportHeaderTitle), findsOneWidget);
      expect(find.text(AppStrings.supportHeaderBody), findsOneWidget);
      expect(find.text(AppStrings.supportSectionMethods), findsOneWidget);

      // CBE Account
      expect(find.text(AppStrings.supportCbeTitle), findsOneWidget);
      expect(find.text(AppStrings.supportCbeBadge), findsOneWidget);
      expect(find.text(AppStrings.supportCbeAccount), findsOneWidget);

      // Telebirr Account (title and badge both say Telebirr)
      expect(find.text(AppStrings.supportTelebirrTitle), findsNWidgets(2));
      expect(find.text(AppStrings.supportTelebirrAccount), findsOneWidget);

      // Account holder
      expect(find.text(AppStrings.supportAccountHolderName), findsNWidgets(2));
      expect(find.text(AppStrings.supportCopyAction), findsNWidgets(2));
    });

    testWidgets(
      'copying CBE account copies number to clipboard and shows snackbar',
      (tester) async {
        String? copiedText;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              final args = call.arguments as Map<dynamic, dynamic>?;
              copiedText = args?['text'] as String?;
              return null;
            }
            return null;
          },
        );

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SupportDeveloperScreen())),
        );

        // Tap the first Copy button (CBE)
        await tester.tap(find.text(AppStrings.supportCopyAction).first);
        await tester.pumpAndSettle();

        expect(copiedText, '1000528855354');
        expect(find.text(AppStrings.supportCbeCopied), findsOneWidget);
      },
    );

    testWidgets(
      'copying Telebirr account copies number to clipboard and shows snackbar',
      (tester) async {
        String? copiedText;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              final args = call.arguments as Map<dynamic, dynamic>?;
              copiedText = args?['text'] as String?;
              return null;
            }
            return null;
          },
        );

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SupportDeveloperScreen())),
        );

        final copyBtn = find.text(AppStrings.supportCopyAction).last;
        await tester.ensureVisible(copyBtn);
        await tester.pumpAndSettle();

        // Tap the second Copy button (Telebirr)
        await tester.tap(copyBtn);
        await tester.pumpAndSettle();

        expect(copiedText, '0925036911');
        expect(find.text(AppStrings.supportTelebirrCopied), findsOneWidget);
      },
    );
  });
}
