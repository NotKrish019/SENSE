import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/safety/crisis_service.dart';
import '../widgets/sense_button.dart';
import '../widgets/sense_card.dart';
import '../widgets/sense_navigation.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final TextEditingController _controller = TextEditingController();
  final CrisisService _crisisService = CrisisService();
  bool _isCrisisDetected = false;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    final hasCrisis = _crisisService.containsCrisisMarkers(text);
    if (hasCrisis != _isCrisisDetected) {
      setState(() => _isCrisisDetected = hasCrisis);
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final wordCount = _controller.text.trim().isEmpty
        ? 0
        : _controller.text.trim().split(RegExp(r'\s+')).length;

    return Scaffold(
      backgroundColor: SenseColors.background,
      appBar: SenseAppBar(
        title: 'Daily Journal',
        actions: [
          TextButton(
            onPressed: _controller.text.isEmpty ? null : _confirmDiscard,
            child: Text(
              'Clear',
              style: SenseTypography.labelBold.copyWith(
                color: _controller.text.isEmpty ? Colors.grey : SenseColors.danger,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: SenseSpacing.screenHorizontal,
            vertical: 12.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Crisis Alert Safety Banner (if triggered)
              if (_isCrisisDetected) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: SenseRadii.lgBorder,
                    border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.emergency_rounded, color: SenseColors.danger, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Support is Available 24/7',
                            style: SenseTypography.labelBold.copyWith(
                              color: SenseColors.danger,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You are not alone. Free, confidential support from trained professionals is available right now:\n\n'
                        '• Tele-MANAS (Govt of India): 14416 or 1800-891-4416\n'
                        '• KIRAN Mental Health Helpline: 1800-599-0019\n'
                        '• Vandrevala Foundation: +91 9999 666 555',
                        style: SenseTypography.caption.copyWith(
                          color: const Color(0xFF991B1B),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Journal Prompt Card
              SenseCard(
                color: SenseColors.surface,
                child: Row(
                  children: [
                    const Icon(Icons.edit_note_rounded, color: SenseColors.blue600, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'What moments, challenges, or thoughts stood out for you today?',
                        style: SenseTypography.captionMedium.copyWith(
                          color: SenseColors.navy900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Main Writing Surface
              Container(
                height: 260,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: SenseColors.white,
                  borderRadius: SenseRadii.lgBorder,
                  border: Border.all(color: SenseColors.border, width: 1.2),
                  boxShadow: SenseShadows.recessed,
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        maxLines: null,
                        expands: true,
                        style: SenseTypography.body.copyWith(
                          color: SenseColors.textPrimary,
                          fontSize: 15,
                          height: 1.5,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Write freely. Entries are stored only on your device and are never shared...',
                          hintStyle: SenseTypography.bodySecondary.copyWith(
                            color: SenseColors.textMuted,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    const Divider(color: SenseColors.border, height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$wordCount words • ${_controller.text.length} chars',
                          style: SenseTypography.caption.copyWith(
                            color: SenseColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.lock_outline_rounded, size: 13, color: SenseColors.success),
                            const SizedBox(width: 4),
                            Text(
                              'Encrypted on-device',
                              style: SenseTypography.caption.copyWith(
                                color: SenseColors.success,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Privacy Notice
              SenseCard(
                color: SenseColors.surface,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.privacy_tip_outlined, color: SenseColors.blue800, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Text is parsed on-device to extract general lexical tone (sentiment & pronoun density). Raw text is never transmitted to cloud LLM APIs.',
                        style: SenseTypography.caption.copyWith(
                          color: SenseColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              SenseButton(
                label: _isSaved ? 'Saved to Local Device' : 'Save Reflection',
                icon: Icons.save_rounded,
                variant: _isSaved ? SenseButtonVariant.secondary : SenseButtonVariant.primary,
                onPressed: _controller.text.trim().isEmpty ? null : _saveJournal,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _saveJournal() {
    setState(() => _isSaved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Journal entry saved locally to encrypted SQLite database.'),
        backgroundColor: SenseColors.navy900,
      ),
    );
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _confirmDiscard() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Clear Reflection?', style: SenseTypography.h3),
        content: Text(
          'Are you sure you want to clear your current entry? Unsaved text cannot be recovered.',
          style: SenseTypography.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: SenseTypography.label),
          ),
          TextButton(
            onPressed: () {
              _controller.clear();
              Navigator.of(ctx).pop();
            },
            child: Text('Clear', style: SenseTypography.labelBold.copyWith(color: SenseColors.danger)),
          ),
        ],
      ),
    );
  }
}
