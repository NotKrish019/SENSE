import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Milestone J hardening: static checks of the Android security configuration.
///
/// - M3: the backup / data-extraction policy (manifest + res/xml rules).
/// - M4: Gradle dependency verification pins the reviewed SQLCipher artifact.
///
/// These read the source files only. The merged manifests of the built
/// debug/profile/release APKs and a physical-device backup test are separate
/// (see docs/architecture/encrypted_local_storage.md).
void main() {
  String read(String p) => File(p).readAsStringSync();
  const manifestPath = 'android/app/src/main/AndroidManifest.xml';
  const extractionPath = 'android/app/src/main/res/xml/data_extraction_rules.xml';
  const fullBackupPath = 'android/app/src/main/res/xml/full_backup_content.xml';
  const verificationPath = 'android/gradle/verification-metadata.xml';

  /// Every storage domain Android backup knows about.
  const domains = [
    'root',
    'file',
    'database',
    'sharedpref',
    'external',
    'device_root',
    'device_file',
    'device_database',
    'device_sharedpref',
  ];

  /// The legacy plaintext database and its sidecar files.
  const legacy = ['mindpulse_secure.db', 'mindpulse_secure.db-journal', 'mindpulse_secure.db-wal', 'mindpulse_secure.db-shm'];

  String withoutComments(String xml) => xml.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

  String section(String xml, String tag) {
    final m = RegExp('<$tag\\b[^>]*>(.*?)</$tag>', dotAll: true).firstMatch(withoutComments(xml));
    expect(m, isNotNull, reason: '<$tag> section missing');
    return m!.group(1)!;
  }

  void expectEverythingExcluded(String body, String where) {
    expect(body, isNot(contains('<include')), reason: '$where must not include anything');
    for (final d in domains) {
      expect(body, contains('<exclude domain="$d" path="." />'), reason: '$where: domain $d');
    }
    for (final f in legacy) {
      expect(body, contains('<exclude domain="database" path="$f" />'), reason: '$where: $f');
    }
  }

  group('M3: backup and data-extraction policy', () {
    test('the manifest disables backup and references both rule files', () {
      final manifest = withoutComments(read(manifestPath));
      expect(manifest, contains('android:allowBackup="false"'));
      expect(manifest, contains('android:fullBackupContent="@xml/full_backup_content"'));
      expect(manifest, contains('android:dataExtractionRules="@xml/data_extraction_rules"'));
      expect(File(extractionPath).existsSync(), isTrue);
      expect(File(fullBackupPath).existsSync(), isTrue);
    });

    test('Android 12+: every domain is excluded from cloud backup AND device-to-device transfer', () {
      final xml = read(extractionPath);
      expect(withoutComments(xml), contains('<cloud-backup disableIfNoEncryptionCapabilities="true">'));
      expectEverythingExcluded(section(xml, 'cloud-backup'), 'cloud-backup');
      expectEverythingExcluded(section(xml, 'device-transfer'), 'device-transfer');
    });

    test('Android 11 and earlier: every domain is excluded from full backup', () {
      expectEverythingExcluded(section(read(fullBackupPath), 'full-backup-content'), 'full-backup-content');
    });

    test('no permission is requested by the app manifest', () {
      expect(withoutComments(read(manifestPath)), isNot(contains('<uses-permission')));
    });
  });

  group('M4: Gradle dependency verification', () {
    final xml = read(verificationPath);
    final components = RegExp(r'<component group="([^"]+)" name="([^"]+)" version="([^"]+)">(.*?)</component>', dotAll: true)
        .allMatches(xml)
        .toList();

    test('verification metadata exists and verifies metadata; no artifact is trusted without a checksum', () {
      expect(xml, contains('<verify-metadata>true</verify-metadata>'));
      expect(xml, isNot(contains('<trusted-artifacts>')), reason: 'no blanket trust rules');
      expect(components.length, greaterThan(100));
      final artifacts = RegExp(r'<artifact name="[^"]+">(.*?)</artifact>', dotAll: true).allMatches(xml).toList();
      expect(artifacts, isNotEmpty);
      for (final a in artifacts) {
        expect(a.group(1), contains(RegExp(r'<sha256 value="[0-9a-f]{64}"')), reason: a.group(0));
      }
    });

    test('exactly one SQLCipher artifact is allowed: net.zetetic:sqlcipher-android:4.20.0 (reviewed SHA-256)', () {
      final sqlcipher = components.where((m) => m.group(1) == 'net.zetetic' || m.group(2)!.contains('sqlcipher')).toList();
      expect(sqlcipher.map((m) => '${m.group(1)}:${m.group(2)}:${m.group(3)}'), ['net.zetetic:sqlcipher-android:4.20.0']);
      expect(
          sqlcipher.single.group(4),
          contains('<artifact name="sqlcipher-android-4.20.0.aar">\n'
              '            <sha256 value="1e57857adfd29e2f5ddb4686e1e5ec6659920220d4bf182fdb5ef085b5577100"'));
      expect(xml, isNot(contains('android-database-sqlcipher')));
    });

    test('the Gradle pin, the verification metadata and the Dart constant agree on 4.20.0', () {
      final gradle = read('android/build.gradle.kts');
      expect(gradle, contains('val sqlcipherAndroidVersion = "4.20.0"'));
      expect(gradle, contains('android-database-sqlcipher'), reason: 'the legacy artifact is rejected by name');
      expect(read('lib/data/local/encrypted/encrypted_database.dart'), contains("kExpectedSqlCipherVersion = '4.20.0'"));
    });

    test('the Dart driver stays pinned to the reviewed archive', () {
      expect(read('pubspec.yaml'), contains(RegExp(r'^  sqflite_sqlcipher: 3\.4\.1$', multiLine: true)));
      final lock = read('pubspec.lock');
      final entry = RegExp(r'  sqflite_sqlcipher:\n(.*?)\n    version: "([^"]+)"', dotAll: true).firstMatch(lock)!;
      expect(entry.group(2), '3.4.1');
      expect(entry.group(1), contains('sha256: "50d05fe0495ed96a85503d9850a49c0936502f44fdba96f403c97e4c9c7043e7"'));
      expect(entry.group(1), contains('url: "https://pub.dev"'));
    });
  });
}
