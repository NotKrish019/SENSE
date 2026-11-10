import 'dart:async';

import 'package:flutter/material.dart';

import 'core/state/consent_preferences.dart';
import 'core/theme/app_theme.dart';
import 'data/local/sense_storage.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/widgets/sense_storage_scope.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SenseApp());
}

/// The app. Owns the single [SenseStorage] (Milestone K1) and connects the
/// shared consent preferences to it.
///
/// Startup opens storage only when this build allows it: the isolated
/// development namespace in a debug build with
/// `--dart-define=SENSE_DEV_STORAGE=1`. Otherwise nothing is opened, the
/// participant database is never touched, and the app behaves as before
/// (preferences in memory, nothing saved). Unavailable storage never stops
/// the app from starting.
class SenseApp extends StatefulWidget {
  /// Injected for tests; normally created from this build's policy.
  final SenseStorage? storage;

  /// Injected for tests; normally [ConsentPreferences.instance].
  final ConsentPreferences? consent;

  const SenseApp({super.key, this.storage, this.consent});

  @override
  State<SenseApp> createState() => _SenseAppState();
}

class _SenseAppState extends State<SenseApp> {
  late final SenseStorage _storage;
  late final bool _ownsStorage;
  late final ConsentPreferences _consent;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _ownsStorage = widget.storage == null;
    _storage = widget.storage ?? SenseStorage(policy: SenseStoragePolicy.fromEnvironment());
    _consent = widget.consent ?? ConsentPreferences.instance;
    _consent.attach(_storage);
    // Close the connection (and release its lease) when the engine detaches.
    _lifecycle = AppLifecycleListener(onDetach: () => unawaited(_storage.close()));
    unawaited(_storage.start());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _consent.detach();
    if (_ownsStorage) unawaited(_storage.shutdown());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SenseStorageScope(
      storage: _storage,
      child: MaterialApp(
        title: 'SENSE',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        builder: (context, child) => DevelopmentStorageBanner(
          enabled: _storage.developmentStorageEnabled,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
