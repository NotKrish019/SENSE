import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/sense_button.dart';
import '../widgets/sense_card.dart';
import 'consent_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _slides = [
    {
      'icon': Icons.insights_rounded,
      'title': 'Compared with you, not with averages',
      'body':
          'SENSE is being designed to compare your entries with your own history rather than '
          'with population averages. Personal baselines are not calculated yet in this prototype.',
      'badge': 'Research goal: personal baselines',
    },
    {
      'icon': Icons.tune_rounded,
      'title': 'Your Data, Your Voluntary Pace',
      'body':
          'Every input is optional and separate. Skipping an input will never be treated as a '
          'sign of stress.',
      'badge': 'Optional Multi-Modality',
    },
    {
      'icon': Icons.lock_outline_rounded,
      'title': 'Privacy-First & Non-Clinical',
      'body':
          'SENSE is designed to offer supportive well-being observations, not medical diagnoses. '
          'This early prototype does not save or share anything you enter; secure storage, '
          'export and deletion will be built before any real data is collected.',
      'badge': 'Non-clinical research prototype',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SenseColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            children: [
              // Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SenseColors.primaryActionGradient,
                        ),
                        child: const Icon(Icons.waves_rounded, color: SenseColors.white, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'SENSE',
                        style: SenseTypography.labelBold.copyWith(
                          fontSize: 16,
                          letterSpacing: 1.5,
                          color: SenseColors.navy900,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _openConsent,
                    child: Text(
                      'Skip',
                      style: SenseTypography.labelBold.copyWith(color: SenseColors.blue800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Carousel Content: takes all free space (was a fixed 380 px box),
              // so larger text only scrolls when the screen genuinely runs out.
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (idx) => setState(() => _currentPage = idx),
                  itemCount: _slides.length,
                  itemBuilder: (context, idx) {
                    final item = _slides[idx];
                    // Scrolls only if the text does not fit (e.g. large system
                    // text size); otherwise stays centred as before.
                    return Center(
                      child: SingleChildScrollView(
                        child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SenseCard(
                          padding: const EdgeInsets.all(28),
                          child: Icon(
                            item['icon'] as IconData,
                            size: 56,
                            color: SenseColors.blue600,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD6EFFC),
                            borderRadius: SenseRadii.pillBorder,
                          ),
                          child: Text(
                            item['badge'] as String,
                            style: SenseTypography.captionMedium.copyWith(
                              color: SenseColors.blue800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          item['title'] as String,
                          style: SenseTypography.h2.copyWith(
                            color: SenseColors.navy900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item['body'] as String,
                          style: SenseTypography.body.copyWith(
                            color: SenseColors.textSecondary,
                            height: 1.45,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Page Indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _slides.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: SenseRadii.pillBorder,
                      color: _currentPage == i ? SenseColors.blue600 : const Color(0xFFC7E2F2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Action Button
              SenseButton(
                label: _currentPage == _slides.length - 1 ? 'Get Started' : 'Continue',
                icon: Icons.arrow_forward_rounded,
                onPressed: () {
                  if (_currentPage < _slides.length - 1) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeInOut,
                    );
                  } else {
                    _openConsent();
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // Both "Skip" and "Get Started" lead to consent: no route bypasses it.
  // push (not replace) keeps onboarding underneath, so Back from consent
  // returns to the slide the user left instead of restarting onboarding.
  void _openConsent() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ConsentScreen()),
    );
  }
}
