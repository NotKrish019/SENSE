// K3 final corrections, applied to the K2 Workload screen: save-state
// integrity. A save is held open with a Completer (no timing), so the
// in-flight state is observed deterministically.

import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse/core/state/consent_preferences.dart';
import 'package:mindpulse/core/state/workload_controller.dart';
import 'package:mindpulse/core/theme/app_theme.dart';
import 'package:mindpulse/data/local/sense_storage.dart';
import 'package:mindpulse/presentation/screens/workload_screen.dart';

import 'support/fake_workload_access.dart';

void main() {
  final morning = DateTime(2026, 11, 11, 9, 30);
  final tz = morning.timeZoneOffset.inMinutes;
  const today = '2026-11-11';
  const save = 'Save Workload Rating';

  late FakeWorkloadAccess access;
  setUp(() => access = FakeWorkloadAccess());
  tearDown(() => ConsentPreferences.instance.reset());

  Future<WorkloadController> pumpPushed(WidgetTester t) async {
    t.view.physicalSize = const Size(412 * 3, 3000 * 3);
    t.view.devicePixelRatio = 3.0;
    t.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final c = WorkloadController(access: access, now: () => morning);
    addTearDown(c.dispose);
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkloadScreen(controller: c))),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    return c;
  }

  SemanticsData sem(WidgetTester t, Finder f) => t.getSemantics(f).getSemanticsData();
  bool enabled(SemanticsData d) => d.flagsCollection.isEnabled == Tristate.isTrue;
  SemanticsData slider(WidgetTester t, int i) => sem(t, find.byType(Slider).at(i)); // 0 demand, 1 effort

  /// Sets demand 4, effort 2, deadlines 3, then holds the save open.
  Future<WorkloadController> startHeldSave(WidgetTester t) async {
    final c = await pumpPushed(t);
    c.setMentalDemand(4);
    c.setEffort(2);
    c.incrementDeadlines();
    c.incrementDeadlines();
    await t.pump();
    access.saveGate = Completer<void>();
    await t.ensureVisible(find.text(save));
    await t.pumpAndSettle();
    await t.tap(find.text(save));
    await t.pump();
    expect(c.isSaving, isTrue);
    return c;
  }

  void expectInputsEnabled(WidgetTester t, bool on) {
    expect(enabled(slider(t, 0)), on, reason: 'mental demand');
    expect(enabled(slider(t, 1)), on, reason: 'effort');
    expect(enabled(sem(t, find.bySemanticsLabel('One more deadline'))), on, reason: 'increment');
    expect(enabled(sem(t, find.bySemanticsLabel('One fewer deadline'))), on, reason: 'decrement');
    expect(enabled(sem(t, find.bySemanticsLabel(save))), on, reason: 'Save');
    expect(enabled(sem(t, find.byTooltip('Back'))), on, reason: 'page back control');
  }

  group('While a workload rating is saving', () {
    testWidgets('both sliders, both deadline buttons, Save and Back are disabled; a busy indicator shows',
        (t) async {
      final h = t.ensureSemantics();
      await startHeldSave(t);
      expectInputsEnabled(t, false);
      expect(find.byKey(const Key('workload-busy')), findsOneWidget);
      expect(find.text('Saving your workload rating.'), findsOneWidget);
      access.saveGate!.complete();
      await t.pumpAndSettle();
      expectInputsEnabled(t, true);
      h.dispose();
    });

    testWidgets('taps and direct changes during the save change nothing; one write', (t) async {
      final c = await startHeldSave(t);
      await t.tap(find.byTooltip('One more deadline'), warnIfMissed: false);
      await t.tap(find.byTooltip('One fewer deadline'), warnIfMissed: false);
      for (var i = 0; i < 3; i++) {
        await t.tap(find.text(save), warnIfMissed: false);
      }
      c.setMentalDemand(1);
      c.setEffort(5);
      c.incrementDeadlines();
      c.decrementDeadlines();
      await t.pump();
      expect([c.mentalDemand, c.effort, c.deadlines], [4, 2, 3]);
      access.saveGate!.complete();
      await t.pumpAndSettle();
      expect(access.saveCalls, hasLength(1));
      expect(access.records, hasLength(1));
    });

    testWidgets('system back cannot leave and discard the in-flight save', (t) async {
      await startHeldSave(t);
      await t.binding.handlePopRoute();
      await t.pump();
      expect(find.byType(WorkloadScreen), findsOneWidget);
      access.saveGate!.complete();
      await t.pumpAndSettle();
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.byType(WorkloadScreen), findsNothing, reason: 'leaving works again once saved');
    });

    testWidgets('"saved" describes exactly the committed values shown on screen', (t) async {
      final h = t.ensureSemantics();
      final c = await startHeldSave(t);
      c.setEffort(5); // refused while saving
      access.saveGate!.complete();
      await t.pumpAndSettle();
      final e = access.records[today]!.entry;
      expect([e.mentalDemand, e.effort, e.deadlines48h], [4, 2, 3]);
      expect(e.day, LocalDay(today, tz));
      expect(c.phase, WorkloadPhase.saved);
      expect(slider(t, 0).value, '4 of 5');
      expect(slider(t, 1).value, '2 of 5');
      expect(find.bySemanticsLabel('3 deadlines'), findsOneWidget);
      expect(find.textContaining("Today's workload entry was saved"), findsWidgets);
      h.dispose();
    });

    testWidgets('"updated" describes exactly the committed values shown on screen', (t) async {
      final h = t.ensureSemantics();
      access.seed(today, tz, demand: 1, effort: 1, deadlines: 0, changed: WorkloadEntry.allFields);
      final c = await startHeldSave(t);
      c.decrementDeadlines(); // refused while saving
      access.saveGate!.complete();
      await t.pumpAndSettle();
      final r = access.records[today]!;
      expect(r.id, 'existing-id');
      expect([r.entry.mentalDemand, r.entry.effort, r.entry.deadlines48h], [4, 2, 2]);
      expect([c.mentalDemand, c.effort, c.deadlines], [4, 2, 2]);
      expect(c.phase, WorkloadPhase.updated);
      expect(find.text("Today's workload entry was updated."), findsWidgets);
      h.dispose();
    });

    testWidgets('a failed save keeps the form, re-enables every control and claims nothing', (t) async {
      final h = t.ensureSemantics();
      access.saveOutcome = const WorkloadSaveFailed();
      final c = await startHeldSave(t);
      expectInputsEnabled(t, false);
      access.saveGate!.complete();
      await t.pumpAndSettle();
      expect([c.mentalDemand, c.effort, c.deadlines], [4, 2, 3]);
      expect(slider(t, 0).value, '4 of 5');
      expect(find.textContaining('entry was saved'), findsNothing);
      expect(find.textContaining('could not be saved'), findsWidgets);
      expectInputsEnabled(t, true);
      h.dispose();
    });
  });
}
