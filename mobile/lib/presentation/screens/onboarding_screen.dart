import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/sense_button.dart';
import '../widgets/sense_card.dart';
import 'dashboard_screen.dart';

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
      'title': 'Understand Your Personal Equilibrium',
      'body':
          'SENSE models your unique historical baseline rather than comparing you to generic population averages. Observe how sleep, workload, and daily habits interact.',
      'badge': 'Personalized Baseline Modeling',
    },
    {
      'icon': Icons.tune_rounded,
      'title': 'Your Data, Your Voluntary Pace',
      'body':
          'Every input is optional and separate. Whether you complete a 30-second check-in or track sleep, SENSE adapts gracefully without penalizing missing data.',
      'badge': 'Optional Multi-Modality',
    },
    {
      'icon': Icons.lock_outline_rounded,
      'title': 'Privacy-First & Non-Clinical',
      'body':
          'SENSE provides supportive well-being observations, not medical diagnoses. All personal data is encrypted locally with complete export and erasure rights.',
      'badge': 'DPDP Act 2023 Compliant',
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
                    onPressed: () => _navigateToDashboard(),
                    child: Text(
                      'Skip',
                      style: SenseTypography.labelBold.copyWith(color: SenseColors.blue800),
                    ),
                  ),
                ],
              ),
              const Spacer(),

              // Carousel Content
              SizedBox(
                height: 380,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (idx) => setState(() => _currentPage = idx),
                  itemCount: _slides.length,
                  itemBuilder: (context, idx) {
                    final item = _slides[idx];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                            textAlign: TextAlign.center,
                            color: SenseColors.navy900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item['body'] as String,
                          style: SenseTypography.body.copyWith(
                            textAlign: TextAlign.center,
                            color: SenseColors.textSecondary,
                            height: 1.45,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  },
                ),
              ),

              const Spacer(),

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
                    _navigateToDashboard();
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

  void _navigateToDashboard() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }
}
