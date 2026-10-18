// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/request_provider.dart';
import '../models/user_model.dart';
import '../models/borrow_request_model.dart';
import '../utils/college_programs.dart';
import '../theme/app_colors.dart';
import '../utils/date_utils.dart';
import '../utils/status_style.dart';
import '../utils/simple_page_route.dart';
import '../widgets/status_badge.dart';
import '../widgets/role_badge.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  final VoidCallback? onBack;

  const ProfileScreen({super.key, this.onBack});

  String _initial(String fullName) {
    final name = fullName.trim();
    return name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
  }

  Future<void> _pickProfilePhoto(
    BuildContext context,
    AuthProvider auth,
  ) async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (image == null) return;
      if (!context.mounted) return;

      final croppedImage = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 75,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Adjust profile photo',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: AppColors.primaryLight,
            cropStyle: CropStyle.circle,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
          IOSUiSettings(
            title: 'Adjust profile photo',
            cropStyle: CropStyle.circle,
            aspectRatioLockEnabled: true,
            aspectRatioPickerButtonHidden: true,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
          WebUiSettings(
            context: context,
            initialAspectRatio: 1,
            cropBoxResizable: false,
          ),
        ],
      );
      if (croppedImage == null) return;

      final error = await auth.updateProfilePhoto(
        await croppedImage.readAsBytes(),
      );
      if (error != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save profile photo: $error')),
        );
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not select photo. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final user = context.watch<AuthProvider>().currentUser;
    final requestProvider = context.watch<RequestProvider>();
    final equipmentProvider = context.watch<EquipmentProvider>();

    if (user == null) return const SizedBox.shrink();

    final recent = requestProvider.recentBorrowings(user.id);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ----- Header (back arrow returns to the Notification tab) -----
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(12, statusBarHeight + 20, 12, 20),
            color: AppColors.primary,
            child: Row(
              children: [
                if (onBack != null)
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  )
                else
                  const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      simpleFadeRoute<void>((_) => const SettingsScreen()),
                    );
                  },
                  icon: const Icon(
                    Icons.settings_outlined,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // ----- Body -----
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Avatar + name + email + role badge
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: AppColors.primaryLight,
                            backgroundImage: user.profileImageBytes == null
                                ? null
                                : MemoryImage(user.profileImageBytes!),
                            child: user.profileImageBytes == null
                                ? Text(
                                    _initial(user.fullName),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _pickProfilePhoto(
                                context,
                                context.read<AuthProvider>(),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.camera_alt_outlined,
                                  size: 16,
                                  color: AppColors.primaryLight,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user.fullName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      RoleBadge(role: user.role),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Account information card
                _Card(
                  title: 'Account information',
                  child: Column(
                    children: [
                      _InfoRow(
                        label: 'Account role',
                        value: user.role.label,
                        helper:
                            'This is the role you selected when you signed in.',
                      ),
                      const Divider(height: 24),
                      if (user.role == UserRole.faculty) ...[
                        _InfoRow(
                          label: 'Department',
                          value: user.college?.trim().isNotEmpty == true
                              ? user.college!.trim()
                              : 'N/A',
                        ),
                        const Divider(height: 24),
                      ] else ...[
                        _InfoRow(
                          label: 'Year Level',
                          value: user.yearLevel ?? 'N/A',
                        ),
                        const Divider(height: 24),
                        _InfoRow(
                          label: 'College',
                          value: collegeDisplay(user.college),
                        ),
                        const Divider(height: 24),
                        _InfoRow(label: 'Block', value: user.block ?? 'N/A'),
                        const Divider(height: 24),
                      ],
                      _InfoRow(label: 'Gender', value: user.gender ?? 'N/A'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Recent Borrowings card
                _Card(
                  title: 'Recent Borrowings',
                  child: recent.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No borrowing history yet.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            for (int i = 0; i < recent.length; i++) ...[
                              _RecentBorrowingRow(
                                request: recent[i],
                                equipmentName:
                                    equipmentProvider
                                        .findById(recent[i].equipmentId)
                                        ?.name ??
                                    'Unknown equipment',
                              ),
                              if (i != recent.length - 1)
                                const Divider(height: 20),
                            ],
                          ],
                        ),
                ),
                const SizedBox(height: 20),

                // Borrowing summary card
                _Card(
                  title: 'Borrowing summary',
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _StatBox(
                              value:
                                  '${requestProvider.totalBorrowedCount(user.id)}',
                              label: 'Total borrowed',
                              color: AppColors.primaryLight,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatBox(
                              value: '${requestProvider.dueSoonCount(user.id)}',
                              label: 'Due soon',
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _StatBox(
                              value:
                                  '${requestProvider.returnedCount(user.id)}',
                              label: 'Returned',
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatBox(
                              value:
                                  '${requestProvider.currentBorrowedCount(user.id)}',
                              label: 'Current borrowed',
                              color: const Color(0xFFB4740E),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared white bordered card used for each section on the Profile screen.
class _Card extends StatelessWidget {
  final String title;
  final Widget child;

  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// A label/value row used inside the Account information card.
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final String? helper;

  const _InfoRow({required this.label, required this.value, this.helper});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        if (helper != null) ...[
          const SizedBox(height: 4),
          Text(
            helper!,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// A row inside the Recent Borrowings card.
class _RecentBorrowingRow extends StatelessWidget {
  final BorrowRequestModel request;
  final String equipmentName;

  const _RecentBorrowingRow({
    required this.request,
    required this.equipmentName,
  });

  @override
  Widget build(BuildContext context) {
    final isReturned = request.status == RequestStatus.returned;
    final displayedStatus = request.status == RequestStatus.approved
        ? RequestStatus.borrowed
        : request.status;

    final subtitle = isReturned
        ? 'Returned on ${formatFullDate(request.returnedDate ?? request.requestDate)}'
        : 'Borrowed on ${formatFullDate(request.checkedOutDate ?? request.requestDate)} - '
              'Due on ${formatFullDate(request.requestedReturnDate)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                equipmentName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            StatusBadge(style: requestStatusStyle(displayedStatus)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// A single stat box in the Borrowing summary grid.
class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatBox({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
