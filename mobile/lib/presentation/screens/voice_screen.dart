import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/sense_button.dart';
import '../widgets/sense_card.dart';
import '../widgets/sense_navigation.dart';

class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> {
  bool _isRecording = false;
  int _recordingSeconds = 0;
  bool _hasSampleRecorded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SenseColors.background,
      appBar: const SenseAppBar(title: 'Voice Check-in (Optional)'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: SenseSpacing.screenHorizontal,
            vertical: 16.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Research Rationale & Permission Card
              SenseCard(
                color: SenseColors.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.mic_none_rounded, color: SenseColors.blue600, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          'Acoustic Prosody Analysis',
                          style: SenseTypography.labelBold.copyWith(
                            color: SenseColors.navy900,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Voice analysis investigates whether subtle variations in pitch variability, speaking rate, and pause duration correlate with stress shifts. Voice recording is 100% voluntary.',
                      style: SenseTypography.caption.copyWith(
                        color: SenseColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Strict Privacy & Boundary Notice
              SenseCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_outlined, color: SenseColors.success, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Strict Privacy Guarantees',
                            style: SenseTypography.labelBold.copyWith(
                              color: SenseColors.success,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '• NO background listening or ambient audio recording.\n'
                            '• Tap-to-record only with your active consent.\n'
                            '• Raw audio is converted on-device to irreversible mathematical features and deleted.',
                            style: SenseTypography.caption.copyWith(
                              color: SenseColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Recording Surface
              Center(
                child: Column(
                  children: [
                    Text(
                      _isRecording
                          ? 'Recording... 00:0$_recordingSeconds'
                          : _hasSampleRecorded
                              ? 'Sample Ready (20s)'
                              : 'Tap microphone to begin prompt',
                      style: SenseTypography.labelBold.copyWith(
                        color: _isRecording ? SenseColors.danger : SenseColors.navy900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Mic Action Button
                    GestureDetector(
                      onTap: _toggleRecording,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: _isRecording
                              ? const LinearGradient(colors: [SenseColors.danger, Color(0xFF881337)])
                              : SenseColors.primaryActionGradient,
                          boxShadow: [
                            BoxShadow(
                              color: _isRecording
                                  ? const Color(0x66B42332)
                                  : const Color(0x40059BE0),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                          color: SenseColors.white,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Simulated Waveform Bars
                    if (_isRecording)
                      SizedBox(
                        height: 40,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(18, (i) {
                            final h = (10 + (i % 5) * 6).toDouble();
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              width: 3.5,
                              height: h,
                              decoration: BoxDecoration(
                                color: SenseColors.cyan500,
                                borderRadius: SenseRadii.pillBorder,
                              ),
                            );
                          }),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Action Buttons
              if (_hasSampleRecorded) ...[
                SenseButton(
                  label: 'Save Acoustic Sample (On-Device)',
                  icon: Icons.check_rounded,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Acoustic parameters extracted and stored locally.'),
                        backgroundColor: SenseColors.navy900,
                      ),
                    );
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(height: 12),
                SenseButton(
                  label: 'Discard Sample',
                  variant: SenseButtonVariant.secondary,
                  onPressed: () => setState(() {
                    _hasSampleRecorded = false;
                    _recordingSeconds = 0;
                  }),
                ),
              ] else ...[
                SenseCard(
                  color: SenseColors.surface,
                  child: Text(
                    'Suggested Prompt: "Describe three neutral tasks you accomplished today and how rested you feel."',
                    style: SenseTypography.caption.copyWith(
                      color: SenseColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleRecording() {
    if (_isRecording) {
      setState(() {
        _isRecording = false;
        _hasSampleRecorded = true;
      });
    } else {
      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
        _hasSampleRecorded = false;
      });
      // Simulate 5-second countdown in prototype
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && _isRecording) setState(() => _recordingSeconds = 1);
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _isRecording) setState(() => _recordingSeconds = 2);
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isRecording) {
          setState(() {
            _recordingSeconds = 3;
            _isRecording = false;
            _hasSampleRecorded = true;
          });
        }
      });
    }
  }
}

