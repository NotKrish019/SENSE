// Living Landscapes design system: PRODUCTION code (Phase 1).
// Shared by the production screens and by the isolated redesign preview
// (lib/main_redesign_preview.dart). Moved here from the approved prototypes.
//
// Home sections: masthead, welcome, Today entry, ways to reflect, the
// sample observation and the support line.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/prototype_copy.dart';
import '../../core/theme/nature_tokens.dart';
import '../widgets/sense_tappable.dart';
import 'nature_navigation.dart';
import 'nature_widgets.dart';

// ---- Masthead (phone/tablet) -------------------------------------------------
class NatureMasthead extends StatelessWidget {
  final VoidCallback onProfile;

  /// Accessible name and tooltip of the profile button.
  final String profileLabel;

  /// Optional extra actions before the profile button (for example a
  /// developer-only control).
  final List<Widget> actions;
  const NatureMasthead({
    super.key,
    required this.onProfile,
    this.profileLabel = 'Profile, privacy and support contacts',
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // The wordmark is a logo lockup: it scales down rather than pushing
        // the controls off a narrow screen at large text sizes.
        const Flexible(
          child: FittedBox(
              fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: NatureWordmark()),
        ),
        const Spacer(),
        ...actions,
        SenseTappable(
          semanticLabel: profileLabel,
          tooltip: profileLabel,
          circle: true,
          focusColor: NatureColors.focus,
          hoverColor: NatureColors.hover,
          onTap: onProfile,
          child: const SizedBox(
            width: 48,
            height: 48,
            child: Icon(Icons.shield_outlined, color: NatureColors.ink, size: 23),
          ),
        ),
      ],
    );
  }
}


/// Greeting by local time of day (no personal data).
String natureGreeting(int hour) {
  if (hour >= 5 && hour < 12) return 'Good morning';
  if (hour >= 12 && hour < 17) return 'Good afternoon';
  return 'Good evening';
}

// ---- Welcome -------------------------------------------------------------------
class NatureWelcome extends StatelessWidget {
  final DateTime date;
  const NatureWelcome({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= NatureBreakpoints.desktop;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(DateFormat('EEEE d MMMM').format(date), style: NatureType.eyebrow),
        const SizedBox(height: 6),
        Text(natureGreeting(date.hour),
            style: NatureType.greeting.copyWith(fontSize: desktop ? 34 : 28)),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: const Text(
            'This is a quiet place to notice how you are doing. '
            'Everything here is optional, and you can stop at any time.',
            style: NatureType.bodyMuted,
          ),
        ),
      ],
    );
  }
}

// ---- Today: a journal entry with an ochre margin rule --------------------------
class NatureTodayEntry extends StatelessWidget {
  final VoidCallback onAbout;
  const NatureTodayEntry({super.key, required this.onAbout});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 560),
      padding: const EdgeInsets.only(left: 16),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: NatureColors.sunOchre, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Today', style: NatureType.eyebrow),
          const SizedBox(height: 4),
          Text(PrototypeCopy.noBaselineTitle, style: NatureType.statusTitle),
          const SizedBox(height: 6),
          Text(PrototypeCopy.noBaselineDescription, style: NatureType.bodyMuted),
          const SizedBox(height: 2),
          NatureTextLink(label: 'About your insights', onTap: onAbout),
        ],
      ),
    );
  }
}

class NatureModality {
  final IconData icon;
  final String title;
  final String detail;
  final Widget Function() screen;
  const NatureModality(this.icon, this.title, this.detail, this.screen);
}

class NatureWaysToReflect extends StatelessWidget {
  final List<NatureModality> modalities;
  final void Function(Widget) open;
  final int columns;
  const NatureWaysToReflect(
      {super.key, required this.modalities, required this.open, this.columns = 1});

  @override
  Widget build(BuildContext context) {
    // An open, ruled index (no card panel): hairlines between entries, the
    // way a contents page is set. One column on phones, two or three on
    // wider screens.
    Widget entry(NatureModality m) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 1, thickness: 1, color: NatureColors.divider),
            _ModalityRow(modality: m, onTap: () => open(m.screen()), first: false, last: false),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ways to reflect', style: NatureType.sectionTitle),
        const SizedBox(height: 4),
        const Text('Choose any, or none. Each one is voluntary.', style: NatureType.bodyMuted),
        const SizedBox(height: 14),
        if (columns == 1)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final m in modalities) entry(m),
              const Divider(height: 1, thickness: 1, color: NatureColors.divider),
            ],
          )
        else
          LayoutBuilder(builder: (context, c) {
            const gap = 40.0;
            final itemW = (c.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              children: [
                for (final m in modalities)
                  SizedBox(width: itemW, child: entry(m)),
              ],
            );
          }),
      ],
    );
  }
}

class _ModalityRow extends StatefulWidget {
  final NatureModality modality;
  final VoidCallback onTap;
  final bool first;
  final bool last;

  const _ModalityRow({required this.modality, required this.onTap, required this.first, required this.last});

  @override
  State<_ModalityRow> createState() => _ModalityRowState();
}

class _ModalityRowState extends State<_ModalityRow> {
  bool _active = false; // hover or press

  @override
  Widget build(BuildContext context) {
    final r = const Radius.circular(NatureRadii.md);
    final m = widget.modality;
    return SenseTappable(
      semanticLabel: '${m.title}. ${m.detail}',
      onTap: widget.onTap,
      focusColor: NatureColors.focus,
      hoverColor: NatureColors.hover,
      onHover: (v) => setState(() => _active = v),
      onHighlightChanged: (v) => setState(() => _active = v),
      borderRadius: BorderRadius.vertical(
          top: widget.first ? r : Radius.zero, bottom: widget.last ? r : Radius.zero),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 68),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              NaturePrintedIconWell(icon: m.icon, settled: _active),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.title, style: NatureType.label),
                    const SizedBox(height: 2),
                    Text(m.detail, style: NatureType.bodyMuted.copyWith(fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSlide(
                offset: Offset(_active ? 0.18 : 0, 0),
                // Reduced motion: the chevron still moves, but instantly.
                duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : NatureMotion.selection,
                curve: NatureMotion.ease,
                child: const Icon(Icons.chevron_right_rounded, color: NatureColors.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon in a sage well with an off-register outline ring (the risograph
/// signature). On hover/press the ring settles into register.
class NaturePrintedIconWell extends StatelessWidget {
  final IconData icon;
  final bool settled;
  const NaturePrintedIconWell({super.key, required this.icon, required this.settled});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        children: [
          Positioned(
            left: 2,
            top: 4,
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(color: NatureColors.paleSage, shape: BoxShape.circle),
              child: Icon(icon, size: 22, color: NatureColors.forest),
            ),
          ),
          AnimatedPositioned(
            // Reduced motion: the ring settles into register instantly.
            duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : NatureMotion.selection,
            curve: NatureMotion.ease,
            left: settled ? 2 : 4,
            top: settled ? 4 : 0,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: NatureColors.forest.withValues(alpha: 0.55), width: 1.2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Example observation (sample data) -------------------------------------
class NatureExampleObservation extends StatelessWidget {
  final VoidCallback onOpen;
  const NatureExampleObservation({super.key, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      decoration: BoxDecoration(
        color: NatureColors.surfaceQuiet,
        borderRadius: NatureRadii.mdBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NatureSampleTag(),
          const SizedBox(height: 10),
          const Text('An example observation', style: NatureType.sectionTitle),
          const SizedBox(height: 6),
          const Text(
            'Example: recorded sleep duration and self-reported stress changed during the '
            'same period.',
            style: NatureType.body,
          ),
          const SizedBox(height: 8),
          const Text(
            'This is illustrative, not based on your data, and it does not mean one caused '
            'the other.',
            style: NatureType.bodyMuted,
          ),
          NatureTextLink(label: 'View example details', onTap: onOpen),
        ],
      ),
    );
  }
}

// ---- Support ------------------------------------------------------------------
class NatureSupportLine extends StatelessWidget {
  final VoidCallback onTap;
  const NatureSupportLine({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, thickness: 1, color: NatureColors.divider),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: ExcludeSemantics(
                child: Icon(Icons.favorite_border_rounded, size: 18, color: NatureColors.coralInk),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: NatureTextLink(
                label: 'Need to talk to someone now? Support contacts are in Profile.',
                onTap: onTap,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
