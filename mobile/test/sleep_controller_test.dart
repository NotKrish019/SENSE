// Milestone K4: SleepController (conversions, field mapping, wake-up date,
// provenance, typed outcomes, save lock, midnight, history) against a
// programmable SleepAccess. Repository-backed behaviour is in
// sleep_persistence_test.dart.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse/core/state/sleep_controller.dart';
import 'package:mindpulse/data/local/sense_storage.dart';

import 'support/fake_sleep_access.dart';

void main() {
  // Wednesday 11 November 2026, 07:20 local: just woke up.
  final morning = DateTime(2026, 11, 11, 7, 20);
  final tz = morning.timeZoneOffset.inMinutes;
  const today = '2026-11-11';
  const duration = SleepController.fieldDuration;
  const bed = SleepController.fieldBedtime;
  const wake = SleepController.fieldWakeTime;
  const quality = SleepController.fieldQuality;

  late FakeSleepAccess access;
  late DateTime now;
  setUp(() {
    access = FakeSleepAccess();
    now = morning;
  });

  Future<SleepController> started({FakeSleepAccess? a}) async {
    final c = SleepController(access: a ?? access, now: () => now);
    addTearDown(c.dispose);
    await c.start();
    await pumpEventQueue(); // the history read follows the day read
    return c;
  }

  group('Conversions', () {
    test('HH:MM is zero-padded 24-hour and parses back exactly', () {
      expect(SleepController.hhmm(0, 5), '00:05');
      expect(SleepController.hhmm(9, 7), '09:07');
      expect(SleepController.hhmm(23, 59), '23:59');
      expect(SleepController.hhmm(0, 0), '00:00');
      for (final t in ['00:05', '09:07', '23:59', '12:00', '00:00']) {
        final (h, m) = SleepController.parseHhmm(t);
        expect(SleepController.hhmm(h, m), t);
      }
      expect(SleepController.parseHhmm('23:30'), (23, 30));
      expect(() => SleepController.hhmm(24, 0), throwsArgumentError);
      expect(() => SleepController.hhmm(7, 60), throwsArgumentError);
      for (final bad in ['7:00', '24:00', '07:60', '11:30 PM', '0700', '']) {
        expect(() => SleepController.parseHhmm(bad), throwsFormatException, reason: bad);
      }
    });

    test('hours to minutes: 4.0 is 240, 7.5 is 450, 12.0 is 720; the 30-minute grid and range hold', () {
      expect(SleepController.minutesFromHours(4.0), 240);
      expect(SleepController.minutesFromHours(7.5), 450);
      expect(SleepController.minutesFromHours(12.0), 720);
      expect(SleepController.minutesFromHours(8.0), 480);
      expect(SleepController.minutesFromHours(7.49), 450, reason: 'slider rounding snaps to the grid');
      expect(SleepController.minutesFromHours(3.0), 240, reason: 'below range clamps to 240');
      expect(SleepController.minutesFromHours(13.0), 720, reason: 'above range clamps to 720');
      for (var h = 4.0; h <= 12.0; h += 0.5) {
        expect(SleepController.minutesFromHours(h) % 30, 0, reason: '$h');
      }
      expect(SleepController.hoursFromMinutes(450), 7.5);
    });
  });

  group('Defaults and mapping', () {
    test('defaults: 450 minutes (7.5 h), 23:30, 07:00, quality 4 (SleepEntry.initialValues)', () async {
      final c = await started();
      expect([c.durationMinutes, c.bedtime, c.wakeTime, c.quality], [450, '23:30', '07:00', 4]);
      expect(c.durationHours, 7.5);
      expect(SleepEntry.initialValues, {duration: 450, bed: '23:30', wake: '07:00', quality: 4});
      expect(c.phase, SleepPhase.editing);
      expect(c.changedFields, isEmpty);
    });

    test('quality is clamped to 1 to 5; duration to 240 to 720', () async {
      final c = await started();
      c.setQuality(0);
      expect(c.quality, 1);
      c.setQuality(9);
      expect(c.quality, 5);
      c.setDurationHours(2);
      expect(c.durationMinutes, 240);
      c.setDurationHours(20);
      expect(c.durationMinutes, 720);
    });

    test('answers map to SleepEntry fields; the wake-up date is today (bedtime was yesterday)', () async {
      final c = await started();
      c.setDurationHours(6.5);
      c.setBedtime(0, 5);
      c.setWakeTime(6, 35);
      c.setQuality(2);
      expect(await c.save(), SleepSaveResult.saved);
      final e = access.saveCalls.single;
      expect([e.durationMinutes, e.bedtimeLocal, e.wakeTimeLocal, e.restQuality], [390, '00:05', '06:35', 2]);
      expect(e.values, {duration: 390, bed: '00:05', wake: '06:35', quality: 2});
      expect(e.day, LocalDay(today, tz), reason: 'the record belongs to the date of wake-up');
      expect(e.provenance.submittedAtUtc, morning.toUtc());
      expect(() => e.validate(), returnsNormally);
    });

    test('a night crossing midnight (23:30 to 07:00) is stored under the wake-up date', () async {
      final c = await started();
      await c.save();
      final e = access.saveCalls.single;
      expect([e.bedtimeLocal, e.wakeTimeLocal], ['23:30', '07:00']);
      expect(e.day.date, today);
      expect(e.durationMinutes, 450, reason: 'duration is its own answer, never derived from the times');
    });

    test('duration is never derived from the times', () async {
      final c = await started();
      c.setBedtime(22, 0);
      c.setWakeTime(8, 0); // 10 hours apart
      expect(c.durationMinutes, 450);
      c.setDurationHours(4);
      expect([c.bedtime, c.wakeTime], ['22:00', '08:00']);
    });
  });

  group('Provenance', () {
    test('an untouched entry records every field as an untouched default', () async {
      final c = await started();
      await c.save();
      final p = access.saveCalls.single.provenance;
      expect(p.changedFields, isEmpty);
      expect(p.defaultFields, SleepEntry.allFields);
    });

    for (final (field, change) in [
      (duration, (SleepController c) => c.setDurationHours(8)),
      (bed, (SleepController c) => c.setBedtime(22, 45)),
      (wake, (SleepController c) => c.setWakeTime(6, 15)),
      (quality, (SleepController c) => c.setQuality(5)),
    ]) {
      test('changing only $field records only $field as changed', () async {
        final c = await started();
        change(c);
        await c.save();
        final p = access.saveCalls.single.provenance;
        expect(p.changedFields, {field});
        expect(p.defaultFields, SleepEntry.allFields.difference({field}));
      });
    }

    test('fields moved away from their defaults and back count as changed', () async {
      final c = await started();
      c.setDurationHours(9);
      c.setDurationHours(7.5);
      c.setBedtime(1, 0);
      c.setBedtime(23, 30);
      expect([c.durationMinutes, c.bedtime], [450, '23:30']);
      await c.save();
      final e = access.saveCalls.single;
      expect(e.provenance.changedFields, {duration, bed});
      expect(() => e.validate(), returnsNormally);
    });
  });

  group("Today's existing entry", () {
    test('loads and prefills; existing provenance kept; new changes added; update keeps id and created_at',
        () async {
      final seeded = access.seed(today, tz, minutes: 360, bedtime: '01:15', wake: '07:15', quality: 4,
          changed: {duration, bed, wake});
      final c = await started();
      expect(access.loadCalls, [today]);
      expect([c.durationMinutes, c.bedtime, c.wakeTime, c.quality], [360, '01:15', '07:15', 4]);
      c.setQuality(2);
      expect(await c.save(), SleepSaveResult.updated);
      final p = access.saveCalls.single.provenance;
      expect(p.changedFields, {duration, bed, wake, quality});
      final r = c.existingEntry!;
      expect(r.id, seeded.id);
      expect(r.createdAtUtc, seeded.createdAtUtc);
      expect(r.updatedAtUtc.isAfter(seeded.updatedAtUtc), isTrue);
      expect(access.records, hasLength(1));
      expect(c.phase, SleepPhase.updated);
    });

    test('prefilled non-default values are never recorded as untouched defaults', () async {
      access.seed(today, tz, minutes: 600, bedtime: '21:00', wake: '07:00', quality: 1, changed: {duration, bed, quality});
      final c = await started();
      await c.save();
      expect(access.saveCalls.single.provenance.defaultFields, {wake});
    });

    test('a first save then a second save: saved, then updated (same record)', () async {
      final c = await started();
      expect(await c.save(), SleepSaveResult.saved);
      final id = c.existingEntry!.id;
      c.setQuality(5);
      expect(await c.save(), SleepSaveResult.updated);
      expect(c.existingEntry!.id, id);
      expect(access.records, hasLength(1));
    });
  });

  group('Outcomes', () {
    test('consent denied (M3 off): typed state, values kept', () async {
      access.saveOutcome = const SleepConsentDenied(ConsentDenialReason.notRecorded);
      final c = await started();
      c.setDurationHours(5);
      expect(await c.save(), SleepSaveResult.consentDenied);
      expect(c.phase, SleepPhase.consentDenied);
      expect(c.durationMinutes, 300);
      expect(c.hasExistingEntry, isFalse);
    });

    test('a failed write is never success; values stay; retry works', () async {
      access.saveOutcome = const SleepSaveFailed();
      final c = await started();
      c.setWakeTime(9, 0);
      expect(await c.save(), SleepSaveResult.failed);
      expect(c.phase, SleepPhase.failed);
      expect(c.wakeTime, '09:00');
      access.saveOutcome = null;
      expect(await c.save(), SleepSaveResult.saved);
    });

    test('storage unavailable and not connected', () async {
      final u = await started(a: FakeSleepAccess(status: SleepStorageStatus.unavailable));
      expect(u.phase, SleepPhase.storageUnavailable);
      expect(await u.save(), SleepSaveResult.storageUnavailable);
      final none = SleepController(now: () => now);
      addTearDown(none.dispose);
      await none.start();
      expect(none.phase, SleepPhase.notConnected);
      expect(await none.save(), SleepSaveResult.notConnected);
    });

    test('opening storage: loading, then today is read when storage opens', () async {
      final a = FakeSleepAccess(status: SleepStorageStatus.opening);
      final c = await started(a: a);
      expect(c.phase, SleepPhase.loading);
      expect(await c.save(), SleepSaveResult.notReady);
      a.status = SleepStorageStatus.open;
      await pumpEventQueue();
      expect(c.phase, SleepPhase.editing);
    });
  });

  group('Save lock and serialization', () {
    test('values are locked while saving; the write equals what was shown', () async {
      final c = await started();
      c.setDurationHours(8.5);
      access.saveGate = Completer<void>();
      final f = c.save();
      await pumpEventQueue();
      expect(c.isSaving, isTrue);
      c.setDurationHours(4);
      c.setBedtime(1, 1);
      c.setWakeTime(2, 2);
      c.setQuality(1);
      expect([c.durationMinutes, c.bedtime, c.wakeTime, c.quality], [510, '23:30', '07:00', 4]);
      access.saveGate!.complete();
      expect(await f, SleepSaveResult.saved);
      final e = access.saveCalls.single;
      expect([e.durationMinutes, e.bedtimeLocal, e.wakeTimeLocal, e.restQuality], [510, '23:30', '07:00', 4]);
    });

    test('repeated Save while a save is in progress is the same single write', () async {
      final c = await started();
      access.saveGate = Completer<void>();
      final a = c.save();
      final b = c.save();
      expect(identical(a, b), isTrue);
      await pumpEventQueue();
      access.saveGate!.complete();
      await a;
      expect(access.saveCalls, hasLength(1));
    });

    test('dispose stops listening; a save finishing afterwards does not notify', () async {
      final c = SleepController(access: access, now: () => now);
      await c.start();
      access.saveGate = Completer<void>();
      final f = c.save();
      c.dispose();
      expect(access.listenerCount, 0);
      access.saveGate!.complete();
      expect(await f, SleepSaveResult.saved);
    });
  });

  group('Midnight before Save', () {
    test('new wake-up day read: no stale write; adjusted values kept; review required before saving', () async {
      access.seed(today, tz, minutes: 420, bedtime: '00:00', wake: '07:00', quality: 3, changed: {duration, bed, quality});
      final c = await started();
      c.setQuality(5); // adjusted on the old form
      now = DateTime(2026, 11, 12, 0, 10);
      expect(await c.save(), SleepSaveResult.dayChanged);
      expect(access.saveCalls, isEmpty, reason: 'nothing written for the stale date');
      expect(c.phase, SleepPhase.dateChanged);
      expect(c.wakeDay!.date, '2026-11-12');
      expect(c.hasExistingEntry, isFalse);
      expect(c.quality, 5, reason: 'adjusted value kept');
      expect([c.durationMinutes, c.bedtime], [450, '23:30'], reason: "untouched values do not carry yesterday's record");
      expect(access.records[today]!.entry.restQuality, 3, reason: "the old day's record is untouched");
      expect(await c.save(), SleepSaveResult.saved, reason: 'an explicit second Save after review');
      expect(access.saveCalls.single.day.date, '2026-11-12');
    });

    test('new wake-up day cannot be read: no write; values unchanged; the retry reads first and asks for review',
        () async {
      final c = await started();
      c.setDurationHours(6);
      now = DateTime(2026, 11, 12, 0, 10);
      access.loadOutcome = const SleepLoadFailed();
      expect(await c.save(), SleepSaveResult.dayChangedNotReloaded);
      expect(access.saveCalls, isEmpty);
      expect(c.durationMinutes, 360);
      access.loadOutcome = null;
      expect(await c.save(), SleepSaveResult.dayChanged, reason: 'refreshed, then review: still no write');
      expect(access.saveCalls, isEmpty);
      expect(c.wakeDay!.date, '2026-11-12');
      expect(await c.save(), SleepSaveResult.saved);
      expect(access.saveCalls.single.day.date, '2026-11-12');
    });
  });

  group('History', () {
    test('the last 7 wake-up days are read through loadRange; only stored records appear', () async {
      access.seed('2026-11-09', tz, minutes: 480, bedtime: '23:30', wake: '07:30', quality: 4,
          changed: {duration, wake}, id: 'r1');
      access.seed('2026-11-04', tz, minutes: 300, bedtime: '01:00', wake: '06:00', quality: 2,
          changed: {duration, bed, wake, quality}, id: 'r0'); // outside the window
      final c = await started();
      expect(access.rangeCalls.single, ('2026-11-05', today));
      expect(c.history!.map((r) => r.entry.day.date), ['2026-11-09']);
      await c.save();
      await pumpEventQueue();
      expect(c.history!.map((r) => r.entry.day.date), ['2026-11-09', today], reason: 'refreshed after a save');
    });

    test('history crosses a month boundary by calendar date', () async {
      now = DateTime(2026, 12, 2, 7);
      final c = await started();
      expect(access.rangeCalls.single, ('2026-11-26', '2026-12-02'));
      expect(c.history, isEmpty);
    });

    test('an unreadable history is unavailable (null), never invented', () async {
      access.rangeOutcome = const SleepRangeUnavailable();
      final c = await started();
      expect(c.history, isNull);
    });
  });
}
