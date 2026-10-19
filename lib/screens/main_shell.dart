// lib/screens/main_shell.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../theme/app_colors.dart';
import 'browse_screen.dart';
import 'my_requests_screen.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';
import '../utils/responsive_layout.dart';

/// Hosts the bottom navigation bar and switches between the four main
/// dashboard tabs. Used by both Student and Faculty roles — the dashboard
/// is identical for both, per the system spec.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const int _profileTabIndex = 3;

  void _goToTab(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    // Built dynamically (not const) so ProfileScreen can be given a callback
    // to jump back to the Notification tab via its back arrow.
    final screens = [
      BrowseScreen(onProfileTap: () => _goToTab(_profileTabIndex)),
      MyRequestsScreen(onProfileTap: () => _goToTab(_profileTabIndex)),
      NotificationScreen(onProfileTap: () => _goToTab(_profileTabIndex)),
      ProfileScreen(onBack: () => _goToTab(2)), // 2 = Notification tab
    ];

    final isOnProfileTab = _currentIndex == _profileTabIndex;
    final unreadCount = context.watch<NotificationProvider>().unreadCount;

    final useNavigationRail =
        MediaQuery.sizeOf(context).width >= ResponsiveAppFrame.wideBreakpoint;

    return Scaffold(
      body: useNavigationRail
          ? Row(
              children: [
                SafeArea(
                  child: NavigationRail(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: _goToTab,
                    labelType: NavigationRailLabelType.all,
                    selectedIconTheme: const IconThemeData(
                      color: AppColors.primaryLight,
                    ),
                    unselectedIconTheme: const IconThemeData(
                      color: Colors.grey,
                    ),
                    selectedLabelTextStyle: const TextStyle(
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                    destinations: [
                      NavigationRailDestination(
                        icon: Icon(Icons.home_outlined),
                        label: Text('Home'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.bookmark_outline),
                        label: Text('Request'),
                      ),
                      NavigationRailDestination(
                        icon: _NotificationIcon(unreadCount),
                        label: Text('Notification'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.person_outline),
                        label: Text('Profile'),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: IndexedStack(index: _currentIndex, children: screens),
                ),
              ],
            )
          : IndexedStack(index: _currentIndex, children: screens),
      // Compact screens use bottom navigation; the profile retains its back
      // arrow, while wide screens use the persistent navigation rail above.
      bottomNavigationBar: useNavigationRail || isOnProfileTab
          ? null
          : TooltipVisibility(
              visible: false,
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: _goToTab,
                type: BottomNavigationBarType.fixed,
                selectedItemColor: AppColors.primaryLight,
                unselectedItemColor: Colors.grey,
                showSelectedLabels: true,
                showUnselectedLabels: true,
                selectedLabelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(fontSize: 12),
                items: [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.bookmark_outline),
                    label: 'Request',
                  ),
                  BottomNavigationBarItem(
                    icon: _NotificationIcon(unreadCount),
                    label: 'Notification',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
    );
  }
}

class _NotificationIcon extends StatelessWidget {
  const _NotificationIcon(this.unreadCount);

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications_outlined),
        if (unreadCount > 0)
          Positioned(
            top: -4,
            right: -7,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                unreadCount > 9 ? '9+' : '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
