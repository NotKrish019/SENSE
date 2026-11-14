// End-to-end on a device or emulator (Milestone E demonstration): the real app
// (SenseApp) on the REAL development namespace (Android Keystore + SQLCipher),
// driven through its UI: Onboarding -> Consent (M1, M3, M4 on) -> Check-in ->
// Sleep -> Workload -> process restart -> Insights. Development test data only.
//
// To show the sufficient-data state, phase 1 also writes a few earlier days of
// clearly synthetic DEVELOPMENT fixtures through the same consent-gated
// repositories (never participant data; the namespace is destroyed at the end).
// Today's entries are made through the screens.
//
//   flutter test integration_test/insights_end_to_end_test.dart -d emulator-5554 \
//       --no-uninstall --dart-define=SENSE_DEV_STORAGE=1 --dart-define=SENSE_E2E_PHASE=1
//   adb -s emulator-5554 shell am force-stop org.sense.mindpulse.dev
//   flutter test integration_test/insights_end_to_end_test.dart -d emulator-5554 \
//       --dart-define=SENSE_DEV_STORAGE=1 --dart-define=SENSE_E2E_PHASE=2
//
// An emulator Keystore is software-backed: not hardware-backed validation.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mindpulse/core/state/consent_preferences.dart';
import 'package:mindpulse/data/local/encrypted/encrypted_database.dart';
import 'package:mindpulse/data/local/sense_storage.dart';
import 'package:mindpulse/main.dart';

const int _phase = int.fromEnvironment('SENSE_E2E_PHASE');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final platform = createDefaultSecureKeyPlatform();
  final policy = SenseStoragePolicy.fromEnvironment();
  final prefs = ConsentPreferences.instance;

  Future<void> until(WidgetTester t, bool Function() done, String what, {int max = 300}) async {
    for (var i = 0; i < max && !done(); i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(done(), isTrue, reason: what);
    await t.pumpAndSettle();
  }

  bool shows(Finder f) => f.evaluate().isNotEmpty;

  Future<void> tapVisible(WidgetTester t, Finder f) async {
    await t.ensureVisible(f.first);
    await t.pumpAndSettle();
    await t.tap(f.first);
    await t.pumpAndSettle();
  }

  /// Scrolls the current page until [f] is built (lazily built content).
  Future<void> reveal(WidgetTester t, Finder f) async {
    for (var i = 0; i < 30 && f.evaluate().isEmpty; i++) {
      await t.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await t.pumpAndSettle();
    }
    expect(f, findsWidgets, reason: 'revealed');
  }

  /// Splash -> onboarding (Skip) -> consent -> Continue -> Home.
  Future<void> enterApp(WidgetTester t, SenseStorage storage, {bool turnOn = false}) async {
    await t.pumpWidget(SenseApp(storage: storage));
    await until(t, () => shows(find.text('Skip')), 'onboarding');
    await tapVisible(t, find.text('Skip'));
    await until(t, () => prefs.persistence == ConsentPersistence.persisted, 'consent loaded from storage');
    if (turnOn) {
      for (final (label, m) in [
        ('M1 · Structured check-ins', InputModality.checkIn),
        ('M3 · Sleep', InputModality.sleep),
        ('M4 · Workload', InputModality.workload),
      ]) {
        await tapVisible(t, find.text(label));
        await until(t, () => prefs.isEnabled(m), '$label on');
      }
    }
    await tapVisible(t, find.text('Continue to SENSE'));
    await until(t, () => shows(find.bySemanticsLabel('Insights tab')), 'home');
  }

  String date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  setUpAll(() {
    expect(currentBuildMode, BuildMode.debug);
    expect(kSenseDevStorageDefine, isTrue, reason: 'run with --dart-define=SENSE_DEV_STORAGE=1');
    expect(_phase, anyOf(1, 2), reason: 'pass --dart-define=SENSE_E2E_PHASE=1 or 2');
  });

  testWidgets('E2E phase $_phase', (t) async {
    final semantics = t.ensureSemantics();
    // Reduced motion (as in the widget tests): the Home landscape and the
    // splash then stand still, so frames settle.
    t.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final today = DateTime.now();
    final todayDate = date(today);

    if (_phase == 1) {
      final before = await platform.inspect(testNamespace: kDevelopmentStorageNamespace);
      if (before['databasePresent'] == true || before['envelopePresent'] == true || before['keyAliasPresent'] == true) {
        await EncryptedDatabaseProvider(testNamespace: kDevelopmentStorageNamespace).destroyKeyAndDatabase();
      }
      final storage = SenseStorage(policy: policy);
      await enterApp(t, storage, turnOn: true);
      final ready = storage.ready!;
      expect(ready.target, StorageTarget.development);
      expect(find.text('DEVELOPMENT DATA — NOT FOR PARTICIPANTS'), findsOneWidget);
      final person = ready.profile.localPersonId;

      // Earlier days: synthetic development fixtures through the consent-gated repositories.
      Provenance p(Set<String> all) => Provenance.fromChanged(allFields: all, changed: all, submittedAtUtc: DateTime.now().toUtc());
      LocalDay day(int back) => LocalDay.fromLocal(DateTime(today.year, today.month, today.day - back, 12));
      const moods = [2, 4, 3, 1, 3, 4, 2, 3]; // 8 earlier days, varied
      for (var i = 0; i < moods.length; i++) {
        await ready.store.checkIns.upsert(person,
            CheckInEntry(moodRating: moods[i], motivationEnergyRating: 3, perceivedStressRating: 2, day: day(i + 1), provenance: p(CheckInEntry.allFields)));
      }
      for (var i = 1; i <= 4; i++) {
        await ready.store.sleep.upsert(person, SleepEntry(durationMinutes: 420 + 30 * (i % 2), bedtimeLocal: '23:30', wakeTimeLocal: '07:00', restQuality: 3, day: day(i), provenance: p(SleepEntry.allFields)));
      }
      const demands = [2, 4, 3, 5, 3, 1, 4]; // 7 earlier days
      for (var i = 0; i < demands.length; i++) {
        await ready.store.workload.upsert(person,
            WorkloadEntry(mentalDemand: demands[i], effort: 3, deadlines48h: i % 3, day: day(i + 1), provenance: p(WorkloadEntry.allFields)));
      }

      // Today through the screens. Check-in: mood Great, then Finish.
      await tapVisible(t, find.bySemanticsLabel('New daily check-in'));
      await until(t, () => shows(find.bySemanticsLabel('Mood: Great')), 'check-in');
      await tapVisible(t, find.bySemanticsLabel('Mood: Great'));
      await tapVisible(t, find.text('Continue to stress rating'));
      await tapVisible(t, find.text('Finish check-in'));
      await until(t, () => shows(find.text('Check-in saved')), 'check-in saved');
      await tapVisible(t, find.text('Return to Home'));

      // Sleep: last night (woke today), saved under today's date.
      await reveal(t, find.bySemanticsLabel('Sleep. Duration, timing and rest'));
      await tapVisible(t, find.bySemanticsLabel('Sleep. Duration, timing and rest'));
      await until(t, () => shows(find.byKey(const Key('sleep-status'))) && !shows(find.text("Loading today's sleep entry.")), 'sleep');
      await tapVisible(t, find.bySemanticsLabel('Rest quality 5 of 5'));
      await tapVisible(t, find.text('Save Sleep Record'));
      await until(t, () => shows(find.textContaining("Last night's sleep was saved")), 'sleep saved');
      await tapVisible(t, find.byTooltip('Back'));

      // Workload: save, then save again AT ONCE: the button is not covered.
      WidgetController.hitTestWarningShouldBeFatal = true;
      await reveal(t, find.bySemanticsLabel('Workload. Demand, effort and deadlines'));
      await tapVisible(t, find.bySemanticsLabel('Workload. Demand, effort and deadlines'));
      await until(t, () => shows(find.byKey(const Key('workload-status'))) && !shows(find.text("Loading today's entry.")), 'workload');
      await tapVisible(t, find.text('Save Workload Rating'));
      await until(t, () => shows(find.textContaining("Today's workload entry was saved")), 'workload saved');
      expect(find.byType(SnackBar), findsNothing);
      await t.tap(find.byTooltip('One more deadline'));
      await t.pump();
      await t.tap(find.text('Save Workload Rating'));
      await until(t, () => shows(find.text("Today's workload entry was updated.")), 'workload updated at once');
      WidgetController.hitTestWarningShouldBeFatal = false;

      expect((await ready.store.checkIns.byDate(person, todayDate))!.entry.moodRating, 5);
      expect((await ready.store.sleep.byDate(person, todayDate))!.entry.restQuality, 5, reason: 'wake-up date = today');
      expect((await ready.store.workload.byDate(person, todayDate))!.entry.deadlines48h, 2);

      await t.pumpWidget(const SizedBox());
      await storage.close();
      storage.dispose();
      semantics.dispose();
      // ignore: avoid_print
      print('SENSE-E2E phase 1: consent on through the UI, check-in/sleep/workload saved for $todayDate');
      return;
    }

    // ---- Phase 2: a new process; the saved entries reach Insights ---------------------------
    final storage = SenseStorage(policy: policy);
    await enterApp(t, storage);
    expect([InputModality.checkIn, InputModality.sleep, InputModality.workload].every(prefs.isEnabled), isTrue,
        reason: 'consent persisted across the restart');
    await tapVisible(t, find.bySemanticsLabel('Insights tab'));
    await until(t, () => shows(find.byKey(const Key('insights-mood'))), 'insights read');

    String row(String v) => t
        .widgetList<Text>(find.descendant(of: find.byKey(Key('insights-$v')), matching: find.byType(Text)))
        .map((w) => w.data)
        .join(' | ');

    expect(find.textContaining('(development data)'), findsOneWidget);
    expect(find.text('Examples of future charts'), findsOneWidget, reason: 'samples separate and labelled');
    // Check-in: 8 fixture days + today (mood 5 from the screen): sufficient.
    expect(row('mood'), contains('9 of 14 days observed (7 required).'));
    expect(row('mood'), contains(': 5 of 5.'), reason: "today's entry, after the restart");
    // Sleep: 4 fixture days + today's (wake-up date): insufficient.
    expect(row('sleepDuration'), contains('Insufficient observations: 5 of 7 required'));
    // Workload: 7 fixture days + today: sufficient.
    expect(row('mentalDemand'), contains('8 of 14 days observed (7 required).'));

    Future<void> reopenInsights() async {
      await tapVisible(t, find.bySemanticsLabel('Home tab'));
      await tapVisible(t, find.bySemanticsLabel('Insights tab'));
      await until(t, () => shows(find.byKey(const Key('insights-window'))) && !shows(find.byKey(const Key('insights-loading'))), 'reread');
    }

    // Revoking each modality suppresses only that modality; re-enabling restores it.
    for (final (m, off, key) in [
      (InputModality.checkIn, 'insights-off-M1', 'mood'),
      (InputModality.sleep, 'insights-off-M3', 'sleepDuration'),
      (InputModality.workload, 'insights-off-M4', 'mentalDemand'),
    ]) {
      expect(await prefs.setEnabled(m, false), ConsentChangeResult.saved);
      await reopenInsights();
      expect(find.byKey(Key(off)), findsOneWidget, reason: '${m.code} off');
      expect(find.byKey(Key('insights-$key')), findsNothing);
      final others = {'mood', 'sleepDuration', 'mentalDemand'}..remove(key);
      for (final o in others) {
        expect(find.byKey(Key('insights-$o')), findsOneWidget, reason: '${m.code} off must not hide $o');
      }
      expect(await prefs.setEnabled(m, true), ConsentChangeResult.saved);
      await reopenInsights();
      expect(find.byKey(Key('insights-$key')), findsOneWidget, reason: '${m.code} back on');
    }
    // The records were never deleted by the revocations.
    final ready = storage.ready!;
    expect((await ready.store.sleep.byDate(ready.profile.localPersonId, todayDate)), isNotNull);

    await t.pumpWidget(const SizedBox());
    await storage.close();
    storage.dispose();
    final d = await EncryptedDatabaseProvider(testNamespace: kDevelopmentStorageNamespace).destroyKeyAndDatabase();
    expect(d.cryptographicallyErased, isTrue);
    final p = await platform.inspect();
    for (final k in ['databasePresent', 'envelopePresent', 'keyAliasPresent']) {
      expect(p[k], isFalse, reason: 'participant $k');
    }
    semantics.dispose();
    // ignore: avoid_print
    print('SENSE-E2E phase 2: saved entries reached Insights after restart; per-modality revocation and '
        're-enable verified; development namespace destroyed');
  });
}
