// Milestone K3: CheckInController (answers, field mapping, provenance, typed
// outcomes, date changes, serialized saves) against a programmable
// CheckInAccess. Repository-backed behaviour is in check_in_persistence_test.dart.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse/core/state/check_in_controller.dart';
import 'package:mindpulse/data/local/sense_storage.dart';

import 'support/fake_check_in_access.dart';

void main() {
  // A fixed local time (not UTC): 11 November 2026, 20:15 local.
  final evening = DateTime(2026, 11, 11, 20, 15);
  final tz = evening.timeZoneOffset.inMinutes;
  const today = '2026-11-11';
  const mood = CheckInController.fieldMood;
  const motivation = CheckInController.fieldMotivation;
  const stress = CheckInController.fieldStress;

  late FakeCheckInAccess access;
  late DateTime now;

  setUp(() {
    access = FakeCheckInAccess();
    now = evening;
  });

  Future<CheckInController> started({FakeCheckInAccess? a}) async {
    final c = CheckInController(access: a ?? access, now: () => now);
    addTearDown(c.dispose);
    await c.start();
    return c;
  }

  group('Defaults and ranges', () {
    test('defaults: mood 3, motivation/energy 3, perceived stress 2 (CheckInEntry.initialValues)', () async {
      final c = await started();
      expect([c.mood, c.motivation, c.stress], [3, 3, 2]);
      expect(CheckInEntry.initialValues, {mood: 3, motivation: 3, stress: 2});
      expect(c.phase, CheckInPhase.editing);
      expect(c.changedFields, isEmpty);
    });

    test('all three answers are clamped to 1 to 5', () async {
      final c = await started();
      for (final (set, get) in [
        (c.setMood, () => c.mood),
        (c.setMotivation, () => c.motivation),
        (c.setStress, () => c.stress),
      ]) {
        set(0);
        expect(get(), 1);
        set(9);
        expect(get(), 5);
        set(4);
        expect(get(), 4);
      }
    });
  });

  group('Field mapping and provenance', () {
    test('answers map to CheckInEntry fields and the local day of the save', () async {
      final c = await started();
      c.setMood(5);
      c.setMotivation(1);
      c.setStress(4);
      expect(await c.save(), CheckInSaveResult.saved);
      final e = access.saveCalls.single;
      expect([e.moodRating, e.motivationEnergyRating, e.perceivedStressRating], [5, 1, 4]);
      expect(e.values, {mood: 5, motivation: 1, stress: 4});
      expect(e.day, LocalDay(today, tz));
      expect(e.provenance.submittedAtUtc, evening.toUtc());
      expect(e.provenance.explicitlySubmitted, isTrue);
      expect(() => e.validate(), returnsNormally);
    });

    test('an untouched check-in records every field as an untouched default', () async {
      final c = await started();
      await c.save();
      final p = access.saveCalls.single.provenance;
      expect(p.changedFields, isEmpty);
      expect(p.defaultFields, CheckInEntry.allFields);
    });

    for (final (field, change) in [
      (mood, (CheckInController c) => c.setMood(1)),
      (motivation, (CheckInController c) => c.setMotivation(5)),
      (stress, (CheckInController c) => c.setStress(3)),
    ]) {
      test('changing only $field records only $field as changed', () async {
        final c = await started();
        change(c);
        await c.save();
        final p = access.saveCalls.single.provenance;
        expect(p.changedFields, {field});
        expect(p.defaultFields, CheckInEntry.allFields.difference({field}));
      });
    }

    test('a field moved away from its default and back counts as changed', () async {
      final c = await started();
      c.setStress(5);
      c.setStress(2);
      expect(c.stress, 2);
      await c.save();
      final e = access.saveCalls.single;
      expect(e.provenance.changedFields, {stress});
      expect(() => e.validate(), returnsNormally, reason: 'a changed field may hold the default value');
    });

    test('setting an answer to its current value is not a change', () async {
      final c = await started();
      c.setMood(3);
      expect(c.changedFields, isEmpty);
    });
  });

  group("Today's existing check-in", () {
    test('loads and prefills; existing provenance is kept and new changes are added', () async {
      access.seed(today, tz, mood: 4, motivation: 3, stress: 2, changed: {mood});
      final c = await started();
      expect(access.loadCalls, [today]);
      expect(c.hasExistingEntry, isTrue);
      expect([c.mood, c.motivation, c.stress], [4, 3, 2]);
      c.setStress(1);
      expect(await c.save(), CheckInSaveResult.updated);
      final p = access.saveCalls.single.provenance;
      expect(p.changedFields, {mood, stress});
      expect(p.defaultFields, {motivation});
      expect(c.phase, CheckInPhase.updated);
    });

    test('prefilled non-default values are never recorded as untouched defaults', () async {
      access.seed(today, tz, mood: 1, motivation: 5, stress: 5, changed: CheckInEntry.allFields);
      final c = await started();
      await c.save(); // nothing adjusted now
      final p = access.saveCalls.single.provenance;
      expect(p.changedFields, CheckInEntry.allFields);
      expect(p.defaultFields, isEmpty);
    });

    test('the update keeps the id and creation time; the update time advances; one record', () async {
      final seeded = access.seed(today, tz, mood: 2, motivation: 2, stress: 3, changed: CheckInEntry.allFields);
      final c = await started();
      c.setMood(3);
      await c.save();
      final r = c.existingEntry!;
      expect(r.id, seeded.id);
      expect(r.createdAtUtc, seeded.createdAtUtc);
      expect(r.updatedAtUtc.isAfter(seeded.updatedAtUtc), isTrue);
      expect(access.records, hasLength(1));
    });

    test('a first save, then a second save: saved, then updated (same record)', () async {
      final c = await started();
      expect(await c.save(), CheckInSaveResult.saved);
      final id = c.existingEntry!.id;
      c.setMotivation(4);
      expect(c.phase, CheckInPhase.editing);
      expect(await c.save(), CheckInSaveResult.updated);
      expect(c.existingEntry!.id, id);
      expect(access.records, hasLength(1));
    });
  });

  group('Date changes', () {
    test('midnight before Finish: nothing is written; adjusted answers are kept for the new day', () async {
      access.seed(today, tz, mood: 5, motivation: 5, stress: 5, changed: CheckInEntry.allFields);
      final c = await started();
      c.setMood(2); // adjusted on the old day's form
      now = DateTime(2026, 11, 12, 0, 5);
      expect(await c.save(), CheckInSaveResult.dayChanged);
      expect(access.saveCalls, isEmpty, reason: 'nothing written without the person confirming');
      expect(c.day!.date, '2026-11-12');
      expect(c.hasExistingEntry, isFalse, reason: 'the new day has no check-in yet');
      expect(c.mood, 2, reason: 'the adjusted answer is kept');
      expect([c.motivation, c.stress], [3, 2], reason: "untouched answers do not carry yesterday's values");
      expect(c.phase, CheckInPhase.editing);
      // The person confirms with another Finish: a new record for the new day.
      expect(await c.save(), CheckInSaveResult.saved);
      final e = access.saveCalls.single;
      expect(e.day.date, '2026-11-12');
      expect(e.provenance.changedFields, {mood});
      expect(access.records.keys, containsAll([today, '2026-11-12']));
      expect(access.records[today]!.entry.moodRating, 5, reason: "the old day's check-in is untouched");
    });

    test("midnight into a day that already has a check-in: its values fill untouched answers", () async {
      // A valid stored record: mood untouched at its default, motivation changed.
      access.seed('2026-11-12', tz, mood: 3, motivation: 4, stress: 2, changed: {motivation});
      final c = await started();
      c.setStress(5);
      now = DateTime(2026, 11, 12, 0, 1);
      expect(await c.save(), CheckInSaveResult.dayChanged);
      expect(c.hasExistingEntry, isTrue);
      expect([c.mood, c.motivation, c.stress], [3, 4, 5]);
      expect(await c.save(), CheckInSaveResult.updated);
      expect(access.saveCalls.single.provenance.changedFields, {motivation, stress});
    });
  });

  group('Save-state integrity (K3 corrections)', () {
    test('answers are locked while saving; the write and the screen agree', () async {
      final c = await started();
      c.setMood(4);
      access.saveGate = Completer<void>();
      final f = c.save();
      await pumpEventQueue();
      expect(c.isSaving, isTrue);
      c.setMood(1);
      c.setMotivation(5);
      c.setStress(5);
      expect([c.mood, c.motivation, c.stress], [4, 3, 2], reason: 'changes are refused while saving');
      access.saveGate!.complete();
      expect(await f, CheckInSaveResult.saved);
      final e = access.saveCalls.single;
      expect([e.moodRating, e.motivationEnergyRating, e.perceivedStressRating], [c.mood, c.motivation, c.stress]);
      expect(c.isSaving, isFalse);
      c.setStress(5);
      expect(c.stress, 5, reason: 'unlocked after the save');
    });

    test('midnight and the new day cannot be read: dayChangedNotReloaded, no write, answers unchanged', () async {
      final c = await started();
      c.setMood(2);
      now = DateTime(2026, 11, 12, 0, 1);
      access.loadOutcome = const CheckInLoadFailed();
      expect(await c.save(), CheckInSaveResult.dayChangedNotReloaded);
      expect(access.saveCalls, isEmpty);
      expect(c.mood, 2);
      // The next Finish reads the new day and asks for review again: no write yet.
      access.loadOutcome = null;
      expect(await c.save(), CheckInSaveResult.dayChanged);
      expect(access.saveCalls, isEmpty);
      expect(c.day!.date, '2026-11-12');
      expect(await c.save(), CheckInSaveResult.saved);
      expect(access.saveCalls.single.day.date, '2026-11-12');
    });

    test('a failed read on the same day is not a date change: the next save proceeds', () async {
      access.loadOutcome = const CheckInLoadFailed();
      final c = await started();
      access.loadOutcome = null;
      expect(await c.save(), CheckInSaveResult.saved);
    });
  });

  group('Outcomes', () {
    test('consent denied (M1 off): typed state, answers kept, nothing claimed', () async {
      access.saveOutcome = const CheckInConsentDenied(ConsentDenialReason.notRecorded);
      final c = await started();
      c.setMood(5);
      expect(await c.save(), CheckInSaveResult.consentDenied);
      expect(c.phase, CheckInPhase.consentDenied);
      expect(c.mood, 5);
      expect(c.hasExistingEntry, isFalse);
    });

    test('a failed write is never success; answers stay; retry works', () async {
      access.saveOutcome = const CheckInSaveFailed();
      final c = await started();
      c.setStress(4);
      expect(await c.save(), CheckInSaveResult.failed);
      expect(c.phase, CheckInPhase.failed);
      expect(c.stress, 4);
      expect(c.hasExistingEntry, isFalse);
      access.saveOutcome = null;
      expect(await c.save(), CheckInSaveResult.saved);
    });

    test('an invalid entry is a failure, not success', () async {
      access.saveOutcome = const CheckInSaveInvalid(mood);
      final c = await started();
      expect(await c.save(), CheckInSaveResult.failed);
    });

    test('storage unavailable: typed state; save refuses without writing', () async {
      final a = FakeCheckInAccess(status: CheckInStorageStatus.unavailable);
      final c = await started(a: a);
      expect(c.phase, CheckInPhase.storageUnavailable);
      expect(await c.save(), CheckInSaveResult.storageUnavailable);
      expect(a.saveCalls, isEmpty);
    });

    test('no storage owner, or storage not connected by this build: prototype "not saved"', () async {
      final none = CheckInController(now: () => now);
      addTearDown(none.dispose);
      await none.start();
      expect(none.phase, CheckInPhase.notConnected);
      expect(none.persistenceConnected, isFalse);
      expect(await none.save(), CheckInSaveResult.notConnected);

      final off = await started(a: FakeCheckInAccess(status: CheckInStorageStatus.notConnected));
      expect(await off.save(), CheckInSaveResult.notConnected);
    });

    test('opening storage: loading, then today is read when storage opens', () async {
      final a = FakeCheckInAccess(status: CheckInStorageStatus.opening);
      final c = await started(a: a);
      expect(c.phase, CheckInPhase.loading);
      expect(c.canSave, isFalse);
      expect(await c.save(), CheckInSaveResult.notReady);
      a.seed(today, tz, mood: 4, motivation: 4, stress: 4, changed: CheckInEntry.allFields);
      a.status = CheckInStorageStatus.open;
      await pumpEventQueue();
      expect(c.phase, CheckInPhase.editing);
      expect(c.stress, 4);
    });

    test('a failed read is reported; the next save reads again first', () async {
      access.loadOutcome = const CheckInLoadFailed();
      final c = await started();
      expect(c.phase, CheckInPhase.failed);
      expect(c.dayLoaded, isFalse);
      access.loadOutcome = null;
      access.seed(today, tz, mood: 1, motivation: 3, stress: 2, changed: {mood});
      expect(await c.save(), CheckInSaveResult.updated);
      expect(access.saveCalls.single.provenance.changedFields, {mood});
    });

    test('storage closing and reopening during the read: the controller follows and reads again', () async {
      access.loadGate = Completer<void>();
      final c = CheckInController(access: access, now: () => now);
      addTearDown(c.dispose);
      final starting = c.start();
      await pumpEventQueue();
      access.status = CheckInStorageStatus.unavailable;
      access.status = CheckInStorageStatus.open;
      access.loadGate!.complete();
      await starting;
      await pumpEventQueue();
      expect(c.phase, CheckInPhase.editing);
      expect(access.loadCalls, [today, today]);
    });
  });

  group('Serialization and disposal', () {
    test('repeated Finish while a save is in progress is the same single write', () async {
      final c = await started();
      access.saveGate = Completer<void>();
      final a = c.save();
      final b = c.save();
      expect(identical(a, b), isTrue);
      expect(c.phase, CheckInPhase.saving);
      expect(c.canSave, isFalse);
      await pumpEventQueue();
      expect(access.saveCalls, hasLength(1));
      access.saveGate!.complete();
      expect(await a, CheckInSaveResult.saved);
      expect(await b, CheckInSaveResult.saved);
      expect(access.records, hasLength(1));
    });

    test('dispose stops listening; a save finishing afterwards does not notify', () async {
      final c = CheckInController(access: access, now: () => now);
      await c.start();
      expect(access.listenerCount, 1);
      access.saveGate = Completer<void>();
      final f = c.save();
      c.dispose();
      expect(access.listenerCount, 0);
      access.saveGate!.complete();
      expect(await f, CheckInSaveResult.saved);
    });
  });
}
