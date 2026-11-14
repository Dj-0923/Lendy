// lib/screens/browse_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/equipment_model.dart';
import '../providers/equipment_provider.dart';
import '../providers/request_provider.dart';
import '../theme/app_colors.dart';
import '../utils/responsive_layout.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/equipment_card.dart';
import 'borrower_assistant_screen.dart';
import 'request_form_screen.dart';

class BrowseScreen extends StatefulWidget {
  final VoidCallback? onProfileTap;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onScannerTap;

  const BrowseScreen({
    super.key,
    this.onProfileTap,
    this.onNotificationTap,
    this.onScannerTap,
  });

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildSearchField(EquipmentProvider equipmentProvider) {
    return TextField(
      key: const Key('browse-search-field'),
      controller: _searchController,
      onChanged: equipmentProvider.setSearchQuery,
      decoration: InputDecoration(
        hintText: 'Search by name, room or asset code...',
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 13.5),
        prefixIcon: const Icon(Icons.search, size: 20),
        prefixIconConstraints: const BoxConstraints.tightFor(
          width: 40,
          height: 40,
        ),
        suffixIcon: widget.onScannerTap == null
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const Key('browse-search-scanner'),
                    tooltip: 'Scan item code',
                    onPressed: widget.onScannerTap,
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                    icon: const Icon(Icons.qr_code_scanner, size: 19),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: VerticalDivider(width: 1),
                  ),
                ],
              ),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        constraints: const BoxConstraints(minHeight: 44),
        suffixIconConstraints: const BoxConstraints.tightFor(
          width: 40,
          height: 40,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.fieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.fieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primaryLight),
        ),
      ),
    );
  }

  Widget _buildFilterRow(EquipmentProvider equipmentProvider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterDropdown<String?>(
            width: 150,
            value: equipmentProvider.selectedCategory,
            options: [null, ...equipmentProvider.categories],
            labelOf: (category) => category ?? 'All Categories',
            onChanged: equipmentProvider.setCategory,
            highlighted: true,
          ),
          const SizedBox(width: 10),
          _FilterDropdown<EquipmentStatus?>(
            width: 155,
            value: equipmentProvider.selectedAvailability,
            options: [null, ...EquipmentStatus.values],
            labelOf: (status) => status?.label ?? 'Any Availability',
            onChanged: equipmentProvider.setAvailability,
          ),
          for (final category in equipmentProvider.categories) ...[
            const SizedBox(width: 10),
            _CategoryCountChip(
              label: category,
              count: equipmentProvider.countForCategory(category),
              selected: equipmentProvider.selectedCategory == category,
              onTap: () => equipmentProvider.setCategory(
                equipmentProvider.selectedCategory == category
                    ? null
                    : category,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final equipmentProvider = context.watch<EquipmentProvider>();
    final requestProvider = context.watch<RequestProvider?>();
    final userId = context.watch<AuthProvider>().currentUser?.id;
    final equipmentList = equipmentProvider.filteredEquipment;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: AppColors.primary,
      ),
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: Column(
          children: [
            ColoredBox(
              key: const Key('browse-status-bar-background'),
              color: AppColors.primary,
              child: SizedBox(width: double.infinity, height: statusBarHeight),
            ),
            Expanded(
              child: ColoredBox(
                color: AppColors.background,
                child: CustomScrollView(
                  key: const Key('browse-scroll-view'),
                  slivers: [
                    SliverToBoxAdapter(
                      child: DashboardHeader(
                        title: 'Lendy',
                        onProfileTap: widget.onProfileTap,
                        onNotificationTap: widget.onNotificationTap,
                        showUserDetails: false,
                        roundedBottom: false,
                        tall: true,
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _PinnedBrowseFilters(
                        child: Container(
                          key: const Key('browse-pinned-controls'),
                          color: AppColors.background,
                          child: Column(
                            children: [
                              Container(
                                key: const Key('browse-pinned-search'),
                                height: _PinnedBrowseFilters.searchHeight,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.only(
                                    bottomLeft: Radius.circular(36),
                                    bottomRight: Radius.circular(36),
                                  ),
                                ),
                                child: ResponsiveContent(
                                  maxWidth: 980,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      8,
                                      20,
                                      12,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: _buildSearchField(
                                            equipmentProvider,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          width: 44,
                                          height: 44,
                                          child: IconButton(
                                            key: const Key(
                                              'browse-ai-assistant-button',
                                            ),
                                            tooltip: 'AI Assistant',
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute<void>(
                                                  builder: (_) =>
                                                      const BorrowerAssistantScreen(),
                                                ),
                                              );
                                            },
                                            style: IconButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.primary,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                            ),
                                            icon: const Icon(
                                              Icons.auto_awesome,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                key: const Key('browse-pinned-filters'),
                                height: _PinnedBrowseFilters.filtersHeight,
                                color: AppColors.background,
                                child: ResponsiveContent(
                                  maxWidth: 980,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    ),
                                    child: _buildFilterRow(equipmentProvider),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: ResponsiveContent(
                        maxWidth: 980,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                "Check what's on the shelf and request what you need.",
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13.5,
                                ),
                              ),
                              const SizedBox(height: 20),
                              if (equipmentProvider.isLoading)
                                const Padding(
                                  padding: EdgeInsets.only(top: 40),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              else if (equipmentList.isEmpty &&
                                  equipmentProvider.loadError != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 40),
                                  child: Center(
                                    child: Text(
                                      equipmentProvider.loadError!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                )
                              else if (equipmentList.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(top: 40),
                                  child: Center(
                                    child: Text(
                                      'No equipment matches your filters.',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (equipmentProvider.loadError != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: Text(
                                          equipmentProvider.loadError!,
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final cardWidth =
                                            (constraints.maxWidth - 16) / 2;

                                        return Wrap(
                                          spacing: 16,
                                          runSpacing: 14,
                                          children: equipmentList
                                              .map(
                                                (equipment) => SizedBox(
                                                  width: cardWidth,
                                                  child: EquipmentCard(
                                                    equipment: equipment,
                                                    requested:
                                                        requestProvider !=
                                                            null &&
                                                        userId != null &&
                                                        requestProvider
                                                            .hasPendingRequest(
                                                              userId,
                                                              equipment.id,
                                                            ),
                                                    onRequest: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              RequestFormScreen(
                                                                equipment:
                                                                    equipment,
                                                              ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinnedBrowseFilters extends SliverPersistentHeaderDelegate {
  const _PinnedBrowseFilters({required this.child});

  final Widget child;

  static const double searchHeight = 72;
  static const double filtersHeight = 58;
  static const double height = searchHeight + filtersHeight;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: AppColors.background,
      elevation: overlapsContent ? 2 : 0,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedBrowseFilters oldDelegate) =>
      oldDelegate.child != child;
}

/// Reusable full-width dropdown styled to match the app's input fields.
///
/// Every option renders at the same fixed height with a single, non-wrapping
/// line, and the unselected hint is the label of the `null` option, so the
/// field never resizes or shifts no matter which choice is picked.
class _FilterDropdown<T> extends StatelessWidget {
  static const double fieldHeight = 38;

  final double width;
  final T value;
  final List<T> options;
  final String Function(T value) labelOf;
  final ValueChanged<T> onChanged;
  final bool highlighted;

  const _FilterDropdown({
    required this.width,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: LayoutBuilder(
        builder: (context, constraints) => MenuAnchor(
          style: MenuStyle(
            minimumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, 0)),
          ),
          menuChildren: options
              .map(
                (option) => MenuItemButton(
                  onPressed: () => onChanged(option),
                  child: SizedBox(
                    width: constraints.maxWidth - 32,
                    height: 48,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        labelOf(option),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
          builder: (context, controller, child) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () =>
                controller.isOpen ? controller.close() : controller.open(),
            child: Container(
              width: double.infinity,
              height: fieldHeight,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: highlighted ? AppColors.brandDeep : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: highlighted
                      ? AppColors.brandDeep
                      : AppColors.fieldBorder,
                ),
              ),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      labelOf(value),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: highlighted
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: highlighted ? Colors.white70 : Colors.grey,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryCountChip extends StatelessWidget {
  const _CategoryCountChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.brandDeep : Colors.white,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? AppColors.brandDeep : AppColors.fieldBorder,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          child: Text(
            '$label ($count)',
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
