import 'package:flutter/material.dart';

import '../../core/theme/nature_tokens.dart';
import '../nature/arrival_art.dart';
import '../widgets/sense_logo.dart';
import 'onboarding_screen.dart';

/// Production Splash (Living Landscapes, Phase 5).
///
/// Behaviour is unchanged: after 1.8 seconds the splash replaces itself with
/// [OnboardingScreen]. Nothing is loaded or initialised meanwhile (there are
/// no models, sensors or services to start), so the screen says nothing about
/// loading. The only motion is a short fade-in of the mark and name, skipped
/// entirely with reduced motion.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  /// How long the splash stays before onboarding (unchanged).
  static const Duration duration = Duration(milliseconds: 1800);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
    Future.delayed(SplashScreen.duration, () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    final size = MediaQuery.sizeOf(context);
    final mark = (size.shortestSide * 0.22).clamp(76.0, 112.0);
    return Theme(
      data: NatureTheme.light,
      child: Scaffold(
        backgroundColor: NatureColors.background,
        // The text never sits on the illustration: the horizon has its own
        // strip at the foot of the screen.
        body: Column(
          children: [
            Expanded(
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: AnimatedOpacity(
                      opacity: still || _shown ? 1 : 0,
                      duration: still ? Duration.zero : const Duration(milliseconds: 600),
                      curve: NatureMotion.ease,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // The forest mark, printed over an off-register ochre plate.
                            SizedBox(
                              width: mark + 8,
                              height: mark + 8,
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: 7,
                                    top: 8,
                                    child: Container(
                                      width: mark,
                                      height: mark,
                                      decoration: BoxDecoration(
                                        color: NatureColors.sunOchre.withValues(alpha: 0.7),
                                        borderRadius: BorderRadius.circular(mark * 0.22),
                                      ),
                                    ),
                                  ),
                                  SenseLogoMark(size: mark, variant: SenseLogoVariant.forestBadge),
                                ],
                              ),
                            ),
                            const SizedBox(height: 26),
                            Text(
                              'SENSE',
                              style: NatureType.greeting.copyWith(
                                fontSize: 40,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 6,
                                color: NatureColors.forest,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Personal Well-being & Stress-Pattern Monitoring',
                              style: NatureType.label.copyWith(color: NatureColors.ink),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Non-clinical research prototype',
                              style: NatureType.bodyMuted.copyWith(fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: (size.height * 0.26).clamp(120.0, 280.0),
              width: double.infinity,
              child: const SplashHorizon(),
            ),
          ],
        ),
      ),
    );
  }
}
