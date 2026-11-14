// lib/screens/my_requests_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/borrow_request_model.dart';
import '../providers/auth_provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/request_provider.dart';
import '../theme/app_colors.dart';
import '../utils/responsive_layout.dart';
import '../widgets/request_card.dart';
import '../widgets/app_notice.dart';

enum _RequestTab { active, pending, history }

class MyRequestsScreen extends StatefulWidget {
  final VoidCallback onBackTap;

  const MyRequestsScreen({super.key, required this.onBackTap});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  _RequestTab _selectedTab = _RequestTab.active;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final requestProvider = context.watch<RequestProvider>();
    final equipmentProvider = context.watch<EquipmentProvider>();
    final userId = auth.currentUser?.id ?? '';

    List<BorrowRequestModel> requests;
    switch (_selectedTab) {
      case _RequestTab.active:
        requests = requestProvider.activeRequests(userId);
        break;
      case _RequestTab.pending:
        requests = requestProvider.pendingRequests(userId);
        break;
      case _RequestTab.history:
        requests = requestProvider
            .historyRequests(userId)
            .where(
              (request) =>
                  equipmentProvider.findById(request.equipmentId) != null,
            )
            .toList();
        break;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: true,
        bottom: false,
        left: false,
        right: false,
        child: Column(
          children: [
            _LoansHeader(onBackTap: widget.onBackTap),
            Expanded(
              child: ResponsiveContent(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: [
                  const Text(
                    "Track everything you've borrowed, requested, or returned.",
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (requestProvider.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        requestProvider.errorMessage!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),

                  // ----- Tab selector -----
                  Row(
                    children: [
                      _TabChip(
                        label: 'Active',
                        selected: _selectedTab == _RequestTab.active,
                        onTap: () =>
                            setState(() => _selectedTab = _RequestTab.active),
                      ),
                      const SizedBox(width: 10),
                      _TabChip(
                        label: 'Pending',
                        selected: _selectedTab == _RequestTab.pending,
                        onTap: () =>
                            setState(() => _selectedTab = _RequestTab.pending),
                      ),
                      const SizedBox(width: 10),
                      _TabChip(
                        label: 'History',
                        selected: _selectedTab == _RequestTab.history,
                        onTap: () =>
                            setState(() => _selectedTab = _RequestTab.history),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ----- Request list -----
                  if (requests.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(
                        child: Text(
                          'Nothing here yet.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    ...requests.map((request) {
                      final equipment = equipmentProvider.findById(
                        request.equipmentId,
                      );

                      String? actionLabel;
                      VoidCallback? onAction;

                      if (_selectedTab == _RequestTab.pending) {
                        actionLabel = 'Cancel';
                        onAction = () => _runRequestAction(
                          () => requestProvider.cancelRequest(request.id),
                        );
                      } else if (_selectedTab == _RequestTab.active) {
                        if (request.status == RequestStatus.approved) {
                          actionLabel = 'Check Out';
                          onAction = () => _runRequestAction(
                            () => requestProvider.checkOut(request.id),
                          );
                        } else if (request.status == RequestStatus.borrowed) {
                          actionLabel =
                              request.returnVerificationStatus == 'rejected'
                              ? 'Request Return Again'
                              : 'Report Return';
                          onAction = () => _runRequestAction(
                            () => requestProvider.reportReturn(request.id),
                          );
                        }
                      }
                      // History tab: no action button (actionLabel stays null).

                      return RequestCard(
                        request: request,
                        equipment: equipment,
                        actionLabel: actionLabel,
                        onAction: onAction,
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runRequestAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      AppNotice.show(
        context,
        'Could not update this request: $error',
        type: AppNoticeType.error,
      );
    }
  }
}

class _LoansHeader extends StatelessWidget {
  const _LoansHeader({required this.onBackTap});

  final VoidCallback onBackTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('loans-header'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 20, 12),
      decoration: const BoxDecoration(color: AppColors.primary),
      child: Row(
        children: [
          IconButton(
            key: const Key('loans-back'),
            onPressed: onBackTap,
            tooltip: 'Back to Home',
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const Text(
            'Loans',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill-style selector chip used for the Active / Pending / History tabs.
class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primaryLight : AppColors.fieldBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
