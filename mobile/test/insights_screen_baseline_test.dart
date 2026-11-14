// Milestone E: the Insights screen's personal baseline section, rendered from
// an injected InsightsController over a scripted read-only InsightsAccess.
// Deterministic: no timers; reads complete in the test's own zone, or are held
// with a Completer.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse/core/state/insights_controller.dart';
import 'package:mindpulse/core/theme/app_theme.dart';
import 'package:mindpulse/data/local/sense_storage.dart';
import 'package:mindpulse/presentation/screens/insights_screen.dart';

final _now = DateTime(2026, 11, 11, 21);

class _Access implements InsightsAccess {
  @override
  InsightsStorageStatus status;
  ObservationWindowOutcome outcome;
  Completer<void>? gate;
  int calls = 0;
  final _listeners = <void Function()>[];
  _Access(this.outcome, {this.status = InsightsStorageStatus.open});

  @override
  bool get isDevelopment => true;
  @override
  Future<ObservationWindowOutcome> loadWindow({required String fromDate, required String toDate}) async {
    calls++;
    if (gate != null) await gate!.future;
    return outcome;
  }

  @override
  void addListener(void Function() l) => _listeners.add(l);
  @override
  void removeListener(void Function() l) => _listeners.remove(l);
}

StoredRecord<T> _stored<T extends DailyEntry>(T e) => StoredRecord<T>(
    id: 'id-${e.day.date}',
    localPersonId: 'p',
    createdAtUtc: DateTime.utc(2026, 11, 1),
    updatedAtUtc: DateTime.utc(2026, 11, 1),
    schemaVersion: 2,
    entry: e);

Provenance _p(Set<String> all) => Provenance.fromChanged(allFields: all, changed: all, submittedAtUtc: DateTime.utc(2026, 11, 1));

/// Check-ins on 7 days (mood varies, 5 on 11 Nov; stress always 2, so no
/// spread); 5 sleep records (insufficient); workload consent off.
ObservationWindowLoaded _fixture() => ObservationWindowLoaded(
      checkInRecords: ModalityRecordsAvailable([
        for (final (d, mood) in [(1, 2), (3, 4), (4, 3), (6, 1), (8, 3), (9, 4), (11, 5)])
          _stored(CheckInEntry(
              moodRating: mood,
              motivationEnergyRating: 3,
              perceivedStressRating: 2,
              day: LocalDay('2026-11-${d.toString().padLeft(2, '0')}', 0),
              provenance: _p(CheckInEntry.allFields))),
      ]),
      sleepRecords: ModalityRecordsAvailable([
        for (final d in [5, 7, 8, 10, 11])
          _stored(SleepEntry(
              durationMinutes: 450,
              bedtimeLocal: '23:30',
              wakeTimeLocal: '07:00',
              restQuality: 4,
              day: LocalDay('2026-11-${d.toString().padLeft(2, '0')}', 0),
              provenance: _p(SleepEntry.allFields))),
      ]),
      workloadRecords: const ModalityConsentOff(),
    );

void main() {
  Future<InsightsController> pump(WidgetTester t, _Access a, {bool settle = true, bool visible = true}) async {
    t.view.physicalSize = const Size(412 * 3, 4200 * 3);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final c = InsightsController(access: a, now: () => _now);
    addTearDown(c.dispose);
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: TickerMode(enabled: visible, child: InsightsScreen(key: UniqueKey(), isTabRoot: true, controller: c)),
    ));
    if (settle) await t.pumpAndSettle();
    return c;
  }

  String rowText(WidgetTester t, String variableName) => t
      .widgetList<Text>(find.descendant(of: find.byKey(Key('insights-$variableName')), matching: find.byType(Text)))
      .map((w) => w.data)
      .join(' | ');

  testWidgets('personal baseline: window, sufficient and insufficient variables, consent-off modality', (t) async {
    await pump(t, _Access(_fixture()));
    expect(find.text('Your personal baseline'), findsOneWidget);
    expect(find.text('Last 14 days: 29 Oct to 11 Nov (development data).'), findsOneWidget);

    final mood = rowText(t, 'mood');
    expect(mood, contains('7 of 14 days observed (7 required).'));
    expect(mood, contains('Personal baseline 3 of 5'));
    expect(mood, contains('Latest entry, Wed 11 Nov: 5 of 5. Above your personal baseline.'));
    // Stress is identical on every day: baseline and latest, but no direction and no range.
    final stress = rowText(t, 'perceivedStress');
    expect(stress, contains('Personal baseline 2 of 5.'));
    expect(stress, contains('Latest entry, Wed 11 Nov: 2 of 5.'));
    expect(stress, contains('there is not enough variation to compare the latest entry with your baseline'));
    for (final word in ['Within', 'Above', 'Below', 'usual range']) {
      expect(stress, isNot(contains(word)), reason: word);
    }

    final sleep = rowText(t, 'sleepDuration');
    expect(sleep, contains('Insufficient observations: 5 of 7 required in the last 14 days. No baseline is shown yet.'));
    expect(sleep, isNot(contains('Personal baseline')));
    expect(sleep, isNot(contains('Latest entry')));

    expect(find.byKey(const Key('insights-mentalDemand')), findsNothing);
    expect(find.text('Workload is off in your data and consent preferences, so it is not analysed.'), findsOneWidget);
    expect(find.text('Review data and consent preferences'), findsOneWidget);
    expect(find.byKey(const Key('insights-footnote')), findsOneWidget);
  });

  testWidgets('saved results and the sample charts are clearly separate', (t) async {
    await pump(t, _Access(_fixture()));
    expect(find.text('Examples of future charts'), findsOneWidget);
    expect(find.text(InsightsScreen.sampleNotice), findsOneWidget);
    final personal = t.getRect(find.text('Your personal baseline'));
    final examples = t.getRect(find.text('Examples of future charts'));
    expect(personal.top, lessThan(examples.top));
    // No sample value appears in the personal section.
    expect(find.descendant(of: find.byKey(const Key('insights-mood')), matching: find.textContaining('Sample')),
        findsNothing);
  });

  testWidgets('no saved entries: every analysed variable says insufficient (0 of 7); nothing is invented',
      (t) async {
    await pump(
        t,
        _Access(const ObservationWindowLoaded(
            checkInRecords: ModalityRecordsAvailable([]),
            sleepRecords: ModalityRecordsAvailable([]),
            workloadRecords: ModalityRecordsAvailable([]))));
    for (final v in ['mood', 'motivationEnergy', 'perceivedStress', 'sleepDuration', 'restQuality', 'mentalDemand', 'effort', 'deadlines']) {
      expect(rowText(t, v), contains('Insufficient observations: 0 of 7 required'), reason: v);
    }
    expect(find.textContaining('Personal baseline '), findsNothing);
  });

  testWidgets('loading, storage unavailable and read failure states show no results', (t) async {
    final a = _Access(_fixture())..gate = Completer<void>();
    await pump(t, a, settle: false);
    await t.pump();
    expect(find.byKey(const Key('insights-loading')), findsOneWidget);
    expect(find.byKey(const Key('insights-mood')), findsNothing);
    a.gate!.complete();
    await t.pumpAndSettle();
    expect(find.byKey(const Key('insights-mood')), findsOneWidget);

    await pump(t, _Access(_fixture(), status: InsightsStorageStatus.unavailable));
    expect(find.byKey(const Key('insights-unavailable')), findsOneWidget);
    expect(find.byKey(const Key('insights-mood')), findsNothing);

    await pump(t, _Access(const ObservationWindowFailed()));
    expect(find.byKey(const Key('insights-failed')), findsOneWidget);
    expect(find.byKey(const Key('insights-mood')), findsNothing);
  });

  testWidgets('read again whenever the tab is shown; revoked consent removes the stale results', (t) async {
    final a = _Access(_fixture());
    final c = InsightsController(access: a, now: () => _now);
    addTearDown(c.dispose);
    t.view.physicalSize = const Size(412 * 3, 4200 * 3);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    Widget app(bool visible) => MaterialApp(
        theme: AppTheme.lightTheme,
        home: TickerMode(enabled: visible, child: InsightsScreen(isTabRoot: true, controller: c)));
    await t.pumpWidget(app(true));
    await t.pumpAndSettle();
    expect(a.calls, 1);
    expect(find.byKey(const Key('insights-mood')), findsOneWidget);
    // Hidden (another tab): no read. Meanwhile M1 is turned off elsewhere.
    await t.pumpWidget(app(false));
    await t.pumpAndSettle();
    expect(a.calls, 1);
    a.outcome = ObservationWindowLoaded(
        checkInRecords: const ModalityConsentOff(),
        sleepRecords: _fixture().sleepRecords,
        workloadRecords: const ModalityConsentOff());
    // Shown again: read again; the check-in results are gone.
    await t.pumpWidget(app(true));
    await t.pumpAndSettle();
    expect(a.calls, 2);
    expect(find.byKey(const Key('insights-mood')), findsNothing);
    expect(find.text('Structured check-ins are off in your data and consent preferences, so they are not analysed.'),
        findsOneWidget);
  });

  testWidgets('not connected: the sample page exactly as before, no personal section', (t) async {
    await pump(t, _Access(_fixture(), status: InsightsStorageStatus.notConnected));
    expect(find.text('Your personal baseline'), findsNothing);
    expect(find.text('Examples of future charts'), findsNothing);
    expect(find.text(InsightsScreen.sampleNotice), findsOneWidget);
    expect(find.textContaining('once saving is connected'), findsOneWidget);
  });

  testWidgets('restrained wording: no clinical, risk or prediction claims in the personal section', (t) async {
    await pump(t, _Access(_fixture()));
    // Only the personal section (above the separately labelled examples).
    final examplesTop = t.getRect(find.text('Examples of future charts')).top;
    final all = t
        .elementList(find.byType(Text))
        .where((e) => t.getRect(find.byWidget(e.widget)).top < examplesTop)
        .map((e) => (e.widget as Text).data ?? '')
        .join(' ')
        .toLowerCase();
    expect(all, contains('your personal baseline'));
    for (final bad in ['diagnos', 'depress', 'anxiety', 'clinical', 'risk', 'alert', 'stress score', 'accura', '—']) {
      expect(all, isNot(contains(bad)), reason: bad);
    }
  });
}
