// Milestone K1: the Consent screen, Settings, onboarding and the development
// banner with repository-backed preferences. Storage is the test-only
// FakeSecureKeyPlatform (disposable plain SQLite through sqflite_common_ffi);
// real I/O runs inside `runAsync`.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse/core/state/consent_preferences.dart';
import 'package:mindpulse/core/theme/app_theme.dart';
import 'package:mindpulse/data/local/encrypted/encrypted_database.dart';
import 'package:mindpulse/data/local/sense_storage.dart';
import 'package:mindpulse/main.dart';
import 'package:mindpulse/presentation/screens/consent_screen.dart';
import 'package:mindpulse/presentation/screens/main_shell.dart';
import 'package:mindpulse/presentation/screens/onboarding_screen.dart';
import 'package:mindpulse/presentation/screens/settings_screen.dart';
import 'package:mindpulse/presentation/screens/splash_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fake_secure_key_platform.dart';

const _debugDev = SenseStoragePolicy(buildMode: BuildMode.debug, developmentDefine: true);

void main() {
  final prefs = ConsentPreferences.instance;
  late Directory dir;

  setUpAll(sqfliteFfiInit);
  setUp(() {
    prefs.reset();
    dir = Directory.systemTemp.createTempSync('sense_k1_ui_');
  });
  tearDown(() {
    prefs.reset();
    dir.deleteSync(recursive: true);
  });

  void view(WidgetTester t) {
    t.view.physicalSize = const Size(412 * 3, 915 * 3);
    t.view.devicePixelRatio = 3.0;
    t.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  /// Lets real (database) I/O finish. Work started from a tap runs in the
  /// test's fake-async zone, so real time (runAsync) and frame pumps (which
  /// run that zone's pending continuations) alternate until [done].
  Future<void> settle(WidgetTester t, bool Function() done) async {
    for (var i = 0; i < 300 && !done(); i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await t.pump();
    }
    await t.pumpAndSettle();
    expect(done(), isTrue, reason: 'condition not reached');
  }

  /// Development storage, open, with the shared preferences attached and loaded.
  Future<(SenseStorage, StorageReady?)> devStorage(WidgetTester t, {String? failWith}) async {
    final storage = SenseStorage(policy: _debugDev, platform: FakeSecureKeyPlatform(dir, failWith: failWith));
    prefs.attach(storage);
    await t.runAsync(storage.start);
    addTearDown(() => t.runAsync(storage.close));
    if (failWith == null) {
      await settle(t, () => prefs.persistence == ConsentPersistence.persisted);
      return (storage, storage.ready!);
    }
    return (storage, null);
  }

  Future<List<String>> events(WidgetTester t, StorageReady ready) async =>
      (await t.runAsync(() => ready.store.consent.history(ready.profile.localPersonId)))!
          .map((e) => '${e.modality}:${e.enabled}')
          .toList();

  Future<void> tapVisible(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  /// Taps a consent choice with the save running on real time (not in the
  /// fake-async zone), waits until [done], then rebuilds.
  Future<void> tapAndSave(WidgetTester t, Finder f, bool Function() done) async {
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.runAsync(() async {
      await t.tap(f);
      for (var i = 0; i < 300 && !done(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await t.pumpAndSettle();
    expect(done(), isTrue, reason: 'save not completed');
  }

  Future<void> pumpScreen(WidgetTester t, Widget home) async {
    view(t);
    await t.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: home));
    await t.pumpAndSettle();
  }

  group('Consent screen with storage', () {
    testWidgets('development storage: each change is saved first, then shown', (t) async {
      final ready = (await devStorage(t)).$2!;
      await pumpScreen(t, const ConsentScreen());
      expect(find.text('0 of 6 inputs turned on (saved to development storage).'), findsOneWidget);
      expect(find.textContaining('saved to development storage on this device, an encrypted test database'),
          findsOneWidget);
      expect(find.textContaining('kept only while the app is open'), findsNothing);

      await tapAndSave(t, find.text('M3 · Sleep'),
          () => prefs.isEnabled(InputModality.sleep) && !prefs.isPending(InputModality.sleep));
      expect(find.text('1 of 6 inputs turned on (saved to development storage).'), findsOneWidget);
      expect(await events(t, ready), ['M3:true']);
    });

    testWidgets('a failed save shows a message and leaves the choice unchanged', (t) async {
      final ready = (await devStorage(t)).$2!;
      await t.runAsync(() => ready.database.execute(
          "CREATE TRIGGER k1_block BEFORE INSERT ON consent_events BEGIN SELECT RAISE(ABORT, 'blocked'); END"));
      await pumpScreen(t, const ConsentScreen());
      await tapVisible(t, find.text('M4 · Workload'));
      await settle(t, () => find.byType(SnackBar).evaluate().isNotEmpty);
      expect(find.text('Your choice for Workload could not be saved, so nothing was changed.'), findsOneWidget);
      expect(prefs.isEnabled(InputModality.workload), isFalse);
      expect(find.text('0 of 6 inputs turned on (saved to development storage).'), findsOneWidget);
      expect(await events(t, ready), isEmpty);
    });

    testWidgets('secure storage unavailable: in memory, and says so', (t) async {
      await devStorage(t, failWith: 'insecureKeyStorage');
      expect(prefs.persistence, ConsentPersistence.storageUnavailable);
      await pumpScreen(t, const ConsentScreen());
      expect(find.text('0 of 6 inputs turned on (kept only while the app is open; secure storage unavailable).'),
          findsOneWidget);
      expect(find.textContaining('Secure storage is unavailable, so your choices are kept only while the app is open'),
          findsOneWidget);
      await tapVisible(t, find.text('M3 · Sleep'));
      expect(prefs.isEnabled(InputModality.sleep), isTrue, reason: 'in memory, labelled not saved');
    });

    testWidgets('without storage the original in-memory wording is unchanged', (t) async {
      await pumpScreen(t, const ConsentScreen());
      expect(find.text('0 of 6 inputs turned on (kept only while the app is open).'), findsOneWidget);
      expect(
          find.text('Your choices are kept only while the app is open. They are not saved and are lost if you '
              'refresh or close it.'),
          findsOneWidget);
    });

    testWidgets('Settings states where the choices are kept', (t) async {
      await devStorage(t);
      await t.runAsync(() => prefs.setEnabled(InputModality.workload, true));
      await pumpScreen(t, const SettingsScreen());
      expect(find.text('Currently on: M4 Workload (saved to development storage)'), findsOneWidget);
    });
  });

  group('Development banner', () {
    testWidgets('shown on every route while development storage is enabled', (t) async {
      view(t);
      // The banner follows the build policy alone, so this needs no database:
      // development storage is enabled, and the platform is unsupported.
      final storage = SenseStorage(policy: _debugDev, platform: FakeSecureKeyPlatform(dir, supported: false));
      await t.pumpWidget(SenseApp(storage: storage));
      await t.pump();
      expect(find.text(kDevelopmentStorageLabel), findsOneWidget);
      expect(find.byKey(const Key('development-storage-banner')), findsOneWidget);
      await t.pump(SplashScreen.duration);
      await t.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('DEVELOPMENT DATA — NOT FOR PARTICIPANTS'), findsOneWidget);
      expect(storage.state, isA<StorageUnavailable>());
      expect(prefs.persistence, ConsentPersistence.memoryOnly, reason: 'unsupported: nothing saved');
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('absent by default (no define): nothing is opened', (t) async {
      view(t);
      await t.pumpWidget(const SenseApp());
      expect(find.text(kDevelopmentStorageLabel), findsNothing);
      expect(prefs.persistence, ConsentPersistence.memoryOnly);
      await t.pump(SplashScreen.duration);
      await t.pumpAndSettle();
    });
  });

  group('Onboarding with persisted consent', () {
    late SenseStorage storage;

    /// Unmounts the app, then closes storage on real time.
    Future<void> finish(WidgetTester t) async {
      await t.pumpWidget(const SizedBox());
      await t.runAsync(storage.close);
    }

    Future<StorageReady> launch(WidgetTester t) async {
      view(t);
      storage = SenseStorage(policy: _debugDev, platform: FakeSecureKeyPlatform(dir));
      // Open and load on real time; SenseApp's own attach is then a no-op.
      await t.runAsync(() async {
        prefs.attach(storage);
        await storage.start();
        for (var i = 0; i < 300 && prefs.persistence != ConsentPersistence.persisted; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await t.pumpWidget(SenseApp(storage: storage));
      await t.pump();
      expect(prefs.persistence, ConsentPersistence.persisted);
      await t.pump(SplashScreen.duration);
      await t.pumpAndSettle();
      await tapVisible(t, find.text('Continue'));
      await tapVisible(t, find.text('Continue'));
      await tapVisible(t, find.text('Get Started'));
      expect(find.byType(ConsentScreen), findsOneWidget);
      return storage.ready!;
    }

    testWidgets('finishing onboarding without choosing records nothing and leaves everything OFF', (t) async {
      final ready = await launch(t);
      await tapVisible(t, find.text('Continue to SENSE'));
      expect(find.byType(MainShell), findsOneWidget);
      expect(await events(t, ready), isEmpty, reason: 'no accidental mass opt-in');
      expect(InputModality.values.map(prefs.isEnabled), everyElement(isFalse));
      await finish(t);
    });

    testWidgets('only explicit choices are recorded, each as its own event', (t) async {
      final ready = await launch(t);
      await tapAndSave(t, find.text('M1 · Structured check-ins'),
          () => prefs.isEnabled(InputModality.checkIn) && !prefs.isPending(InputModality.checkIn));
      await tapAndSave(t, find.text('M4 · Workload'),
          () => prefs.isEnabled(InputModality.workload) && !prefs.isPending(InputModality.workload));
      // Changing a mind is a new event; earlier events are kept (the latest wins).
      await tapAndSave(t, find.text('M1 · Structured check-ins'),
          () => !prefs.isEnabled(InputModality.checkIn) && !prefs.isPending(InputModality.checkIn));
      expect(await events(t, ready), ['M1:true', 'M4:true', 'M1:false']);
      expect({for (final m in InputModality.values) if (prefs.isEnabled(m)) m}, {InputModality.workload});
      await tapVisible(t, find.text('Continue to SENSE'));
      expect(find.byType(MainShell), findsOneWidget);
      await finish(t);
    });
  });
}
