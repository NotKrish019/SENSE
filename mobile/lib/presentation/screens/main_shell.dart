import 'package:flutter/material.dart';

import '../../core/theme/nature_tokens.dart';
import '../nature/nature_navigation.dart';
import 'check_in_screen.dart';
import 'dashboard_screen.dart';
import 'insights_screen.dart';
import 'settings_screen.dart';

/// Tab indices used by [MainShell] and its navigation bars.
class MainTab {
  MainTab._();
  static const int home = 0;
  static const int insights = 1;
  static const int profile = 2;
}

/// The app's main area after onboarding/consent (Living Landscapes, Phase 1).
///
/// Navigation by width:
/// * phone and tablet (< 1024 px): the paper bottom bar with Home, Insights,
///   the central check-in disc and Profile;
/// * desktop (>= 1024 px): a top bar with the wordmark, text tabs and a
///   labelled "New check-in" button.
///
/// Tabs live in an [IndexedStack], so each is built once and keeps its state
/// (scroll position, selected period) while you switch; there is only ever one
/// Home instance. Hidden tabs are paused with [TickerMode], so the Home
/// landscape stops animating while Insights or Profile is shown. Detail
/// screens (check-in, journal, insight detail…) are pushed on top with the
/// normal Navigator, so Back returns to the tab. All three tabs are in the
/// Living Landscapes design (Insights and Profile since Phase 2) and lay
/// themselves out for phone, tablet and desktop.
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
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= NatureBreakpoints.desktop;

    Widget tab(int i, Widget child) => TickerMode(enabled: _index == i, child: child);

    final pages = IndexedStack(
      index: _index,
      children: [
        tab(
          MainTab.home,
          DashboardScreen(
            onOpenInsights: () => _select(MainTab.insights),
            onOpenProfile: () => _select(MainTab.profile),
          ),
        ),
        tab(MainTab.insights, const InsightsScreen(isTabRoot: true)),
        tab(MainTab.profile, const SettingsScreen(isTabRoot: true)),
      ],
    );

    return PopScope(
      // System/browser Back on Insights or Profile returns to Home instead of
      // leaving the app.
      canPop: _index == MainTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(MainTab.home);
      },
      // Keyboard focus order. Phone and tablet: all of the current page first,
      // then the bottom bar (Home, Insights, +, Profile), so focus never jumps
      // to the bar while a card is partly hidden behind it. Desktop: the
      // header first, then the page, as on the web.
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Scaffold(
          backgroundColor: NatureColors.background,
          body: desktop
              ? Column(
                  children: [
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(1),
                      child: FocusTraversalGroup(
                        child: Theme(
                          data: NatureTheme.light,
                          child: NatureTopBar(
                            overSky: _index == MainTab.home,
                            currentIndex: _index,
                            onTap: _select,
                            onCheckIn: _openCheckIn,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: FocusTraversalOrder(
                        order: const NumericFocusOrder(2),
                        child: FocusTraversalGroup(child: pages),
                      ),
                    ),
                  ],
                )
              : FocusTraversalOrder(
                  order: const NumericFocusOrder(1),
                  child: FocusTraversalGroup(child: pages),
                ),
          bottomNavigationBar: desktop
              ? null
              : FocusTraversalOrder(
                  order: const NumericFocusOrder(2),
                  child: FocusTraversalGroup(
                    child: Theme(
                      data: NatureTheme.light,
                      child: NatureBottomBar(
                        currentIndex: _index,
                        onTap: _select,
                        onCheckIn: _openCheckIn,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
