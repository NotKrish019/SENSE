/// Syntax-aware source facts for the static architecture guards (Milestone K1).
///
/// Each file is parsed with the Dart analyzer, so the guards see real
/// directives and real code tokens: single- or double-quoted, raw or adjacent
/// string URIs; `import`, `export` and `part` directives, including
/// conditional (`if (dart.library.io) '...'`) URIs; and identifiers in code
/// only (never in comments or string literals, but including string
/// interpolations, which are code). A file that does not parse fails the
/// guard instead of being skipped.
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

enum DirectiveKind { import, export, part }

class DirectiveFact {
  final DirectiveKind kind;

  /// The URI exactly as written, without quotes.
  final String uri;

  /// The URI resolved to a project path (`lib/...`) for relative and
  /// same-package URIs; null for `dart:` and other packages.
  final String? projectPath;

  /// Names listed in `show` combinators (Milestone K2), or null when the
  /// directive has no `show` (everything is visible). Configurations of a
  /// conditional directive share the directive's combinators.
  final List<String>? shown;

  const DirectiveFact(this.kind, this.uri, this.projectPath, [this.shown]);

  @override
  String toString() => '${kind.name} $uri';
}

class DartSourceFacts {
  /// Project-relative path with forward slashes (`lib/main.dart`).
  final String path;
  final List<DirectiveFact> directives;

  /// Every identifier token in code.
  final Set<String> identifiers;

  /// Identifiers that follow a member-access operator (`.`, `?.`, `..`,
  /// `?..`), and object-pattern field names (`StorageReady(:final database)`).
  final Set<String> memberAccesses;

  /// How often each identifier occurs in code (Milestone K2).
  final Map<String, int> identifierCounts;

  /// For each call of an untargeted function or constructor (`f(...)`), where
  /// the call sits: `Callee(label:)` when it is the named argument `label` of
  /// a call to `Callee`, otherwise the parent node's type (Milestone K2).
  final Map<String, Set<String>> callSites;

  const DartSourceFacts._(
      this.path, this.directives, this.identifiers, this.memberAccesses, this.identifierCounts, this.callSites);

  Iterable<String> get uris => directives.map((d) => d.uri);
  Iterable<DirectiveFact> of(DirectiveKind kind) => directives.where((d) => d.kind == kind);

  /// Project paths this file imports, exports or includes as a part.
  Iterable<String> get projectDependencies => directives.map((d) => d.projectPath).whereType<String>();

  static DartSourceFacts parse(String path, {String packageName = 'mindpulse'}) {
    final normalized = path.replaceAll('\\', '/');
    final result = parseString(content: File(normalized).readAsStringSync(), path: normalized);
    if (result.errors.isNotEmpty) {
      throw StateError('$normalized does not parse: ${result.errors.first}');
    }
    final unit = result.unit;

    final directives = <DirectiveFact>[];
    void add(DirectiveKind kind, StringLiteral literal, [List<String>? shown]) {
      final uri = literal.stringValue;
      if (uri == null) throw StateError('$normalized: a directive URI is not a constant string');
      directives.add(DirectiveFact(kind, uri, _resolve(normalized, uri, packageName), shown));
    }

    for (final d in unit.directives) {
      final kind = switch (d) {
        ImportDirective() => DirectiveKind.import,
        ExportDirective() => DirectiveKind.export,
        PartDirective() => DirectiveKind.part,
        _ => null,
      };
      if (kind == null || d is! UriBasedDirective) continue;
      List<String>? shown;
      if (d is NamespaceDirective) {
        final shows = d.combinators.whereType<ShowCombinator>().toList();
        if (shows.isNotEmpty) {
          shown = [for (final c in shows) for (final n in c.shownNames) n.name];
        }
      }
      add(kind, d.uri, shown);
      if (d is NamespaceDirective) {
        for (final c in d.configurations) {
          add(kind, c.uri, shown);
        }
      }
    }

    final identifiers = <String>{};
    final counts = <String, int>{};
    final members = <String>{};
    for (Token? t = unit.beginToken; t != null && !t.isEof; t = t.next) {
      if (!t.isIdentifier) continue;
      identifiers.add(t.lexeme);
      counts[t.lexeme] = (counts[t.lexeme] ?? 0) + 1;
      final previous = t.previous?.type;
      if (previous == TokenType.PERIOD ||
          previous == TokenType.QUESTION_PERIOD ||
          previous == TokenType.PERIOD_PERIOD ||
          previous == TokenType.QUESTION_PERIOD_PERIOD) {
        members.add(t.lexeme);
      }
    }
    // Object-pattern fields read a getter too: `StorageReady(:final database)`.
    unit.accept(_PatternFieldNames(members));
    final sites = <String, Set<String>>{};
    unit.accept(_CallSites(sites));
    return DartSourceFacts._(normalized, List.unmodifiable(directives), identifiers, members, counts, sites);
  }

  static String? _resolve(String from, String uri, String packageName) {
    if (uri.startsWith('package:$packageName/')) {
      return 'lib/${uri.substring('package:$packageName/'.length)}';
    }
    if (uri.contains(':')) return null;
    final segments = from.split('/')..removeLast();
    for (final s in uri.split('/')) {
      if (s == '..') {
        segments.removeLast();
      } else if (s != '.') {
        segments.add(s);
      }
    }
    return segments.join('/');
  }
}

class _PatternFieldNames extends RecursiveAstVisitor<void> {
  final Set<String> names;
  _PatternFieldNames(this.names);

  @override
  void visitPatternField(PatternField node) {
    final name = node.effectiveName;
    if (name != null) names.add(name);
    super.visitPatternField(node);
  }
}

class _CallSites extends RecursiveAstVisitor<void> {
  final Map<String, Set<String>> sites;
  _CallSites(this.sites);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Untargeted calls only: `f(...)`, not `x.f(...)` or `..f(...)`.
    if (node.target == null && !node.isCascaded) {
      final parent = node.parent;
      String site = parent.runtimeType.toString();
      if (parent is NamedArgument && parent.parent is ArgumentList) {
        final owner = parent.parent!.parent;
        final callee = switch (owner) {
          MethodInvocation(:final methodName) => methodName.name,
          InstanceCreationExpression(:final constructorName) => constructorName.toSource(),
          _ => owner.runtimeType.toString(),
        };
        site = '$callee(${parent.name.lexeme}:)';
      }
      sites.putIfAbsent(node.methodName.name, () => {}).add(site);
    }
    super.visitMethodInvocation(node);
  }
}

/// Every `.dart` file under [root], parsed, keyed by project path.
Map<String, DartSourceFacts> parseDartTree(String root) {
  final pkg = RegExp(r'^name:\s*(\S+)', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync())![1]!;
  final files = Directory(root)
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => f.path.replaceAll('\\', '/'))
      .where((p) => p.endsWith('.dart'))
      .toList()
    ..sort();
  return {for (final p in files) p: DartSourceFacts.parse(p, packageName: pkg)};
}
