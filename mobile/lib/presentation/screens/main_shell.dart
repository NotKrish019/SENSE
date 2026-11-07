import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/sense_navigation.dart';
import 'check_in_screen.dart';
import 'dashboard_screen.dart';
import 'insights_screen.dart';
import 'settings_screen.dart';

/// Tab indices used by [MainShell] and [SenseBottomNavBar].
class MainTab {
  MainTab._();
  static const int home = 0;
  static const int insights = 1;
  static const int profile = 2;
}

/// The app's main area after onboarding/consent: one bottom navigation bar
/// shared by Home, Insights and Profile.
///
/// Tabs live in an [IndexedStack], so each is built once and keeps its state
/// (scroll position, selected period) while you switch; there is only ever one
/// dashboard instance. Detail screens (check-in, journal, insight detail…) are
/// pushed on top with the normal Navigator, so Back returns to the tab.
class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = MainTab.home});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index = widget.initialIndex;

  void _select(int index) {
    if (index == _index) return; // re-selecting the current tab: no-op
    setState(() => _index = index);
  }

  void _openCheckIn() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CheckInScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // System/browser Back on Insights or Profile returns to Home instead of
      // leaving the app.
      canPop: _index == MainTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(MainTab.home);
      },
      // Keyboard focus order: all of the current page first, then the bottom
      // bar (Home, Insights, +, Profile). Without explicit groups, Flutter's
      // position-based ordering jumped to the bar while a card was partly
      // hidden behind it, then back up to the card.
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Scaffold(
        backgroundColor: SenseColors.background,
        body: FocusTraversalOrder(
          order: const NumericFocusOrder(1),
          child: FocusTraversalGroup(
            child: IndexedStack(
          index: _index,
          children: [
            DashboardScreen(
              onOpenInsights: () => _select(MainTab.insights),
              onOpenProfile: () => _select(MainTab.profile),
            ),
            const InsightsScreen(isTabRoot: true),
            const SettingsScreen(isTabRoot: true),
          ],
            ),
          ),
        ),
        bottomNavigationBar: FocusTraversalOrder(
          order: const NumericFocusOrder(2),
          child: FocusTraversalGroup(
            child: SenseBottomNavBar(
              currentIndex: _index,
              onTap: _select,
              onAddTap: _openCheckIn,
            ),
          ),
        ),
        ),
      ),
    );
  }
}
