// Milestone E: personal baseline from SAVED records. The real storage owner
// (FakeSecureKeyPlatform, disposable plain SQLite through sqflite_common_ffi),
// the existing repositories and consent events, the read-only InsightsAccess
// and InsightsController. A small inline fake covers loading and failure.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse/core/state/insights_controller.dart';
import 'package:mindpulse/data/local/encrypted/encrypted_database.dart';
import 'package:mindpulse/data/local/local_data_store.dart';
import 'package:mindpulse/data/local/sense_storage.dart';
import 'package:mindpulse/domain/personal_insights.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fake_secure_key_platform.dart';

const _debugDev = SenseStoragePolicy(buildMode: BuildMode.debug, developmentDefine: true);
const _debugDefault = SenseStoragePolicy(buildMode: BuildMode.debug, developmentDefine: false);

/// Today (local): Wednesday 11 November 2026, evening. Window: 29 Oct to 11 Nov.
final _now = DateTime(2026, 11, 11, 21);

class _ScriptedAccess implements InsightsAccess {
  InsightsStorageStatus _status = InsightsStorageStatus.open;
  ObservationWindowOutcome outcome = const ObservationWindowFailed();
  Completer<void>? gate;
  final calls = <(String, String)>[];
  final _listeners = <void Function()>[];

  @override
  InsightsStorageStatus get status => _status;
  set status(InsightsStorageStatus s) {
    _status = s;
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  @override
  bool get isDevelopment => true;

  @override
  Future<ObservationWindowOutcome> loadWindow({required String fromDate, required String toDate}) async {
    calls.add((fromDate, toDate));
    if (gate != null) await gate!.future;
    return outcome;
  }

  @override
  void addListener(void Function() l) => _listeners.add(l);
  @override
  void removeListener(void Function() l) => _listeners.remove(l);
}

void main() {
  late Directory dir;
  final owners = <SenseStorage>[];

  setUpAll(sqfliteFfiInit);
  setUp(() => dir = Directory.systemTemp.createTempSync('sense_insights_'));
  tearDown(() async {
    for (final s in owners) {
      await s.close();
    }
    owners.clear();
    dir.deleteSync(recursive: true);
  });

  Future<(SenseStorage, StorageReady)> openDev() async {
    final s = SenseStorage(policy: _debugDev, platform: FakeSecureKeyPlatform(dir));
    owners.add(s);
    final r = await s.start() as StorageReady;
    return (s, r);
  }

  Future<void> consent(StorageReady r, String m, bool on) => r.store.consent.recordChange(r.profile.localPersonId, m, on);

  LocalDay day(String d) => LocalDay(d, 0);
  Provenance prov(Set<String> all, Set<String> changed) =>
      Provenance.fromChanged(allFields: all, changed: changed, submittedAtUtc: DateTime.utc(2026, 11, 11));

  Future<void> checkIn(StorageReady r, String d, int mood, int energy, int stress) => r.store.checkIns.upsert(
      r.profile.localPersonId,
      CheckInEntry(
          moodRating: mood,
          motivationEnergyRating: energy,
          perceivedStressRating: stress,
          day: day(d),
          provenance: prov(CheckInEntry.allFields, CheckInEntry.allFields)));

  Future<void> sleep(StorageReady r, String wakeDate, int minutes, int quality) => r.store.sleep.upsert(
      r.profile.localPersonId,
      SleepEntry(
          durationMinutes: minutes,
          bedtimeLocal: '23:30',
          wakeTimeLocal: '07:00',
          restQuality: quality,
          day: day(wakeDate),
          provenance: prov(SleepEntry.allFields, {'duration_minutes', 'rest_quality'})));

  Future<void> workload(StorageReady r, String d, int demand, int effort, int deadlines) => r.store.workload.upsert(
      r.profile.localPersonId,
      WorkloadEntry(
          mentalDemand: demand,
          effort: effort,
          deadlines48h: deadlines,
          day: day(d),
          provenance: prov(WorkloadEntry.allFields, WorkloadEntry.allFields)));

  /// 'YYYY-MM-DD' for November 2026 day [n] (or October when n <= 0).
  String nov(int n) => n > 0 ? '2026-11-${n.toString().padLeft(2, '0')}' : '2026-10-${(31 + n).toString().padLeft(2, '0')}';

  Future<InsightsController> started(SenseStorage s) async {
    final c = InsightsController(access: s.insights, now: () => _now);
    addTearDown(c.dispose);
    await c.start();
    return c;
  }

  VariableBaseline result(InsightsController c, InsightVariable v) =>
      (c.modalities!.firstWhere((m) => m.modality == v.modality) as ModalityAnalysed)
          .variables
          .firstWhere((x) => x.variable == v);

  group('Mapping saved records to the engine', () {
    test('check-ins: mood, motivation/energy and stress by local date; 7 entries give a baseline', () async {
      final (s, r) = await openDev();
      await consent(r, 'M1', true);
      for (final (d, m, e, st) in [(1, 2, 3, 2), (3, 4, 3, 2), (4, 3, 2, 3), (6, 1, 3, 2), (8, 3, 2, 4), (9, 4, 4, 2), (11, 5, 3, 1)]) {
        await checkIn(r, nov(d), m, e, st);
      }
      final c = await started(s);
      expect(c.phase, InsightsPhase.available);
      expect(c.windowDates!.first, '2026-10-29');
      final mood = result(c, InsightVariable.mood);
      expect(mood.observations, 7);
      expect(mood.baseline, 3.0);
      expect([mood.latestValue, mood.latestDate], [5.0, '2026-11-11']);
      expect(mood.state, BaselineState.usable, reason: 'mood varies: a robust spread');
      expect(mood.position, BaselinePosition.above);
      expect(result(c, InsightVariable.motivationEnergy).baseline, 3.0);
      // Stress is mostly 2 (MAD zero): baseline shown, no direction.
      final stress = result(c, InsightVariable.perceivedStress);
      expect(stress.latestValue, 1.0);
      expect(stress.state, BaselineState.degenerateDispersion);
      expect(stress.position, isNull);
    });

    test('sleep: counted on the stored WAKE-UP date; duration analysed in hours', () async {
      final (s, r) = await openDev();
      await consent(r, 'M3', true);
      // Bedtime on 10 Nov, woke on 11 Nov: the 11 Nov record.
      await sleep(r, nov(11), 420, 4);
      final c = await started(s);
      final dur = result(c, InsightVariable.sleepDuration);
      expect([dur.latestDate, dur.latestValue], ['2026-11-11', 7.0]);
      expect(dur.observations, 1);
      expect(dur.sufficient, isFalse);
      expect(result(c, InsightVariable.restQuality).latestValue, 4.0);
    });

    test('workload: demand, effort and deadlines (0 is a value); 6 entries are insufficient', () async {
      final (s, r) = await openDev();
      await consent(r, 'M4', true);
      for (final d in [2, 4, 6, 8, 10, 11]) {
        await workload(r, nov(d), 3, 2, 0);
      }
      final c = await started(s);
      final dl = result(c, InsightVariable.deadlines);
      expect(dl.observations, 6);
      expect(dl.sufficient, isFalse);
      expect(dl.latestValue, 0.0);
      expect(result(c, InsightVariable.mentalDemand).required, 7);
    });

    test('different counts per variable across modalities; entries outside the 14 days are ignored', () async {
      final (s, r) = await openDev();
      for (final m in ['M1', 'M3', 'M4']) {
        await consent(r, m, true);
      }
      for (var d = 1; d <= 9; d++) {
        await checkIn(r, nov(d), 3, 3, 2);
      }
      await checkIn(r, nov(-3), 1, 1, 5); // 28 Oct: outside the window
      await checkIn(r, '2026-11-12', 1, 1, 5); // tomorrow: outside
      for (final d in [5, 7, 9]) {
        await sleep(r, nov(d), 450, 3);
      }
      final c = await started(s);
      expect(result(c, InsightVariable.mood).observations, 9);
      expect(result(c, InsightVariable.mood).baseline, 3.0, reason: 'the outside 1s are not counted');
      expect(result(c, InsightVariable.sleepDuration).observations, 3);
      expect(result(c, InsightVariable.mentalDemand).observations, 0, reason: 'no workload saved: nothing invented');
      expect(result(c, InsightVariable.mentalDemand).sufficient, isFalse);
    });
  });

  group('Consent boundaries', () {
    test('each modality is analysed only when its persisted consent is on', () async {
      final (s, r) = await openDev();
      await consent(r, 'M1', true);
      await consent(r, 'M3', true);
      await consent(r, 'M4', true);
      await checkIn(r, nov(11), 3, 3, 2);
      await sleep(r, nov(11), 450, 4);
      await workload(r, nov(11), 3, 3, 1);
      for (final off in ['M1', 'M3', 'M4']) {
        await consent(r, off, false);
        final c = await started(s);
        final states = {for (final m in c.modalities!) m.modality: m is ModalityAnalysed};
        expect(states[off], isFalse, reason: '$off off');
        expect(states.values.where((v) => v), hasLength(2));
        await consent(r, off, true);
      }
    });

    test('revoking consent removes the modality on the next read; the records themselves remain', () async {
      final (s, r) = await openDev();
      await consent(r, 'M1', true);
      for (var d = 1; d <= 7; d++) {
        await checkIn(r, nov(d), 3, 3, 2);
      }
      final c = await started(s);
      expect(result(c, InsightVariable.mood).sufficient, isTrue);
      await consent(r, 'M1', false);
      await c.refresh();
      expect(c.modalities!.firstWhere((m) => m.modality == 'M1'), isA<ModalityNotAnalysed>());
      expect((await r.store.checkIns.range(r.profile.localPersonId, fromDate: nov(1), toDate: nov(7))), hasLength(7),
          reason: 'revocation hides insights; it does not delete records');
    });

    test('never turned on: not analysed (default off)', () async {
      final (s, r) = await openDev();
      await expectLater(checkIn(r, nov(11), 3, 3, 2), throwsA(isA<ConsentDeniedException>()),
          reason: 'M1 never on: the write itself is refused');
      final c = await started(s);
      expect(c.modalities!.every((m) => m is ModalityNotAnalysed), isTrue);
    });
  });

  group('Availability and staleness', () {
    test('storage not connected (default debug build): no personal results, nothing opened', () async {
      final platform = FakeSecureKeyPlatform(dir);
      final s = SenseStorage(policy: _debugDefault, platform: platform);
      owners.add(s);
      await s.start();
      final c = await started(s);
      expect(c.phase, InsightsPhase.notConnected);
      expect(c.modalities, isNull);
      expect(platform.calls, isNot(contains('openKey')));
    });

    test('storage closing clears the results at once', () async {
      final (s, r) = await openDev();
      await consent(r, 'M1', true);
      await checkIn(r, nov(11), 3, 3, 2);
      final c = await started(s);
      expect(c.modalities, isNotNull);
      await s.close();
      await pumpEventQueue();
      expect(c.phase, InsightsPhase.storageUnavailable);
      expect(c.modalities, isNull);
      expect(c.windowDates, isNull);
    });

    test('a failed read shows nothing; loading hides previous results until the new read completes', () async {
      final a = _ScriptedAccess();
      final c = InsightsController(access: a, now: () => _now);
      addTearDown(c.dispose);
      await c.start();
      expect(c.phase, InsightsPhase.failed);
      expect(c.modalities, isNull);
      expect(a.calls.single, ('2026-10-29', '2026-11-11'));

      a.outcome = const ObservationWindowLoaded(
          checkInRecords: ModalityRecordsAvailable([]),
          sleepRecords: ModalityConsentOff(),
          workloadRecords: ModalityConsentOff());
      await c.refresh();
      expect(c.phase, InsightsPhase.available);
      a.gate = Completer<void>();
      final pending = c.refresh();
      await pumpEventQueue();
      expect(c.phase, InsightsPhase.loading);
      expect(c.modalities, isNull, reason: 'no stale results while reading again');
      a.outcome = const ObservationWindowFailed();
      a.gate!.complete();
      await pending;
      expect(c.phase, InsightsPhase.failed);
      expect(c.modalities, isNull);
    });

    test('opening storage: loading, then read when it opens', () async {
      final a = _ScriptedAccess().._status = InsightsStorageStatus.opening;
      final c = InsightsController(access: a, now: () => _now);
      addTearDown(c.dispose);
      await c.start();
      expect(c.phase, InsightsPhase.loading);
      expect(a.calls, isEmpty);
      a.outcome = const ObservationWindowLoaded(
          checkInRecords: ModalityConsentOff(), sleepRecords: ModalityConsentOff(), workloadRecords: ModalityConsentOff());
      a.status = InsightsStorageStatus.open;
      await pumpEventQueue();
      expect(c.phase, InsightsPhase.available);
    });
  });

  test('reading insights writes nothing (the record and consent tables are unchanged)', () async {
    final (s, r) = await openDev();
    await consent(r, 'M1', true);
    await checkIn(r, nov(11), 3, 3, 2);
    Future<List<int>> counts() async => [
          for (final t in ['check_ins', 'sleep_records', 'workload_records', 'consent_events'])
            (await r.database.rawQuery('SELECT COUNT(*) AS n FROM $t')).first['n'] as int,
        ];
    final before = await counts();
    final c = await started(s);
    await c.refresh();
    expect(await counts(), before);
  });
}
