import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mindpulse/data/local/encrypted/encrypted_database.dart';
import 'package:mindpulse/data/local/local_data_store.dart';

/// Milestone J: the encrypted database survives an application restart (a new
/// process: new Keystore lookup, new envelope read, new SQLCipher connection).
///
/// Two separate runs, with the app process killed in between and the app (and
/// so its Keystore key and files) kept installed:
///
///   flutter test integration_test/encrypted_restart_test.dart -d emulator-5554 \
///       --no-uninstall --dart-define=SENSE_RESTART_PHASE=1
///   adb -s emulator-5554 shell am force-stop org.sense.mindpulse.dev
///   flutter test integration_test/encrypted_restart_test.dart -d emulator-5554 \
///       --dart-define=SENSE_RESTART_PHASE=2
///
/// Phase 2 destroys the test namespace at the end.
const int _phase = int.fromEnvironment('SENSE_RESTART_PHASE');
const String _ns = 'itest_restart';
const String _sentinel = 'SENSE-RESTART-SENTINEL-v1';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final platform = createDefaultSecureKeyPlatform();

  testWidgets('restart phase $_phase', (tester) async {
    expect(_phase, anyOf(1, 2), reason: 'pass --dart-define=SENSE_RESTART_PHASE=1 or 2');
    final provider = EncryptedDatabaseProvider(testNamespace: _ns);

    if (_phase == 1) {
      await platform.destroy(testNamespace: _ns); // start from a clean test namespace
      final o = await provider.open() as EncryptedDatabaseOpened;
      expect(o.firstInitialization, isTrue);
      final person = (await LocalDataStore(o.database).profiles.ensureActive()).localPersonId;
      await o.database.execute('CREATE TABLE probe (v TEXT NOT NULL, person TEXT NOT NULL)');
      await o.database.insert('probe', {'v': _sentinel, 'person': person});
      await o.database.close();
      // ignore: avoid_print
      print('SENSE-EVIDENCE restart phase 1 wrote sentinel; pid-bound state closed');
      return;
    }

    final r = await provider.open();
    expect(r, isA<EncryptedDatabaseOpened>(), reason: '$r');
    final o = r as EncryptedDatabaseOpened;
    expect(o.firstInitialization, isFalse, reason: 'phase 2 must reuse the key created in phase 1');
    expect(o.cipherVersion, startsWith(kExpectedSqlCipherVersion));
    final row = (await o.database.query('probe')).single;
    expect(row['v'], _sentinel);
    expect((await LocalDataStore(o.database).profiles.active())!.localPersonId, row['person']);
    expect((await o.database.rawQuery('PRAGMA integrity_check')).first.values.first, 'ok');
    await o.database.close();
    final report = await provider.destroyKeyAndDatabase();
    expect(report.cryptographicallyErased, isTrue);
    // ignore: avoid_print
    print('SENSE-EVIDENCE restart phase 2 read sentinel after process restart; namespace destroyed');
  });
}
