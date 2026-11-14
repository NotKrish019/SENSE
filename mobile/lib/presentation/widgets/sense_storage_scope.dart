import 'package:flutter/material.dart';

import '../../data/local/sense_storage.dart';

/// Makes the app's [SenseStorage] owner available below it (Milestone K1).
///
/// The owner is created once by the app (not a global) and passed down here.
/// Screens never open a database themselves; later milestones read the
/// ready store from this scope.
class SenseStorageScope extends InheritedNotifier<SenseStorage> {
  const SenseStorageScope({super.key, required SenseStorage storage, required super.child})
      : super(notifier: storage);

  /// The owner, rebuilding [context] when its state changes; null if absent.
  static SenseStorage? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SenseStorageScope>()?.notifier;
}

/// The narrow workload operations for the Workload screen (Milestone K2), or
/// null when there is no storage owner above [context]. Screens receive only
/// these typed load and save operations, never the database, the store or a
/// repository. Does not register a dependency: the returned object notifies
/// its own listeners when storage changes.
WorkloadAccess? workloadAccessOf(BuildContext context) =>
    context.getInheritedWidgetOfExactType<SenseStorageScope>()?.notifier?.workload;

/// A persistent, clearly visible strip above every route while development
/// storage is enabled ([kDevelopmentStorageLabel]). Nothing is shown otherwise.
class DevelopmentStorageBanner extends StatelessWidget {
  final bool enabled;
  final Widget child;
  const DevelopmentStorageBanner({super.key, required this.enabled, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final media = MediaQuery.of(context);
    return Column(
      children: [
        Material(
          color: const Color(0xFF7A1F1F),
          child: SafeArea(
            bottom: false,
            child: Semantics(
              container: true,
              liveRegion: true,
              label: kDevelopmentStorageLabel,
              child: ExcludeSemantics(
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 32),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  alignment: Alignment.center,
                  child: const Text(
                    kDevelopmentStorageLabel,
                    key: Key('development-storage-banner'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: MediaQuery(
            data: media.removePadding(removeTop: true),
            child: child,
          ),
        ),
      ],
    );
  }
}

/// The narrow check-in operations for the Check-in screen (Milestone K3), or
/// null when there is no storage owner above [context]. Same rules as
/// [workloadAccessOf]: typed load and save only, no dependency registered.
CheckInAccess? checkInAccessOf(BuildContext context) =>
    context.getInheritedWidgetOfExactType<SenseStorageScope>()?.notifier?.checkIn;

/// The narrow sleep operations for the Sleep screen (Milestone K4), or null
/// when there is no storage owner above [context]. Same rules as
/// [workloadAccessOf]: typed reads and save only, no dependency registered.
SleepAccess? sleepAccessOf(BuildContext context) =>
    context.getInheritedWidgetOfExactType<SenseStorageScope>()?.notifier?.sleep;

/// The narrow, read-only observation surface for the Insights screen, or null
/// when there is no storage owner above [context]. Same rules as
/// [workloadAccessOf]: typed reads only, no dependency registered.
InsightsAccess? insightsAccessOf(BuildContext context) =>
    context.getInheritedWidgetOfExactType<SenseStorageScope>()?.notifier?.insights;
