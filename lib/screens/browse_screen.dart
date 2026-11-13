// lib/screens/browse_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/equipment_model.dart';
import '../providers/equipment_provider.dart';
import '../providers/request_provider.dart';
import '../theme/app_colors.dart';
import '../utils/responsive_layout.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/equipment_card.dart';
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

  @override
  Widget build(BuildContext context) {
    final equipmentProvider = context.watch<EquipmentProvider>();
    final requestProvider = context.watch<RequestProvider?>();
    final userId = context.watch<AuthProvider>().currentUser?.id;
    final equipmentList = equipmentProvider.filteredEquipment;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        key: const Key('browse-scroll-view'),
        slivers: [
          SliverToBoxAdapter(
            child: DashboardHeader(
              title: 'Browse Items',
              onProfileTap: widget.onProfileTap,
              onNotificationTap: widget.onNotificationTap,
              tall: true,
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

                    // ----- Search field -----
                    TextField(
                      controller: _searchController,
                      onChanged: equipmentProvider.setSearchQuery,
                      decoration: InputDecoration(
                        hintText: 'Search by name, room or asset code...',
                        hintStyle: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13.5,
                        ),
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: widget.onScannerTap == null
                            ? null
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    key: const Key('browse-search-scanner'),
                                    tooltip: 'Scan item code',
                                    onPressed: widget.onScannerTap,
                                    icon: const Icon(
                                      Icons.qr_code_scanner,
                                      size: 19,
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 10),
                                    child: VerticalDivider(width: 1),
                                  ),
                                ],
                              ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 13,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.fieldBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.fieldBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ----- Compact horizontal filters -----
                    SingleChildScrollView(
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
                            labelOf: (status) =>
                                status?.label ?? 'Any Availability',
                            onChanged: equipmentProvider.setAvailability,
                          ),
                          for (final category
                              in equipmentProvider.categories) ...[
                            const SizedBox(width: 10),
                            _CategoryCountChip(
                              label: category,
                              count: equipmentProvider.countForCategory(
                                category,
                              ),
                              selected:
                                  equipmentProvider.selectedCategory ==
                                  category,
                              onTap: () => equipmentProvider.setCategory(
                                equipmentProvider.selectedCategory == category
                                    ? null
                                    : category,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ----- Equipment list -----
                    if (equipmentProvider.isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(child: CircularProgressIndicator()),
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
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (equipmentProvider.loadError != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                equipmentProvider.loadError!,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final cardWidth = (constraints.maxWidth - 16) / 2;

                              return Wrap(
                                spacing: 16,
                                children: equipmentList
                                    .map(
                                      (equipment) => SizedBox(
                                        width: cardWidth,
                                        child: EquipmentCard(
                                          equipment: equipment,
                                          requested:
                                              requestProvider != null &&
                                              userId != null &&
                                              requestProvider.hasPendingRequest(
                                                userId,
                                                equipment.id,
                                              ),
                                          onRequest: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    RequestFormScreen(
                                                      equipment: equipment,
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
    );
  }
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
