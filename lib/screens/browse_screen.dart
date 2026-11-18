// lib/screens/browse_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/equipment_model.dart';
import '../providers/equipment_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/request_provider.dart';
import '../services/borrower_assistant_service.dart';
import '../theme/app_colors.dart';
import '../utils/responsive_layout.dart';
import '../utils/borrower_assistant_conversation_store.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/equipment_card.dart';
import 'borrower_assistant_screen.dart';
import 'request_form_screen.dart';

class BrowseScreen extends StatefulWidget {
  final VoidCallback? onProfileTap;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onScannerTap;
  final BorrowerAssistantService? assistantService;

  const BrowseScreen({
    super.key,
    this.onProfileTap,
    this.onNotificationTap,
    this.onScannerTap,
    this.assistantService,
  });

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  static const _assistantSuggestions = [
    'Available items?',
    'Camera to borrow?',
    'Request status?',
  ];

  final _searchController = TextEditingController();
  final _browseScrollController = ScrollController();
  bool _isBrowseScrolled = false;
  String? _noticeUserId;

  @override
  void initState() {
    super.initState();
    _browseScrollController.addListener(_handleBrowseScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == _noticeUserId) return;
    _noticeUserId = userId;
    if (userId != null) {
      unawaited(_restoreAssistantReplyNotice(userId));
    }
  }

  Future<void> _restoreAssistantReplyNotice(String userId) async {
    try {
      await BorrowerAssistantConversationStore.restoreReplyNotice(userId);
    } catch (error) {
      debugPrint('Could not restore assistant reply notification: $error');
    }
  }

  void _handleBrowseScroll() {
    final isScrolled =
        _browseScrollController.hasClients &&
        _browseScrollController.offset > 0;
    if (isScrolled == _isBrowseScrolled) return;
    setState(() => _isBrowseScrolled = isScrolled);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _browseScrollController
      ..removeListener(_handleBrowseScroll)
      ..dispose();
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
                      width: 48,
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
        constraints: const BoxConstraints(minHeight: 48),
        suffixIconConstraints: const BoxConstraints.tightFor(
          width: 50,
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

  Widget _buildAssistantSuggestions() {
    return SizedBox(
      height: 40,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 8.0;
          final pillWidth =
              (constraints.maxWidth -
                  gap * (_assistantSuggestions.length - 1)) /
              _assistantSuggestions.length;

          return Row(
            key: const Key('browse-ai-suggestions'),
            children: [
              for (
                var index = 0;
                index < _assistantSuggestions.length;
                index++
              ) ...[
                if (index > 0) const SizedBox(width: gap),
                SizedBox(
                  width: pillWidth,
                  height: 40,
                  child: Material(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: AppColors.fieldBorder),
                    ),
                    child: InkWell(
                      key: Key('browse-ai-suggestion-$index'),
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        _openAssistant(
                          initialQuestion: _assistantSuggestions[index],
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _assistantSuggestions[index],
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _openAssistant({String? initialQuestion}) async {
    final notificationProvider = context.read<NotificationProvider?>();
    final activePageId = notificationProvider?.beginActivePage('fabii_chat');
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BorrowerAssistantScreen(
            service: widget.assistantService,
            initialQuestion: initialQuestion,
          ),
        ),
      );
    } finally {
      if (activePageId != null) {
        notificationProvider?.endActivePage(activePageId);
      }
    }
  }

  Widget _buildAssistantReplyNotice(String? userId) {
    if (userId == null) return const SizedBox.shrink();
    return ValueListenableBuilder<BorrowerAssistantReplyNotice?>(
      valueListenable: BorrowerAssistantConversationStore.replyNotice,
      builder: (context, notice, child) {
        final matchingNotice = notice?.userId == userId ? notice : null;
        final replying =
            matchingNotice?.state == BorrowerAssistantNoticeState.replying;
        final replied =
            matchingNotice?.state == BorrowerAssistantNoticeState.replied;
        final idle = !replying && !replied;
        return SizedBox(
          height: 24,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const Key('browse-ai-reply-notice'),
              onTap: replying ? null : () => _openAssistant(),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    if (replying)
                      const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white70,
                        ),
                      )
                    else if (replied)
                      const Icon(
                        Icons.mark_chat_unread_outlined,
                        size: 15,
                        color: Colors.white,
                      ),
                    if (!idle) const SizedBox(width: 6),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          idle
                              ? 'Fabii is waiting...'
                              : replying
                              ? 'Fabii is replying...'
                              : 'Fabii replied · View',
                          key: const Key('browse-ai-reply-notice-text'),
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAssistantButton() {
    return SizedBox(
      width: 153,
      height: 180,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 168,
            height: 168,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0xAA9C4DCC), Color(0x009C4DCC)],
                stops: [0.2, 1],
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'AI Assistant',
            child: Material(
              key: const Key('browse-ai-assistant-button'),
              color: Colors.transparent,
              elevation: 0,
              child: InkWell(
                onTap: () {
                  _openAssistant();
                },
                child: Ink(
                  decoration: BoxDecoration(
                    image: const DecorationImage(
                      image: AssetImage('assets/images/fabii.webp'),
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(EquipmentProvider equipmentProvider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterDropdown<String?>(
            width: 136,
            value: equipmentProvider.selectedCategory,
            options: [null, ...equipmentProvider.categories],
            labelOf: (category) => category ?? 'All Categories',
            onChanged: equipmentProvider.setCategory,
            highlighted: true,
          ),
          const SizedBox(width: 10),
          _FilterDropdown<EquipmentStatus?>(
            width: 145,
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
                child: ScrollConfiguration(
                  behavior: const _BrowseScrollBehavior(),
                  child: CustomScrollView(
                    key: const Key('browse-scroll-view'),
                    controller: _browseScrollController,
                    slivers: [
                      SliverToBoxAdapter(
                        child: DashboardHeader(
                          title: 'Lendy',
                          onProfileTap: widget.onProfileTap,
                          onNotificationTap: widget.onNotificationTap,
                          showUserDetails: false,
                          roundedBottom: false,
                          tall: true,
                          bottomContent: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'What do you need today?',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Browse equipment or ask Fabii for help.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _PinnedBrowseFilters(
                          searchHeight: _isBrowseScrolled
                              ? _PinnedBrowseFilters.compactSearchHeight
                              : _PinnedBrowseFilters.assistantSearchHeight,
                          child: Container(
                            key: const Key('browse-pinned-controls'),
                            color: AppColors.background,
                            child: Column(
                              children: [
                                Container(
                                  key: const Key('browse-pinned-search'),
                                  height: _isBrowseScrolled
                                      ? _PinnedBrowseFilters.compactSearchHeight
                                      : _PinnedBrowseFilters
                                            .assistantSearchHeight,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.only(
                                      bottomLeft: Radius.circular(48),
                                      bottomRight: Radius.circular(48),
                                    ),
                                  ),
                                  child: ClipRRect(
                                    key: const Key(
                                      'browse-pinned-search-content-clip',
                                    ),
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(48),
                                      bottomRight: Radius.circular(48),
                                    ),
                                    child: ResponsiveContent(
                                      maxWidth: 980,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                        ),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          clipBehavior: Clip.none,
                                          children: [
                                            Positioned(
                                              left: 0,
                                              right: _isBrowseScrolled
                                                  ? 0
                                                  : 138,
                                              bottom: _isBrowseScrolled
                                                  ? 8
                                                  : 40,
                                              child: _isBrowseScrolled
                                                  ? _buildSearchField(
                                                      equipmentProvider,
                                                    )
                                                  : Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        _buildAssistantSuggestions(),
                                                        const SizedBox(
                                                          height: 24,
                                                        ),
                                                        _buildSearchField(
                                                          equipmentProvider,
                                                        ),
                                                      ],
                                                    ),
                                            ),
                                            if (!_isBrowseScrolled &&
                                                userId != null)
                                              Positioned(
                                                left: 0,
                                                right: 170,
                                                bottom: 8,
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  child: SizedBox(
                                                    width: 120,
                                                    child:
                                                        _buildAssistantReplyNotice(
                                                          userId,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            if (!_isBrowseScrolled)
                                              Positioned(
                                                right: -8,
                                                bottom: 0,
                                                child: _buildAssistantButton(),
                                              ),
                                          ],
                                        ),
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
            ),
          ],
        ),
      ),
    );
  }
}

class _PinnedBrowseFilters extends SliverPersistentHeaderDelegate {
  const _PinnedBrowseFilters({required this.child, required this.searchHeight});

  final Widget child;
  final double searchHeight;

  static const double assistantSearchHeight = 180;
  static const double compactSearchHeight = 64;
  static const double filtersHeight = 58;

  @override
  double get minExtent => searchHeight + filtersHeight;

  @override
  double get maxExtent => searchHeight + filtersHeight;

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
      oldDelegate.child != child || oldDelegate.searchHeight != searchHeight;
}

class _BrowseScrollBehavior extends MaterialScrollBehavior {
  const _BrowseScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (details.direction == AxisDirection.up ||
        details.direction == AxisDirection.down) {
      return child;
    }
    return super.buildScrollbar(context, child, details);
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
                  const SizedBox(width: 4),
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
