import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'presentation/redesign/nature_home_preview.dart';

/// Redesign preview entry point (stage 3 prototype). The real app entry
/// point, `lib/main.dart`, is unchanged.
///
///   cd mobile
///   flutter run -d chrome --web-port 8766 -t lib/main_redesign_preview.dart
///
/// Opens straight on the redesigned Home (no splash/onboarding/consent).
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _RedesignPreviewApp());
}

class _RedesignPreviewApp extends StatelessWidget {
  const _RedesignPreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SENSE redesign preview',
      debugShowCheckedModeBanner: false,
      // Current theme for the screens that are not redesigned yet; the Home
      // preview uses the nature tokens directly.
      theme: AppTheme.lightTheme,
      home: const NatureHomePreview(),
    );
  }
}
