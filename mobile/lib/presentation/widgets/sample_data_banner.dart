import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/prototype_copy.dart';

/// Screen-level notice shown wherever a screen displays hard-coded
/// illustrative values. Pair with `SenseProvenanceBadge.sampleData()` on
/// individual cards. Never show it over information the user entered.
class SenseSampleDataBanner extends StatelessWidget {
  final String title;
  final String message;

  const SenseSampleDataBanner({
    super.key,
    this.title = PrototypeCopy.sampleDataTitle,
    this.message = PrototypeCopy.sampleDataDescription,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$title. $message',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(SenseSpacing.md),
        decoration: BoxDecoration(
          color: SenseColors.white,
          borderRadius: SenseRadii.mdBorder,
          border: Border.all(color: SenseColors.cyan500, width: 1.2),
          boxShadow: SenseShadows.card,
        ),
        child: ExcludeSemantics(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.science_outlined, color: SenseColors.blue800, size: 20),
              const SizedBox(width: SenseSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SenseTypography.labelBold.copyWith(color: SenseColors.navy900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
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
      ),
    );
  }
}

/// Honest feedback for "save" actions while persistence is not connected.
void showPrototypeNotSavedMessage(BuildContext context, String what) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(PrototypeCopy.notSaved(what)),
      backgroundColor: SenseColors.navy900,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
    ),
  );
}
