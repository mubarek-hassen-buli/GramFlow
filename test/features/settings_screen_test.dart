import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/channels/presentation/channel_providers.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/features/settings/data/app_settings.dart';
import 'package:gramx/features/settings/data/settings_store.dart';
import 'package:gramx/features/settings/data/storage_repository.dart';
import 'package:gramx/features/settings/presentation/settings_screen.dart';
import 'package:gramx/features/settings/presentation/support_developer_screen.dart';

class _FakeSettingsNotifier extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
}

void main() {
  group('SettingsScreen About section', () {
    testWidgets(
      'renders Support Developer AKA Mubarek and excludes GitHub / licenses',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsProvider.overrideWith(_FakeSettingsNotifier.new),
              activeAccountProvider.overrideWith((ref) => Stream.value(null)),
              storageUsageProvider.overrideWith(
                (ref) => Future.value(StorageUsage.empty),
              ),
              isGuestModeProvider.overrideWith((ref) => false),
            ],
            child: const MaterialApp(home: SettingsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Ensure the About section is scrolled into view
        final supportFinder = find.text(AppStrings.settingsSupport);
        await tester.scrollUntilVisible(
          supportFinder,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        // Verified: "Support the Developer AKA Mubarek" is displayed
        expect(supportFinder, findsOneWidget);
        expect(find.text(AppStrings.settingsSupportBody), findsOneWidget);

        // Verified: "Contribute on GitHub" and "Open-source licenses" are removed
        expect(find.text(AppStrings.settingsSource), findsNothing);
        expect(find.text(AppStrings.settingsSourceBody), findsNothing);
        expect(find.text(AppStrings.settingsLicenses), findsNothing);
        expect(find.text(AppStrings.settingsLicensesBody), findsNothing);

        // Verified: Privacy, Terms, and Version remain
        expect(find.text(AppStrings.settingsPrivacy), findsOneWidget);
        expect(find.text(AppStrings.settingsTerms), findsOneWidget);
        expect(find.text(AppStrings.settingsVersion), findsOneWidget);
      },
    );

    testWidgets('tapping Support tile navigates to SupportDeveloperScreen', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/settings',
        routes: [
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: SupportDeveloperScreen.route,
            builder: (context, state) => const SupportDeveloperScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(_FakeSettingsNotifier.new),
            activeAccountProvider.overrideWith((ref) => Stream.value(null)),
            storageUsageProvider.overrideWith(
              (ref) => Future.value(StorageUsage.empty),
            ),
            isGuestModeProvider.overrideWith((ref) => false),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      final supportFinder = find.text(AppStrings.settingsSupport);
      await tester.scrollUntilVisible(
        supportFinder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(supportFinder);
      await tester.pumpAndSettle();

      // Verified navigation landed on SupportDeveloperScreen
      expect(find.byType(SupportDeveloperScreen), findsOneWidget);
      expect(find.text(AppStrings.supportHeaderTitle), findsOneWidget);
      expect(find.text(AppStrings.supportCbeAccount), findsOneWidget);
      expect(find.text(AppStrings.supportTelebirrAccount), findsOneWidget);
    });
  });
}
