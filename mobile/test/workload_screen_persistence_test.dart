// Milestone K2: the Workload screen connected to WorkloadController.
// Most cases inject a controller over a programmable WorkloadAccess; the last
// group runs the real storage owner (FakeSecureKeyPlatform, disposable plain
// SQLite through sqflite_common_ffi) under SenseStorageScope, as the app does.
// The unconnected prototype behaviour ("not saved") stays covered by the
// existing Phase 3 and honesty tests, which pump the screen without storage.

import 'dart:async';
import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse/core/constants/prototype_copy.dart';
import 'package:mindpulse/core/state/consent_preferences.dart';
import 'package:mindpulse/core/state/workload_controller.dart';
import 'package:mindpulse/core/theme/app_theme.dart';
import 'package:mindpulse/data/local/encrypted/encrypted_database.dart';
import 'package:mindpulse/data/local/sense_storage.dart';
import 'package:mindpulse/presentation/screens/consent_screen.dart';
import 'package:mindpulse/presentation/screens/workload_screen.dart';
import 'package:mindpulse/presentation/widgets/sense_storage_scope.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fake_secure_key_platform.dart';
import 'support/fake_workload_access.dart';

void main() {
  final morning = DateTime(2026, 11, 11, 9, 30);
  final tz = morning.timeZoneOffset.inMinutes;
  const today = '2026-11-11';
  const saveLabel = 'Save Workload Rating';

  late FakeWorkloadAccess access;
  setUp(() => access = FakeWorkloadAccess());
  tearDown(() => ConsentPreferences.instance.reset());

  void view(WidgetTester t, {double height = 3000}) {
    t.view.physicalSize = Size(412 * 3, height * 3);
    t.view.devicePixelRatio = 3.0;
    t.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  Future<WorkloadController> pumpScreen(WidgetTester t, {FakeWorkloadAccess? a, bool settle = true}) async {
    view(t);
    final c = WorkloadController(access: a ?? access, now: () => morning);
    addTearDown(c.dispose);
    await t.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: WorkloadScreen(controller: c)));
    if (settle) await t.pumpAndSettle();
    return c;
  }

  SemanticsNode node(WidgetTester t, String label) => t.getSemantics(find.bySemanticsLabel(label).first);
  bool enabled(SemanticsNode n) => n.getSemanticsData().flagsCollection.isEnabled == Tristate.isTrue;
  String status(WidgetTester t) => t.widget<Text>(find.byKey(const Key('workload-status'))).data!;
  bool saveEnabled(WidgetTester t) => enabled(node(t, saveLabel));

  Future<void> tapSave(WidgetTester t) async {
    await t.ensureVisible(find.text(saveLabel));
    await t.pumpAndSettle();
    await t.tap(find.text(saveLabel));
    await t.pumpAndSettle();
  }

  Finder savedClaim() => find.byWidgetPredicate((w) =>
      w is Text && RegExp(r'entry was (saved|updated)', caseSensitive: false).hasMatch(w.data ?? ''));

  group('Initial state and inputs', () {
    testWidgets('defaults, honest status, Save enabled, no not-saved prototype note', (t) async {
      final h = t.ensureSemantics();
      await pumpScreen(t);
      expect(
          find.bySemanticsLabel('Your ratings (self-reported): mental demand 3 of 5, effort 3 of 5, 1 deadline'),
          findsOneWidget);
      expect(node(t, 'Mental demand').getSemanticsData().value, '3 of 5');
      expect(node(t, 'Effort').getSemanticsData().value, '3 of 5');
      expect(status(t), startsWith('No workload entry saved today yet.'));
      expect(status(t), contains('development storage'));
      expect(find.text(PrototypeCopy.notStoredYet), findsNothing);
      expect(saveEnabled(t), isTrue);
      expect(savedClaim(), findsNothing);
      h.dispose();
    });

    testWidgets('mental demand and effort change through the sliders', (t) async {
      final h = t.ensureSemantics();
      final c = await pumpScreen(t);
      t.semantics.performAction(find.semantics.byLabel('Mental demand'), SemanticsAction.increase);
      await t.pumpAndSettle();
      t.semantics.performAction(find.semantics.byLabel('Effort'), SemanticsAction.decrease);
      await t.pumpAndSettle();
      expect(node(t, 'Mental demand').getSemanticsData().value, '4 of 5');
      expect([c.mentalDemand, c.effort], [4, 2]);
      expect(c.changedFields, {'mental_demand', 'effort'});
      h.dispose();
    });

    testWidgets('deadline stepper: decrease to 0 (disabled), increase capped at 20 (disabled)', (t) async {
      final h = t.ensureSemantics();
      final c = await pumpScreen(t);
      t.semantics.tap(find.semantics.byLabel('One fewer deadline'));
      await t.pumpAndSettle();
      expect(find.bySemanticsLabel('0 deadlines'), findsOneWidget);
      expect(enabled(node(t, 'One fewer deadline')), isFalse);
      for (var i = 0; i < 20; i++) {
        t.semantics.tap(find.semantics.byLabel('One more deadline'));
        await t.pump();
      }
      await t.pumpAndSettle();
      expect(c.deadlines, 20);
      expect(find.bySemanticsLabel('20 deadlines'), findsOneWidget);
      expect(enabled(node(t, 'One more deadline')), isFalse);
      await t.tap(find.byTooltip('One more deadline'));
      await t.pumpAndSettle();
      expect(c.deadlines, 20);
      h.dispose();
    });
  });

  group('Saving', () {
    testWidgets('first save: success only after the write; saved wording; one record', (t) async {
      final c = await pumpScreen(t);
      c.setMentalDemand(5);
      await t.pump();
      await tapSave(t);
      expect(access.records, hasLength(1));
      expect(access.saveCalls.single.day, LocalDay(today, tz));
      expect(find.text("Today's workload entry was saved in development storage. Development data, not for participants."),
          findsOneWidget); // inline in the status line (no overlay)
      expect(c.phase, WorkloadPhase.saved);
    });

    testWidgets('existing entry is prefilled; saving says updated and keeps the same record', (t) async {
      access.seed(today, tz, demand: 2, effort: 4, deadlines: 0, changed: WorkloadEntry.allFields);
      final h = t.ensureSemantics();
      final c = await pumpScreen(t);
      expect(node(t, 'Mental demand').getSemanticsData().value, '2 of 5');
      expect(node(t, 'Effort').getSemanticsData().value, '4 of 5');
      expect(find.bySemanticsLabel('0 deadlines'), findsOneWidget);
      expect(status(t), startsWith('You already saved a workload entry today.'));
      t.semantics.tap(find.semantics.byLabel('One more deadline'));
      await t.pumpAndSettle();
      await tapSave(t);
      expect(find.text("Today's workload entry was updated."), findsOneWidget);
      expect(access.records[today]!.id, 'existing-id');
      expect(access.records, hasLength(1));
      expect(c.existingEntry!.entry.deadlines48h, 1);
      h.dispose();
    });

    testWidgets('loading: status says so and Save is disabled until today is read', (t) async {
      final h = t.ensureSemantics();
      access.loadGate = Completer<void>();
      await pumpScreen(t, settle: false);
      await t.pump();
      expect(status(t), "Loading today's entry.");
      expect(find.byKey(const Key('workload-busy')), findsOneWidget);
      expect(saveEnabled(t), isFalse);
      access.loadGate!.complete();
      await t.pumpAndSettle();
      expect(saveEnabled(t), isTrue);
      expect(find.byKey(const Key('workload-busy')), findsNothing);
      h.dispose();
    });

    testWidgets('saving: indicator, Save disabled, no saved claim; a double tap writes once', (t) async {
      final h = t.ensureSemantics();
      await pumpScreen(t);
      access.saveGate = Completer<void>();
      await t.ensureVisible(find.text(saveLabel));
      await t.pumpAndSettle();
      await t.tap(find.text(saveLabel));
      await t.pump();
      await t.tap(find.text(saveLabel), warnIfMissed: false);
      await t.pump();
      expect(status(t), 'Saving your workload rating.');
      expect(find.byKey(const Key('workload-busy')), findsOneWidget);
      expect(saveEnabled(t), isFalse);
      expect(savedClaim(), findsNothing);
      access.saveGate!.complete();
      await t.pumpAndSettle();
      expect(access.saveCalls, hasLength(1));
      expect(access.records, hasLength(1));
      expect(savedClaim(), findsWidgets);
      h.dispose();
    });

    testWidgets('consent denied: clear message, values kept, link opens the consent preferences', (t) async {
      access.saveOutcome = const WorkloadConsentDenied(ConsentDenialReason.notRecorded);
      final c = await pumpScreen(t);
      c.setEffort(5);
      await t.pump();
      await tapSave(t);
      const msg = 'Workload is turned off in your data and consent preferences, so nothing was saved.';
      expect(find.text(msg), findsOneWidget);
      expect(c.effort, 5);
      expect(savedClaim(), findsNothing);
      await t.ensureVisible(find.text('Review data and consent preferences'));
      await t.pumpAndSettle();
      await t.tap(find.text('Review data and consent preferences'));
      await t.pumpAndSettle();
      expect(find.byType(ConsentScreen), findsOneWidget);
      expect(ConsentPreferences.instance.isEnabled(InputModality.workload), isFalse, reason: 'never enabled silently');
    });

    testWidgets('storage unavailable: message, nothing written, no saved claim', (t) async {
      await pumpScreen(t, a: FakeWorkloadAccess(status: WorkloadStorageStatus.unavailable));
      expect(status(t), startsWith('Secure storage is unavailable'));
      await tapSave(t);
      expect(find.textContaining('Secure storage is unavailable'), findsOneWidget);
      expect(savedClaim(), findsNothing);
    });

    testWidgets('a failed write keeps the values on screen and claims nothing', (t) async {
      final h = t.ensureSemantics();
      access.saveOutcome = const WorkloadSaveFailed();
      final c = await pumpScreen(t);
      c.setMentalDemand(1);
      c.incrementDeadlines();
      await t.pump();
      await tapSave(t);
      expect(find.text('Your workload rating could not be saved. Your answers are still here, so you can try again.'),
          findsOneWidget);
      expect(node(t, 'Mental demand').getSemanticsData().value, '1 of 5');
      expect(find.bySemanticsLabel('2 deadlines'), findsOneWidget);
      expect(savedClaim(), findsNothing);
      expect(saveEnabled(t), isTrue, reason: 'the person can retry');
      h.dispose();
    });

    testWidgets('not connected by this build: the prototype note and not-saved message, unchanged', (t) async {
      await pumpScreen(t, a: FakeWorkloadAccess(status: WorkloadStorageStatus.notConnected));
      expect(find.text(PrototypeCopy.notStoredYet), findsOneWidget);
      expect(find.byKey(const Key('workload-status')), findsNothing);
      await tapSave(t);
      expect(find.text(PrototypeCopy.notSaved('workload rating')), findsOneWidget);
    });
  });

  group('Real storage owner under SenseStorageScope (host fake platform)', () {
    late Directory dir;
    setUpAll(sqfliteFfiInit);
    setUp(() => dir = Directory.systemTemp.createTempSync('sense_k2_ui_'));
    tearDown(() => dir.deleteSync(recursive: true));

    Future<void> settle(WidgetTester t, bool Function() done) async {
      for (var i = 0; i < 300 && !done(); i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await t.pump();
      }
      await t.pumpAndSettle();
      expect(done(), isTrue, reason: 'condition not reached');
    }

    testWidgets('M4 on: Save writes through the repository; M4 off: denied, earlier record kept', (t) async {
      view(t);
      final storage = SenseStorage(
          policy: const SenseStoragePolicy(buildMode: BuildMode.debug, developmentDefine: true),
          platform: FakeSecureKeyPlatform(dir));
      final ready = (await t.runAsync(storage.start))! as StorageReady;
      addTearDown(() => t.runAsync(storage.close));
      final person = ready.profile.localPersonId;
      await t.runAsync(() => ready.store.consent.recordChange(person, 'M4', true));

      await t.pumpWidget(SenseStorageScope(
        storage: storage,
        child: MaterialApp(theme: AppTheme.lightTheme, home: const WorkloadScreen()),
      ));
      await settle(t, () => find.textContaining('No workload entry saved today yet').evaluate().isNotEmpty);

      await t.ensureVisible(find.text(saveLabel));
      await t.pumpAndSettle();
      await t.tap(find.text(saveLabel));
      await settle(t, () => find.textContaining('was saved in development storage').evaluate().isNotEmpty);
      final day = LocalDay.fromLocal(DateTime.now()).date;
      final stored = (await t.runAsync(() => ready.store.workload.byDate(person, day)))!;
      expect([stored.entry.mentalDemand, stored.entry.effort, stored.entry.deadlines48h], [3, 3, 1]);
      expect(stored.entry.provenance.defaultFields, WorkloadEntry.allFields);

      await t.runAsync(() => ready.store.consent.recordChange(person, 'M4', false));
      await t.tap(find.byTooltip('One more deadline'));
      await t.pumpAndSettle();
      await t.tap(find.text(saveLabel));
      await settle(t, () => find.textContaining('Workload is turned off').evaluate().isNotEmpty);
      final kept = (await t.runAsync(() => ready.store.workload.byDate(person, day)))!;
      expect(kept.entry.deadlines48h, 1);
      expect(kept.id, stored.id);
    });
  });
}
