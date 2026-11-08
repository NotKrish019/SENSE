import 'package:flutter/material.dart';

import '../../core/safety/crisis_service.dart';
import '../../core/theme/nature_tokens.dart';
import '../nature/input_bands.dart';
import '../nature/nature_inputs.dart';
import '../nature/nature_widgets.dart';

/// Production Journal (Living Landscapes, Phase 3).
///
/// A paper writing page under a morning orchard. Behaviour is unchanged:
/// * free text in one multi-line field (accessible name "Journal reflection"),
///   with a live word and character count;
/// * the text is checked on this device against a short list of crisis
///   phrases ([CrisisService]); when one matches, 24/7 support contacts are
///   shown above the page;
/// * "Save Reflection" is enabled once there is text. Persistence is not
///   connected: it shows the honest "not saved" message, keeps the text on
///   screen, and the button then reads "Not saved (prototype only)";
/// * "Clear" (enabled once there is text) asks for confirmation first.
/// No sentiment or AI analysis runs, nothing is sent anywhere, nothing is saved.
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ScrollController _scroll = ScrollController();
  bool _isCrisisDetected = false;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasCrisis = CrisisService.containsCrisisMarkers(_controller.text);
    setState(() => _isCrisisDetected = hasCrisis);
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text;
    final wordCount = text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;
    final hasText = text.trim().isNotEmpty;

    return Theme(
      data: NatureTheme.light,
      child: Scaffold(
        backgroundColor: NatureColors.background,
        body: NatureJournalPage(
          controller: _scroll,
          onBack: () => Navigator.of(context).maybePop(),
          backLabel: 'Back',
          maxSheetWidth: 760,
          band: (desktop) => OrchardBand(tornBottom: desktop),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Journal', style: NatureType.eyebrow),
              const SizedBox(height: 8),
              const NatureHeading('Daily journal'),
              const SizedBox(height: 14),
              if (_isCrisisDetected) ...[
                const _SupportNotice(),
                const SizedBox(height: 20),
              ],
              const _Prompt('What moments, challenges, or thoughts stood out for you today?'),
              const SizedBox(height: 14),
              _WritingPage(
                controller: _controller,
                focusNode: _focus,
                wordCount: wordCount,
                charCount: text.length,
              ),
              const SizedBox(height: 22),
              const _PrivacyNote(),
              const SizedBox(height: 26),
              LayoutBuilder(builder: (context, c) {
                final save = NaturePrintedAction(
                  label: _isSaved ? 'Not saved (prototype only)' : 'Save Reflection',
                  icon: null,
                  onTap: hasText ? _saveJournal : null,
                );
                final clear = NatureQuietButton(
                  label: 'Clear',
                  caution: true,
                  onTap: text.isEmpty ? null : _confirmDiscard,
                );
                // Side by side when there is room; stacked on narrow screens
                // or with large text, Save first.
                final roomy = c.maxWidth >= 440 && MediaQuery.textScalerOf(context).scale(1) <= 1.3;
                if (roomy) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: save),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: clear),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [save, const SizedBox(height: 10), clear],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _saveJournal() {
    // Persistence is not connected yet: say so, and keep the screen open so
    // the text is not discarded unexpectedly.
    setState(() => _isSaved = true);
    showNatureNotSavedMessage(context, 'journal entry');
  }

  Future<void> _confirmDiscard() async {
    final clear = await showNatureConfirmDialog(
      context,
      title: 'Clear reflection?',
      message: 'Are you sure you want to clear your current entry? Unsaved text cannot be recovered.',
      confirmLabel: 'Clear',
      destructive: true,
    );
    if (clear) _controller.clear();
  }
}

/// The writing prompt, set like a line pencilled in the margin.
class _Prompt extends StatelessWidget {
  final String text;
  const _Prompt(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: ExcludeSemantics(child: Icon(Icons.edit_note_rounded, color: NatureColors.ochreInk, size: 24)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Prompt', style: NatureType.eyebrow.copyWith(color: NatureColors.ochreInk)),
              const SizedBox(height: 2),
              Text(text, style: NatureType.statusTitle.copyWith(fontSize: 18)),
            ],
          ),
        ),
      ],
    );
  }
}

/// The writing surface: a brighter leaf of ruled paper with a coral margin
/// line. The rules follow the text's line height at every text size.
class _WritingPage extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final int wordCount;
  final int charCount;
  const _WritingPage({
    required this.controller,
    required this.focusNode,
    required this.wordCount,
    required this.charCount,
  });

  static const double _fontSize = 16;
  static const double _lineHeight = 1.7;
  static const double _margin = 30;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final pitch = scaler.scale(_fontSize) * _lineHeight;
    final focused = focusNode.hasFocus;
    const style = TextStyle(
      fontFamily: NatureType.family,
      fontSize: _fontSize,
      height: _lineHeight,
      color: NatureColors.ink,
    );
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF5),
        borderRadius: NatureRadii.smBorder,
        border: Border.all(
          color: focused ? NatureColors.forest : NatureColors.borderStrong,
          width: focused ? 2 : 1.2,
        ),
      ),
      child: Column(
        children: [
          CustomPaint(
            painter: _RulePainter(pitch: pitch, top: 16, margin: _margin),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(_margin + 12, 16, 16, 12),
              // Minimum (not fixed) height: the page grows with the entry and
              // with larger text; the screen scrolls instead.
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: pitch * 8),
                // Persistent accessible name: the hint disappears once text is
                // typed, so it cannot be the field's only label.
                child: Semantics(
                  label: 'Journal reflection',
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    minLines: 8,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    style: style,
                    strutStyle: const StrutStyle(
                      fontFamily: NatureType.family,
                      fontSize: _fontSize,
                      height: _lineHeight,
                      forceStrutHeight: true,
                    ),
                    cursorColor: NatureColors.forest,
                    decoration: InputDecoration(
                      hintText: 'Write freely. In this prototype, your text stays on this screen only and is not saved.',
                      hintStyle: style.copyWith(color: NatureColors.inkMuted),
                      hintMaxLines: 4,
                      border: InputBorder.none,
                      isCollapsed: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(_margin + 12, 10, 16, 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: NatureColors.divider)),
            ),
            // Counter and "not saved" notice wrap onto two lines if needed;
            // the honesty notice is never cut off.
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text('$wordCount words · $charCount chars',
                    style: NatureType.bodyMuted.copyWith(fontSize: 13)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ExcludeSemantics(
                        child: Icon(Icons.info_outline_rounded, size: 15, color: NatureColors.inkMuted)),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text('Not saved (prototype)',
                          style: NatureType.bodyMuted.copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RulePainter extends CustomPainter {
  final double pitch;
  final double top;
  final double margin;
  const _RulePainter({required this.pitch, required this.top, required this.margin});

  @override
  void paint(Canvas canvas, Size size) {
    final rule = Paint()
      ..color = NatureColors.skyTeal.withValues(alpha: 0.28)
      ..strokeWidth = 1;
    // Rules sit just under each line's text.
    for (var y = top + pitch * 0.86; y < size.height - 4; y += pitch) {
      canvas.drawLine(Offset(10, y), Offset(size.width - 10, y), rule);
    }
    canvas.drawLine(
        Offset(margin, 0),
        Offset(margin, size.height),
        Paint()
          ..color = NatureColors.dustyCoral.withValues(alpha: 0.7)
          ..strokeWidth = 1.2);
  }

  @override
  bool shouldRepaint(_RulePainter old) => old.pitch != pitch || old.top != top || old.margin != margin;
}

/// Shown when the on-device check finds a crisis phrase. Announced when it
/// appears (live region).
class _SupportNotice extends StatelessWidget {
  const _SupportNotice();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: const BoxDecoration(
          color: Color(0xFFF7E9E4),
          border: Border(left: BorderSide(color: NatureColors.dustyCoral, width: 4)),
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(NatureRadii.sm),
            bottomRight: Radius.circular(NatureRadii.sm),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const ExcludeSemantics(child: Icon(Icons.support_rounded, color: NatureColors.coralInk, size: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Support is Available 24/7',
                      style: NatureType.sectionTitle.copyWith(color: NatureColors.coralInk, fontSize: 17)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'You are not alone. Free, confidential support from trained professionals is available right now:',
              style: NatureType.body,
            ),
            const SizedBox(height: 8),
            for (final (name, number) in const [
              ('Tele-MANAS (Govt of India)', '14416 or 1800-891-4416'),
              ('KIRAN Mental Health Helpline', '1800-599-0019'),
              ('Vandrevala Foundation', '+91 9999 666 555'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: '$name: ', style: NatureType.body),
                  TextSpan(text: number, style: NatureType.label.copyWith(fontWeight: FontWeight.w600)),
                ])),
              ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 16),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: NatureColors.skyTeal, width: 3)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What happens to your text', style: NatureType.eyebrow),
          SizedBox(height: 4),
          Text(
            'It is checked on this device against a short list of crisis phrases so support '
            'contacts can be shown. No sentiment or AI analysis runs yet, nothing is sent '
            'anywhere, and the entry is not saved.',
            style: NatureType.bodyMuted,
          ),
        ],
      ),
    );
  }
}
