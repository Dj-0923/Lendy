// lib/screens/browse_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/equipment_model.dart';
import '../providers/equipment_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/equipment_card.dart';
import 'request_form_screen.dart';
import 'qr_scan_screen.dart';

class BrowseScreen extends StatefulWidget {
  final VoidCallback? onProfileTap;

  const BrowseScreen({super.key, this.onProfileTap});

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
    final equipmentList = equipmentProvider.filteredEquipment;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primaryLight,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: const BorderSide(color: AppColors.primaryLight, width: 1.5),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const QrScanScreen()),
          );
        },
        child: const Icon(Icons.qr_code_scanner_rounded, size: 26),
      ),
      body: Column(
        children: [
          DashboardHeader(
            title: 'Browse Item',
            onProfileTap: widget.onProfileTap,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              children: [
                const Text(
                  "Check what's on the shelf and request what you need.",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 16),

                // ----- Search field -----
                TextField(
                  controller: _searchController,
                  onChanged: equipmentProvider.setSearchQuery,
                  decoration: InputDecoration(
                    hintText: 'Search by name or assets code...',
                    hintStyle: const TextStyle(
                      color: Colors.grey,
                      fontSize: 13.5,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: AppColors.fieldFill,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppColors.fieldBorder,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppColors.fieldBorder,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ----- Category filter -----
                _FilterDropdown<EquipmentCategory?>(
                  value: equipmentProvider.selectedCategory,
                  hint: 'All categories',
                  options: [null, ...EquipmentCategory.values],
                  labelOf: (c) => c?.label ?? 'All categories',
                  onChanged: equipmentProvider.setCategory,
                ),
                const SizedBox(height: 12),

                // ----- Availability filter -----
                _FilterDropdown<EquipmentStatus?>(
                  value: equipmentProvider.selectedAvailability,
                  hint: 'Any availability',
                  options: [null, ...EquipmentStatus.values],
                  labelOf: (s) => s?.label ?? 'Any availability',
                  onChanged: equipmentProvider.setAvailability,
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
                        style: const TextStyle(color: AppColors.textSecondary),
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
                          final useGrid = constraints.maxWidth >= 760;
                          final cardWidth = useGrid
                              ? (constraints.maxWidth - 16) / 2
                              : constraints.maxWidth;

                          return Wrap(
                            spacing: 16,
                            children: equipmentList
                                .map(
                                  (equipment) => SizedBox(
                                    width: cardWidth,
                                    child: EquipmentCard(
                                      equipment: equipment,
                                      onRequest: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => RequestFormScreen(
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
  static const double fieldHeight = 48;

  final T value;
  final String hint;
  final List<T> options;
  final String Function(T value) labelOf;
  final ValueChanged<T> onChanged;

  const _FilterDropdown({
    required this.value,
    required this.hint,
    required this.options,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
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
                  height: fieldHeight,
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
              color: AppColors.fieldFill,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.fieldBorder),
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
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
