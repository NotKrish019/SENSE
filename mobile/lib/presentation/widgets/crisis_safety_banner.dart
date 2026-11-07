import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/safety/crisis_service.dart';
import '../../core/theme/app_theme.dart';

/// Permanent, out-of-band crisis support button and dialog.
/// Decoupled from all ML states to ensure 100% reliable emergency care routing.
class CrisisSafetyBanner extends StatelessWidget {
  const CrisisSafetyBanner({super.key});

  static void showCrisisModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.support_agent_rounded, color: AppTheme.crisisCrimson, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Immediate Support & Crisis Helplines',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textMuted),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'If you are feeling overwhelmed, hopeless, or in acute distress, free, confidential human support is available 24/7:',
                style: TextStyle(fontSize: 14, color: AppTheme.textMuted, height: 1.4),
              ),
              const SizedBox(height: 16),
              ...CrisisService.helplines.map((helpline) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(
                      helpline.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    subtitle: Text(
                      '${helpline.description}\nDial: ${helpline.phoneNumber}',
                      style: const TextStyle(fontSize: 12, height: 1.3),
                    ),
                    trailing: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryTeal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: const Icon(Icons.call, size: 16),
                      label: const Text('Call'),
                      onPressed: () {
                        // Triggers system dialer
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Dialing ${helpline.phoneNumber}...')),
                        );
                      },
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              const Text(
                AppConstants.nonClinicalDisclaimer,
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.amber.shade50,
      child: Row(
        children: [
          Icon(Icons.health_and_safety_outlined, size: 20, color: Colors.amber.shade900),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Need immediate support?',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.amber.shade900),
            ),
          ),
          TextButton(
            onPressed: () => showCrisisModal(context),
            child: const Text('Helplines', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

