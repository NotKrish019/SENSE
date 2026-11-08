import 'package:flutter/material.dart';

import '../../core/theme/nature_tokens.dart';
import '../nature/arrival_art.dart';
import '../nature/nature_widgets.dart';
import '../widgets/sense_logo.dart';
import '../widgets/sense_tappable.dart';
import 'consent_screen.dart';

/// One onboarding step: the original title, body and badge (meaning
/// unchanged), plus a short "now / planned" note that separates what the
/// prototype does today from what is planned.
class OnboardingStep {
  final OnboardingMotifKind motif;
  final String badge;
  final String title;
  final String body;
  final String now;
  final String planned;
  const OnboardingStep({
    required this.motif,
    required this.badge,
    required this.title,
    required this.body,
    required this.now,
    required this.planned,
  });
}

/// Production Onboarding (Living Landscapes, Phase 5).
///
/// Three steps, in the original order and with the original meaning. Flow is
/// unchanged: "Continue" moves to the next step; on the last step it reads
/// "Get Started"; "Get Started" and "Skip" both open [ConsentScreen] on top
/// (no route bypasses consent, and Back from consent returns to the step the
/// person left). New: a "Back" button returns to the previous step (swiping
/// still works), and "Step n of 3" is shown and announced. With reduced
/// motion, steps change without the slide animation.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const List<OnboardingStep> steps = [
    OnboardingStep(
      motif: OnboardingMotifKind.contours,
      badge: 'Research goal: personal baselines',
      title: 'Compared with you, not with averages',
      body: 'SENSE is being designed to compare your entries with your own history rather than '
          'with population averages. Personal baselines are not calculated yet in this prototype.',
      now: 'You can try the screens. Nothing you enter is saved.',
      planned: 'A personal baseline from about 14 days of saved check-ins.',
    ),
    OnboardingStep(
      motif: OnboardingMotifKind.stones,
      badge: 'Optional multi-modality',
      title: 'Your data, your voluntary pace',
      body: 'Every input is optional and separate. Skipping an input will never be treated as a '
          'sign of stress.',
      now: 'Check-in, journal, sleep, workload and activity can be tried by hand.',
      planned: 'Voice, and optional health-app sync for activity.',
    ),
    OnboardingStep(
      motif: OnboardingMotifKind.leaf,
      badge: 'Non-clinical research prototype',
      title: 'Privacy-first and non-clinical',
      body: 'SENSE is designed to offer supportive well-being observations, not medical diagnoses. '
          'This early prototype does not save or share anything you enter; secure storage, '
          'export and deletion will be built before any real data is collected.',
      now: 'Nothing you enter is saved or shared.',
      planned: 'Secure storage, export and deletion, before any real data is collected.',
    ),
  ];

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _steps = OnboardingScreen.steps;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    if (MediaQuery.of(context).disableAnimations) {
      _pageController.jumpToPage(page);
    } else {
      _pageController.animateToPage(page, duration: const Duration(milliseconds: 260), curve: Curves.easeInOut);
    }
  }

  void _next() {
    if (_currentPage < _steps.length - 1) {
      _goTo(_currentPage + 1);
    } else {
      _openConsent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _currentPage == _steps.length - 1;
    return Theme(
      data: NatureTheme.light,
      child: Scaffold(
        backgroundColor: NatureColors.background,
        body: SafeArea(
          child: LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= 840;
            final side = c.maxWidth > 1040 + 48 ? (c.maxWidth - 1040) / 2 : (wide ? 40.0 : 20.0);
            return Padding(
              padding: EdgeInsets.fromLTRB(side, 12, side, 16),
              child: Column(
                children: [
                  // Brand and Skip.
                  Row(
                    children: [
                      const Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SenseLogo(
                            variant: SenseLogoVariant.forestBadge,
                            markSize: 30,
                            wordmarkColor: NatureColors.forest,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      SenseTappable(
                        semanticLabel: 'Skip',
                        semanticHint: 'Opens data and consent preferences',
                        onTap: _openConsent,
                        focusColor: NatureColors.focus,
                        hoverColor: NatureColors.hover,
                        borderRadius: NatureRadii.smBorder,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48, minWidth: 64),
                          child: Center(
                            widthFactor: 1,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('Skip', style: NatureType.link),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _Progress(current: _currentPage, total: _steps.length, title: _steps[_currentPage].title),
                  const SizedBox(height: 8),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (idx) => setState(() => _currentPage = idx),
                      itemCount: _steps.length,
                      itemBuilder: (context, idx) => _StepPage(step: _steps[idx], wide: wide),
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(builder: (context, bc) {
                    final cont = NaturePrintedAction(
                      label: last ? 'Get Started' : 'Continue',
                      onTap: _next,
                    );
                    final back = _currentPage > 0
                        ? NatureQuietButton(label: 'Back', onTap: () => _goTo(_currentPage - 1))
                        : null;
                    final roomy = bc.maxWidth >= 440 && MediaQuery.textScalerOf(context).scale(1) <= 1.3;
                    final maxW = wide ? 560.0 : double.infinity;
                    if (roomy) {
                      return ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxW),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 2, child: back ?? const SizedBox.shrink()),
                            const SizedBox(width: 12),
                            Expanded(flex: 3, child: cont),
                          ],
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        cont,
                        if (back != null) ...[const SizedBox(height: 8), back],
                      ],
                    );
                  }),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  // Both "Skip" and "Get Started" lead to consent: no route bypasses it.
  // push (not replace) keeps onboarding underneath, so Back from consent
  // returns to the step the user left instead of restarting onboarding.
  void _openConsent() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ConsentScreen()),
    );
  }
}

/// "Step n of 3" in words, with three bars; announced when it changes.
class _Progress extends StatelessWidget {
  final int current;
  final int total;
  final String title;
  const _Progress({required this.current, required this.total, required this.title});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Step ${current + 1} of $total: $title',
      child: ExcludeSemantics(
        child: Row(
          children: [
            Text('Step ${current + 1} of $total', style: NatureType.eyebrow),
            const SizedBox(width: 12),
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Container(
                width: 26,
                height: 5,
                decoration: BoxDecoration(
                  color: i <= current ? NatureColors.forest : NatureColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepPage extends StatelessWidget {
  final OnboardingStep step;
  final bool wide;
  const _StepPage({required this.step, required this.wide});

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(step.badge,
            style: NatureType.eyebrow.copyWith(color: NatureColors.ochreInk),
            textAlign: wide ? TextAlign.start : TextAlign.center),
        const SizedBox(height: 8),
        Semantics(
          header: true,
          child: Text(step.title,
              style: NatureType.greeting.copyWith(fontSize: wide ? 30 : 24),
              textAlign: wide ? TextAlign.start : TextAlign.center),
        ),
        const SizedBox(height: 12),
        Text(step.body, style: NatureType.body, textAlign: wide ? TextAlign.start : TextAlign.center),
        const SizedBox(height: 18),
        _NowPlanned(now: step.now, planned: step.planned),
      ],
    );
    final motif = OnboardingMotif(kind: step.motif, size: wide ? 260 : 136);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  motif,
                  const SizedBox(width: 48),
                  Expanded(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: text)),
                ],
              )
            : ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: NatureBreakpoints.maxReading),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [motif, const SizedBox(height: 20), text],
                ),
              ),
      ),
    );
  }
}

/// Two short lines that keep today and the plan apart, labelled in words.
class _NowPlanned extends StatelessWidget {
  final String now;
  final String planned;
  const _NowPlanned({required this.now, required this.planned});

  @override
  Widget build(BuildContext context) {
    Widget line(String label, String text, Color rule) => Container(
          width: double.infinity,
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: rule, width: 3))),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: '$label: ', style: NatureType.label.copyWith(fontWeight: FontWeight.w600)),
              TextSpan(text: text, style: NatureType.bodyMuted),
            ]),
          ),
        );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          line('In this prototype', now, NatureColors.forest),
          const SizedBox(height: 8),
          line('Planned', planned, NatureColors.ochreInk),
        ],
      ),
    );
  }
}
