// lib/screens/main_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/request_provider.dart';
import '../theme/app_colors.dart';
import 'browse_screen.dart';
import 'my_requests_screen.dart';
import 'message_screen.dart';
import 'notification_screen.dart';
import 'qr_scan_screen.dart';
import 'profile_screen.dart';
import '../utils/responsive_layout.dart';
import '../widgets/app_notice.dart';

/// Hosts the main dashboard tabs for Student and Faculty accounts.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  int _previousTabIndex = 0;
  DateTime? _lastBackPress;
  bool _hasOpenedMessages = false;

  static const int _homeTabIndex = 0;
  static const int _loansTabIndex = 1;
  static const int _messagesTabIndex = 2;
  static const int _profileTabIndex = 3;
  static const int _notificationsTabIndex = 4;

  void _goToTab(int index) {
    if (index == _messagesTabIndex) _hasOpenedMessages = true;
    setState(() {
      if (_currentIndex != _notificationsTabIndex) {
        _previousTabIndex = _currentIndex;
      }
      _currentIndex = index;
      _lastBackPress = null;
    });
  }

  void _openNotifications() => _goToTab(_notificationsTabIndex);

  void _openScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
  }

  void _handleBackPress() {
    if (_currentIndex == _messagesTabIndex) {
      _goToTab(
        _previousTabIndex == _notificationsTabIndex
            ? _homeTabIndex
            : _previousTabIndex,
      );
      return;
    }
    if (_currentIndex == _notificationsTabIndex) {
      _goToTab(_homeTabIndex);
      return;
    }
    if (_currentIndex != _homeTabIndex) {
      _goToTab(_homeTabIndex);
      return;
    }

    final now = DateTime.now();
    final pressedTwice =
        _lastBackPress != null &&
        now.difference(_lastBackPress!) < const Duration(seconds: 2);
    if (pressedTwice) {
      SystemNavigator.pop();
      return;
    }

    _lastBackPress = now;
    AppNotice.show(context, 'Tap again to exit');
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthProvider?>()?.currentUser?.id ?? '';
    final requestProvider = context.watch<RequestProvider?>();
    final unreadLoanUpdates =
        (context.watch<NotificationProvider?>()?.unreadCount ?? 0) +
        (requestProvider?.rejectedReturnCount(userId) ?? 0);
    final screens = [
      BrowseScreen(
        onProfileTap: () => _goToTab(_profileTabIndex),
        onNotificationTap: _openNotifications,
        onScannerTap: _openScanner,
      ),
      MyRequestsScreen(onBackTap: () => _goToTab(_homeTabIndex)),
      _hasOpenedMessages
          ? MessageScreen(
              onBackTap: () => _goToTab(
                _previousTabIndex == _notificationsTabIndex
                    ? _homeTabIndex
                    : _previousTabIndex,
              ),
            )
          : const SizedBox.shrink(),
      ProfileScreen(onBack: () => _goToTab(_homeTabIndex)),
      NotificationScreen(
        onBackTap: () => _goToTab(_homeTabIndex),
        isActive: _currentIndex == _notificationsTabIndex,
      ),
    ];

    final isOnProfileTab = _currentIndex == _profileTabIndex;
    final isOnNotificationsTab = _currentIndex == _notificationsTabIndex;
    final isOnMessagesTab = _currentIndex == _messagesTabIndex;
    final isOnLoansTab = _currentIndex == _loansTabIndex;

    final useNavigationRail =
        MediaQuery.sizeOf(context).width >= ResponsiveAppFrame.wideBreakpoint;
    final showNavigationRail =
        useNavigationRail && !isOnMessagesTab && !isOnLoansTab;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBackPress();
      },
      child: Scaffold(
        body: showNavigationRail
            ? Row(
                children: [
                  SafeArea(
                    child: NavigationRail(
                      selectedIndex: _currentIndex <= _profileTabIndex
                          ? _currentIndex
                          : _homeTabIndex,
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
                        const NavigationRailDestination(
                          icon: Icon(Icons.home_outlined),
                          label: Text('Home'),
                        ),
                        const NavigationRailDestination(
                          icon: Icon(Icons.bookmark_outline),
                          label: Text('Loans'),
                        ),
                        const NavigationRailDestination(
                          icon: Icon(Icons.forum_outlined),
                          label: Text('Messages'),
                        ),
                        const NavigationRailDestination(
                          icon: Icon(Icons.person_outline),
                          label: Text('Profile'),
                        ),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: IndexedStack(
                      index: _currentIndex,
                      children: screens,
                    ),
                  ),
                ],
              )
            : IndexedStack(index: _currentIndex, children: screens),
        // Notifications are opened from the dashboard header instead of the
        // bottom navigation.
        floatingActionButton:
            useNavigationRail ||
                isOnMessagesTab ||
                isOnLoansTab ||
                isOnProfileTab ||
                isOnNotificationsTab
            ? null
            : FloatingActionButton(
                key: const Key('main-scan-button'),
                onPressed: _openScanner,
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryLight,
                elevation: 3,
                shape: const CircleBorder(
                  side: BorderSide(color: AppColors.primaryLight, width: 1.5),
                ),
                child: const Icon(Icons.qr_code_scanner_rounded, size: 26),
              ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar:
            useNavigationRail ||
                isOnMessagesTab ||
                isOnLoansTab ||
                isOnProfileTab ||
                isOnNotificationsTab
            ? null
            : BottomAppBar(
                shape: const CircularNotchedRectangle(),
                notchMargin: 7,
                color: Colors.white,
                elevation: 8,
                child: SizedBox(
                  height: 62,
                  child: Row(
                    children: [
                      Expanded(
                        child: _NavigationButton(
                          label: 'Home',
                          icon: Icons.home_outlined,
                          selectedIcon: Icons.home,
                          selected: _currentIndex == _homeTabIndex,
                          onTap: () => _goToTab(_homeTabIndex),
                        ),
                      ),
                      Expanded(
                        child: _NavigationButton(
                          label: 'Loans',
                          icon: Icons.bookmark_border,
                          selectedIcon: Icons.bookmark,
                          selected: _currentIndex == _loansTabIndex,
                          onTap: () => _goToTab(_loansTabIndex),
                          badgeCount: unreadLoanUpdates,
                        ),
                      ),
                      SizedBox(
                        width: 56,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              'Scan',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _NavigationButton(
                          label: 'Messages',
                          icon: Icons.forum_outlined,
                          selectedIcon: Icons.forum,
                          selected: _currentIndex == _messagesTabIndex,
                          onTap: () => _goToTab(_messagesTabIndex),
                        ),
                      ),
                      Expanded(
                        child: _NavigationButton(
                          label: 'Profile',
                          icon: Icons.person_outline,
                          selectedIcon: Icons.person,
                          selected: _currentIndex == _profileTabIndex,
                          onTap: () => _goToTab(_profileTabIndex),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryLight : Colors.grey;
    return Semantics(
      button: true,
      selected: selected,
      label: badgeCount > 0 ? '$label, $badgeCount new updates' : label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(selected ? selectedIcon : icon, color: color, size: 22),
                if (badgeCount > 0)
                  Positioned(
                    key: const Key('loans-nav-badge'),
                    top: -6,
                    right: -10,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badgeCount > 9 ? '9+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
