// Milestone K2: WorkloadController (form state, field mapping, provenance,
// typed outcomes, serialized saves) against a programmable WorkloadAccess.
// Repository-backed behaviour is in workload_persistence_test.dart.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse/core/state/workload_controller.dart';
import 'package:mindpulse/data/local/sense_storage.dart';

import 'support/fake_workload_access.dart';

void main() {
  // A fixed local time (not UTC): 11 November 2026, 09:30 local.
  final morning = DateTime(2026, 11, 11, 9, 30);
  final tz = morning.timeZoneOffset.inMinutes;
  const today = '2026-11-11';

  late FakeWorkloadAccess access;
  late DateTime now;
  WorkloadController make({FakeWorkloadAccess? a}) => WorkloadController(access: a ?? access, now: () => now);

  setUp(() {
    access = FakeWorkloadAccess();
    now = morning;
  });

  Future<WorkloadController> started({FakeWorkloadAccess? a}) async {
    final c = make(a: a);
    addTearDown(c.dispose);
    await c.start();
    return c;
  }

  group('Defaults and ranges', () {
    test('defaults: mental demand 3, effort 3, deadlines 1 (WorkloadEntry.initialValues)', () async {
      final c = await started();
      expect([c.mentalDemand, c.effort, c.deadlines], [3, 3, 1]);
      expect(WorkloadEntry.initialValues, {'mental_demand': 3, 'effort': 3, 'deadlines_48h': 1});
      expect(c.phase, WorkloadPhase.editing);
      expect(c.hasExistingEntry, isFalse);
      expect(c.changedFields, isEmpty);
    });

    test('mental demand and effort are clamped to 1 to 5', () async {
      final c = await started();
      c.setMentalDemand(0);
      expect(c.mentalDemand, 1);
      c.setMentalDemand(9);
      expect(c.mentalDemand, 5);
      c.setEffort(-3);
      expect(c.effort, 1);
      c.setEffort(6);
      expect(c.effort, 5);
    });

    test('deadlines: decrement stops at 0, increment stops at 20', () async {
      final c = await started();
      c.decrementDeadlines();
      expect(c.deadlines, 0);
      expect(c.canDecrementDeadlines, isFalse);
      c.decrementDeadlines();
      expect(c.deadlines, 0, reason: 'decrement at 0 is ignored');
      for (var i = 0; i < 25; i++) {
        c.incrementDeadlines();
      }
      expect(c.deadlines, 20);
      expect(c.canIncrementDeadlines, isFalse);
      c.incrementDeadlines();
      expect(c.deadlines, 20, reason: 'increment at 20 is ignored');
      expect([WorkloadController.minDeadlines, WorkloadController.maxDeadlines], [0, 20]);
    });
  });

  group('Field mapping and provenance', () {
    test('form values map to WorkloadEntry fields and the local day of the save', () async {
      final c = await started();
      c.setMentalDemand(4);
      c.setEffort(2);
      c.decrementDeadlines();
      expect(await c.save(), WorkloadSaveResult.saved);
      final e = access.saveCalls.single;
      expect(e.values, {'mental_demand': 4, 'effort': 2, 'deadlines_48h': 0});
      expect(e.day, LocalDay(today, tz));
      expect(e.provenance.submittedAtUtc, morning.toUtc());
      expect(e.provenance.explicitlySubmitted, isTrue);
      expect(() => e.validate(), returnsNormally);
    });

    test('an untouched form records every field as an untouched default', () async {
      final c = await started();
      await c.save();
      final p = access.saveCalls.single.provenance;
      expect(p.changedFields, isEmpty);
      expect(p.defaultFields, WorkloadEntry.allFields);
    });

    test('only adjusted fields are recorded as changed', () async {
      final c = await started();
      c.setMentalDemand(5);
      await c.save();
      final p = access.saveCalls.single.provenance;
      expect(p.changedFields, {'mental_demand'});
      expect(p.defaultFields, {'effort', 'deadlines_48h'});
    });

    test('a field moved away from its default and back counts as changed (an explicit choice)', () async {
      final c = await started();
      c.setEffort(4);
      c.setEffort(3);
      c.incrementDeadlines();
      c.decrementDeadlines();
      expect([c.effort, c.deadlines], [3, 1]);
      await c.save();
      final e = access.saveCalls.single;
      expect(e.provenance.changedFields, {'effort', 'deadlines_48h'});
      expect(e.provenance.defaultFields, {'mental_demand'});
      expect(() => e.validate(), returnsNormally, reason: 'changed fields may hold the default value');
    });

    test('setting a field to its current value is not a change', () async {
      final c = await started();
      c.setMentalDemand(3);
      expect(c.changedFields, isEmpty);
    });

    test('zero deadlines is a real, changed observation (not missing)', () async {
      final c = await started();
      c.decrementDeadlines();
      await c.save();
      final e = access.saveCalls.single;
      expect(e.deadlines48h, 0);
      expect(e.provenance.changedFields, contains('deadlines_48h'));
    });
  });

  group("Today's existing entry", () {
    test('loads and prefills the stored values; existing provenance is kept when editing', () async {
      access.seed(today, tz, demand: 2, effort: 5, deadlines: 0, changed: {'mental_demand', 'effort', 'deadlines_48h'});
      final c = await started();
      expect(access.loadCalls, [today]);
      expect(c.hasExistingEntry, isTrue);
      expect([c.mentalDemand, c.effort, c.deadlines], [2, 5, 0]);
      c.incrementDeadlines();
      expect(await c.save(), WorkloadSaveResult.updated);
      final p = access.saveCalls.single.provenance;
      expect(p.changedFields, {'mental_demand', 'effort', 'deadlines_48h'});
      expect(c.phase, WorkloadPhase.updated);
    });

    test('untouched defaults stay defaults; a newly adjusted field is added', () async {
      access.seed(today, tz, demand: 4, effort: 3, deadlines: 1, changed: {'mental_demand'});
      final c = await started();
      c.setEffort(1);
      await c.save();
      final p = access.saveCalls.single.provenance;
      expect(p.changedFields, {'mental_demand', 'effort'});
      expect(p.defaultFields, {'deadlines_48h'});
    });

    test('prefilled non-default values are never recorded as untouched defaults', () async {
      access.seed(today, tz, demand: 5, effort: 1, deadlines: 7, changed: {'mental_demand', 'effort', 'deadlines_48h'});
      final c = await started();
      await c.save(); // nothing touched in this session
      final p = access.saveCalls.single.provenance;
      expect(p.changedFields, {'mental_demand', 'effort', 'deadlines_48h'});
      expect(p.defaultFields, isEmpty);
    });

    test('the update keeps the id and creation time; updated time advances', () async {
      final seeded = access.seed(today, tz, demand: 2, effort: 2, deadlines: 2, changed: WorkloadEntry.allFields);
      final c = await started();
      c.setMentalDemand(3);
      await c.save();
      final r = c.existingEntry!;
      expect(r.id, seeded.id);
      expect(r.createdAtUtc, seeded.createdAtUtc);
      expect(r.updatedAtUtc.isAfter(seeded.updatedAtUtc), isTrue);
      expect(access.records, hasLength(1));
    });

    test('a first save then a second save: saved, then updated (same record)', () async {
      final c = await started();
      expect(await c.save(), WorkloadSaveResult.saved);
      final id = c.existingEntry!.id;
      c.setEffort(5);
      expect(c.phase, WorkloadPhase.editing, reason: 'a change clears the finished result');
      expect(await c.save(), WorkloadSaveResult.updated);
      expect(c.existingEntry!.id, id);
      expect(access.records, hasLength(1));
    });
  });

  group('Outcomes', () {
    test('consent denied (M4 off): typed state, values kept, nothing claimed', () async {
      access.saveOutcome = const WorkloadConsentDenied(ConsentDenialReason.disabled);
      final c = await started();
      c.setMentalDemand(5);
      expect(await c.save(), WorkloadSaveResult.consentDenied);
      expect(c.phase, WorkloadPhase.consentDenied);
      expect(c.mentalDemand, 5);
      expect(c.hasExistingEntry, isFalse);
    });

    test('a failed write is never success; values stay; retry works', () async {
      access.saveOutcome = const WorkloadSaveFailed();
      final c = await started();
      c.setEffort(4);
      c.incrementDeadlines();
      expect(await c.save(), WorkloadSaveResult.failed);
      expect(c.phase, WorkloadPhase.failed);
      expect([c.effort, c.deadlines], [4, 2]);
      expect(c.hasExistingEntry, isFalse);
      access.saveOutcome = null;
      expect(await c.save(), WorkloadSaveResult.saved);
      expect(c.phase, WorkloadPhase.saved);
    });

    test('an invalid entry is a failure, not success', () async {
      access.saveOutcome = const WorkloadSaveInvalid('deadlines_48h');
      final c = await started();
      expect(await c.save(), WorkloadSaveResult.failed);
      expect(c.phase, WorkloadPhase.failed);
    });

    test('storage unavailable: typed state, save refuses without writing', () async {
      final c = await started(a: FakeWorkloadAccess(status: WorkloadStorageStatus.unavailable));
      expect(c.phase, WorkloadPhase.storageUnavailable);
      expect(await c.save(), WorkloadSaveResult.storageUnavailable);
    });

    test('storage closing after load: the save reports unavailable', () async {
      final c = await started();
      access.status = WorkloadStorageStatus.unavailable;
      expect(c.phase, WorkloadPhase.storageUnavailable);
      expect(await c.save(), WorkloadSaveResult.storageUnavailable);
      expect(access.saveCalls, isEmpty);
    });

    test('no storage owner, or storage not connected by this build: prototype "not saved"', () async {
      final none = WorkloadController(now: () => now);
      addTearDown(none.dispose);
      await none.start();
      expect(none.phase, WorkloadPhase.notConnected);
      expect(none.persistenceConnected, isFalse);
      expect(await none.save(), WorkloadSaveResult.notConnected);

      final off = await started(a: FakeWorkloadAccess(status: WorkloadStorageStatus.notConnected));
      expect(off.phase, WorkloadPhase.notConnected);
      expect(await off.save(), WorkloadSaveResult.notConnected);
    });

    test('opening storage: loading, then today is read when storage opens', () async {
      final a = FakeWorkloadAccess(status: WorkloadStorageStatus.opening);
      final c = await started(a: a);
      expect(c.phase, WorkloadPhase.loading);
      expect(c.canSave, isFalse);
      expect(await c.save(), WorkloadSaveResult.notReady);
      a.seed(today, tz, demand: 4, effort: 4, deadlines: 4, changed: WorkloadEntry.allFields);
      a.status = WorkloadStorageStatus.open;
      await pumpEventQueue();
      expect(c.phase, WorkloadPhase.editing);
      expect(c.deadlines, 4);
    });

    test('storage closing and reopening during the read: the controller follows and reads again', () async {
      access.loadGate = Completer<void>();
      final c = make();
      addTearDown(c.dispose);
      final starting = c.start();
      await pumpEventQueue();
      access.status = WorkloadStorageStatus.unavailable;
      access.status = WorkloadStorageStatus.open; // in-flight read is still pending
      access.loadGate!.complete();
      await starting;
      await pumpEventQueue();
      expect(c.phase, WorkloadPhase.editing);
      expect(c.todayLoaded, isTrue);
      expect(access.loadCalls, [today, today]);
    });

    test('a failed read is reported; the next save reads again first (provenance is never lost)', () async {
      access.loadOutcome = const WorkloadLoadFailed();
      final c = await started();
      expect(c.phase, WorkloadPhase.failed);
      expect(c.todayLoaded, isFalse);
      access.loadOutcome = null;
      access.seed(today, tz, demand: 1, effort: 3, deadlines: 1, changed: {'mental_demand'});
      expect(await c.save(), WorkloadSaveResult.updated);
      expect(access.loadCalls, [today, today]);
      expect(access.saveCalls.single.provenance.changedFields, {'mental_demand'});
    });

    test('the date changing after load: nothing is written; the form shows the new day', () async {
      access.seed(today, tz, demand: 5, effort: 5, deadlines: 5, changed: WorkloadEntry.allFields);
      final c = await started();
      now = DateTime(2026, 11, 12, 0, 5);
      expect(await c.save(), WorkloadSaveResult.dayChanged);
      expect(access.saveCalls, isEmpty);
      expect(c.hasExistingEntry, isFalse);
      expect([c.mentalDemand, c.effort, c.deadlines], [3, 3, 1]);
      expect(access.loadCalls.last, '2026-11-12');
    });
  });

  group('Serialization and disposal', () {
    test('repeated Save while a save is in progress is the same single write', () async {
      final c = await started();
      access.saveGate = Completer<void>();
      final a = c.save();
      final b = c.save();
      expect(identical(a, b), isTrue);
      expect(c.phase, WorkloadPhase.saving);
      expect(c.canSave, isFalse);
      await pumpEventQueue();
      expect(access.saveCalls, hasLength(1));
      access.saveGate!.complete();
      expect(await a, WorkloadSaveResult.saved);
      expect(await b, WorkloadSaveResult.saved);
      expect(access.saveCalls, hasLength(1));
      expect(access.records, hasLength(1));
    });

    test('nothing is shown as saved before the write completes', () async {
      final c = await started();
      access.saveGate = Completer<void>();
      final f = c.save();
      await pumpEventQueue();
      expect(c.phase, WorkloadPhase.saving);
      expect(c.hasExistingEntry, isFalse);
      access.saveGate!.complete();
      await f;
      expect(c.phase, WorkloadPhase.saved);
    });

    test('dispose stops listening; a save finishing afterwards does not notify', () async {
      final c = make();
      await c.start();
      expect(access.listenerCount, 1);
      access.saveGate = Completer<void>();
      final f = c.save();
      c.dispose();
      expect(access.listenerCount, 0);
      access.saveGate!.complete();
      expect(await f, WorkloadSaveResult.saved);
    });
  });
}
