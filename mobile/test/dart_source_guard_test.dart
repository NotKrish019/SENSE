// Milestone K2: regression tests for the analyzer-based source facts used by
// the static architecture guards (test/support/dart_source_guard.dart). Each
// case parses a small throwaway source file, so a guard that silently stopped
// seeing a construct (a quote style, an export without `show`, a `?.` access)
// fails here instead of passing vacuously.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/dart_source_guard.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('sense_guard_'));
  tearDown(() => dir.deleteSync(recursive: true));

  DartSourceFacts parse(String source, {String name = 'lib/probe/probe.dart'}) {
    final f = File('${dir.path}/$name')..createSync(recursive: true);
    f.writeAsStringSync(source);
    return DartSourceFacts.parse(f.path);
  }

  test('show lists are recorded per export; exports without show (or with hide only) have none', () {
    final f = parse('''
export 'a.dart' show A, B;
export "b.dart" show C show D;
export 'c.dart';
export 'd.dart' hide E;
export 'e.dart' if (dart.library.io) 'e_io.dart' show F;
''');
    final exports = f.of(DirectiveKind.export).toList();
    expect(exports.map((e) => e.uri), ['a.dart', 'b.dart', 'c.dart', 'd.dart', 'e.dart', 'e_io.dart']);
    expect(exports.map((e) => e.shown), [
      ['A', 'B'],
      ['C', 'D'],
      null,
      null,
      ['F'],
      ['F'],
    ]);
  });

  test('a guard requiring show lists rejects a bare export and a hide-only export', () {
    bool allShown(DartSourceFacts f) => f.of(DirectiveKind.export).every((e) => e.shown != null);
    expect(allShown(parse("export 'x.dart' show X;")), isTrue);
    expect(allShown(parse("export 'x.dart' show X;\nexport 'y.dart';", name: 'lib/probe/b.dart')), isFalse);
    expect(allShown(parse("export 'y.dart' hide Database;", name: 'lib/probe/c.dart')), isFalse);
  });

  test('a re-exported database type is visible to the guard through the show list', () {
    final f = parse("export 'local_data_store.dart' show WorkloadEntry, LocalDataStore;");
    expect(f.of(DirectiveKind.export).single.shown, contains('LocalDataStore'));
  });

  test('double-quoted imports and package URIs resolve to project paths', () {
    final f = parse('''
import "../data/local/sense_storage.dart";
import 'package:mindpulse/data/local/local_data_store.dart';
''', name: 'lib/presentation/probe.dart');
    // Relative URIs resolve against the file's own path (the guards parse
    // project-relative paths, so there they read 'lib/...').
    final deps = f.projectDependencies.toList();
    expect(deps, hasLength(2));
    expect(deps[0], endsWith('/lib/data/local/sense_storage.dart'));
    expect(deps[1], 'lib/data/local/local_data_store.dart');
  });

  test('member accesses through ?. and object patterns are seen; comments and strings are not', () {
    final f = parse('''
void f(dynamic s, Object o) {
  s?.ready;
  s..store;
  if (o case StorageReady(:final database)) {}
  // s.upsert(x);
  final t = 's.execute()';
}
class StorageReady { final Object database = 0; }
''');
    expect(f.memberAccesses, containsAll(['ready', 'store', 'database']));
    expect(f.memberAccesses, isNot(contains('upsert')));
    expect(f.memberAccesses, isNot(contains('execute')));
  });

  test('call sites record where an untargeted call sits; identifier counts are exact', () {
    final f = parse('''
void a(dynamic c) {
  final w = WorkloadController(access: workloadAccessOf(c));
  workloadAccessOf(c)?.save(null);
  final g = workloadAccessOf;
  new Holder(x: workloadAccessOf(c));
}
''');
    // The direct `?.save` use is recorded as a third, different site (its
    // parent node type), so a guard requiring only the controller hand-off fails.
    final sites = f.callSites['workloadAccessOf']!;
    expect(sites, hasLength(3));
    expect(sites, containsAll(['WorkloadController(access:)', 'Holder(x:)']));
    expect(sites.where((x) => x.startsWith('MethodInvocation')), hasLength(1));
    expect(f.identifierCounts['workloadAccessOf'], 4, reason: 'the tear-off counts too');
  });

  test('a file that does not parse fails instead of being skipped', () {
    // The analyzer reports the syntax error by throwing (ArgumentError).
    expect(() => parse('export ;'), throwsA(isA<Error>()));
  });
}
