import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/sense_logo.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SenseColors.navy900,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // SENSE mark (badge variant): two signal paths meeting at a node.
            const DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(18)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x66059BE0),
                    blurRadius: 28,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: SenseLogoMark(size: 80),
            ),
            const SizedBox(height: 24),
            Text(
              'SENSE',
              style: SenseTypography.display.copyWith(
                color: SenseColors.white,
                fontSize: 36,
                letterSpacing: 4.0,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Personal Well-being & Stress-Pattern Monitoring',
              style: SenseTypography.captionMedium.copyWith(
                color: const Color(0xFFB0D9F7),
                fontSize: 13,
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

