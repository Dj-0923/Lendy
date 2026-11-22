// lib/widgets/dashboard_header.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../theme/app_colors.dart';

/// Dashboard header with account actions and an optional image backdrop.
class DashboardHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onProfileTap;
  final VoidCallback? onNotificationTap;
  final Widget? bottomContent;
  final String? backgroundImageAsset;
  final bool showUserDetails;
  final bool roundedBottom;
  final bool tall;

  const DashboardHeader({
    super.key,
    required this.title,
    this.onProfileTap,
    this.onNotificationTap,
    this.bottomContent,
    this.backgroundImageAsset,
    this.showUserDetails = true,
    this.roundedBottom = true,
    this.tall = false,
  });

  String _initial(String fullName) {
    final name = fullName.trim();
    return name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final unreadCount =
        context.watch<NotificationProvider?>()?.unseenLoanUpdateCount ?? 0;
    final imageBytes = user?.profileImageBytes;
    final background = backgroundImageAsset;
    final pinBrandingToTop = background != null && bottomContent != null;
    final compactBranding =
        pinBrandingToTop && MediaQuery.sizeOf(context).width < 520;

    return Container(
      key: const Key('dashboard-header'),
      width: double.infinity,
      margin: EdgeInsets.zero,
      padding: EdgeInsets.fromLTRB(
        16,
        compactBranding
            ? 8
            : tall && bottomContent == null
            ? 24
            : 16,
        16,
        bottomContent != null
            ? compactBranding
                  ? 4
                  : 8
            : tall
            ? 30
            : 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary,
        image: background == null
            ? null
            : DecorationImage(
                image: AssetImage(background),
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                filterQuality: FilterQuality.high,
              ),
        borderRadius: roundedBottom
            ? const BorderRadius.only(
                bottomLeft: Radius.circular(48),
                bottomRight: Radius.circular(48),
              )
            : null,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: pinBrandingToTop
                ? MainAxisSize.max
                : MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              key: const Key('dashboard-header-logo'),
                              radius: 17,
                              backgroundColor: Colors.white,
                              backgroundImage: const AssetImage(
                                'assets/images/Lendy.png',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (showUserDetails) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  user?.fullName ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Icon(
                                  Icons.circle,
                                  color: Color(0xFF31D5A1),
                                  size: 5,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight.withValues(
                                    alpha: 0.55,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  user?.role.name.toUpperCase() ?? '',
                                  maxLines: 1,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (onNotificationTap != null)
                    IconButton(
                      key: const Key('dashboard-notifications'),
                      onPressed: onNotificationTap,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 48,
                        height: 48,
                      ),
                      tooltip: 'Notifications',
                      icon: Container(
                        key: const Key('dashboard-notification-circle'),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        alignment: Alignment.center,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(
                              Icons.notifications_outlined,
                              color: Colors.white,
                              size: 25,
                            ),
                            if (unreadCount > 0)
                              Positioned(
                                top: -4,
                                right: -7,
                                child: Container(
                                  key: const Key(
                                    'dashboard-notification-badge',
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
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
                        ),
                      ),
                    ),
                  IconButton(
                    key: const Key('dashboard-profile-avatar'),
                    onPressed: onProfileTap,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 48,
                      height: 48,
                    ),
                    icon: Container(
                      key: const Key('dashboard-profile-outline'),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF9FE3A5),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white24,
                        backgroundImage: imageBytes == null
                            ? null
                            : MemoryImage(imageBytes),
                        child: imageBytes == null
                            ? Text(
                                _initial(user?.fullName ?? ''),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
              if (pinBrandingToTop) ...[
                const SizedBox(height: 8),
                const Spacer(),
                bottomContent!,
                const Spacer(),
              ] else if (bottomContent != null) ...[
                const SizedBox(height: 8),
                bottomContent!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
