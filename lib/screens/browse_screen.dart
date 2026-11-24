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
  final BorrowerAssistantService? assistantService;

  const BrowseScreen({
    super.key,
    this.onProfileTap,
    this.onNotificationTap,
    this.assistantService,
  });

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  static const _homeHeroAspectRatio = 2.0;
  static const _compactHeroMaxWidth = 480.0;
  static const _homeHeroReferenceWidth = 773.0;
  static const _assistantButtonSize = 64.0;
  static const _assistantButtonBottomOffset = 20.0;
  static const _browseContentBottomPadding = 16.0;

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

  Widget _buildHomeGreeting(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final screenWidth = screenSize.width;
    final titleSizeByWidth = (screenWidth * 0.09).clamp(28.0, 60.0).toDouble();
    final titleSizeByHeight = (screenSize.height * 0.075)
        .clamp(28.0, 60.0)
        .toDouble();
    final titleSize = titleSizeByWidth < titleSizeByHeight
        ? titleSizeByWidth
        : titleSizeByHeight;
    final subtitleSize = (screenWidth * 0.026).clamp(13.0, 20.0).toDouble();
    final textWidthFactor = screenWidth < 480
        ? 0.82
        : screenWidth >= 520
        ? 0.68
        : 0.82 - ((screenWidth - 480) / 40 * 0.14);

    return FractionallySizedBox(
      widthFactor: textWidthFactor,
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            const TextSpan(
              children: [
                TextSpan(text: 'What do you\nneed '),
                TextSpan(
                  text: 'today?',
                  style: TextStyle(color: Color(0xFF31E6B5)),
                ),
              ],
            ),
            key: const Key('browse-home-greeting'),
            style: TextStyle(
              color: Colors.white,
              fontSize: titleSize,
              fontWeight: FontWeight.w900,
              height: 0.9,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Browse equipment or ask Fabii for help.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: subtitleSize,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(
    EquipmentProvider equipmentProvider, {
    required double height,
  }) {
    final searchIconWidth = (height * 0.62).clamp(48.0, height).toDouble();

    return Container(
      key: const Key('browse-search-field-container'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(height / 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 30,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        key: const Key('browse-search-field'),
        controller: _searchController,
        onChanged: equipmentProvider.setSearchQuery,
        decoration: InputDecoration(
          hintText: 'Search by name, room or asset code...',
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          suffixIcon: const Icon(Icons.search, size: 22),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: EdgeInsets.fromLTRB(
            20,
            height * 0.2,
            8,
            height * 0.2,
          ),
          constraints: BoxConstraints.tightFor(height: height),
          suffixIconConstraints: BoxConstraints.tightFor(
            width: searchIconWidth,
            height: height,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(height / 2),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(height / 2),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(height / 2),
            borderSide: const BorderSide(color: AppColors.primaryLight),
          ),
        ),
      ),
    );
  }

  Future<void> _openAssistant({String? initialQuestion}) async {
    final notificationProvider = context.read<NotificationProvider?>();
    unawaited(
      notificationProvider?.markAssistantNotificationsRead() ??
          Future<void>.value(),
    );
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

  Widget _buildAssistantButton(String? userId) {
    return SizedBox(
      width: _assistantButtonSize,
      height: _assistantButtonSize,
      child: ValueListenableBuilder<BorrowerAssistantReplyNotice?>(
        valueListenable: BorrowerAssistantConversationStore.replyNotice,
        builder: (context, notice, child) {
          final replyCount =
              userId != null &&
                  notice?.userId == userId &&
                  notice?.state == BorrowerAssistantNoticeState.replied
              ? notice!.replyCount
              : 0;
          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              Semantics(
                button: true,
                label: 'Open Fabii assistant',
                child: Material(
                  key: const Key('browse-ai-assistant-button'),
                  color: Colors.white,
                  elevation: 2,
                  shape: const CircleBorder(
                    side: BorderSide(color: Color(0xFF51B893), width: 3),
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _openAssistant,
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/botFabii.png',
                        width: 58,
                        height: 58,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -1,
                child: Container(
                  width: 25,
                  height: 25,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryLight, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: CustomPaint(
                    key: const Key('browse-ai-message-icon'),
                    size: const Size(17, 15),
                    painter: _AssistantMessageIconPainter(
                      color: AppColors.primaryLight,
                    ),
                  ),
                ),
              ),
              if (replyCount > 0)
                Positioned(
                  right: -5,
                  top: -5,
                  child: Container(
                    key: const Key('browse-ai-reply-badge'),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE53935),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      replyCount > 99 ? '99+' : '$replyCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterRow(
    EquipmentProvider equipmentProvider, {
    required double horizontalInset,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: horizontalInset),
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
    final listBottomPadding =
        equipmentList.isNotEmpty && equipmentList.length.isEven
        ? _assistantButtonSize + _assistantButtonBottomOffset
        : _browseContentBottomPadding;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final searchInset = (screenWidth * 0.052).clamp(20.0, 40.0).toDouble();
    final filterInset = (screenWidth * 0.023).clamp(12.0, 18.0).toDouble();
    final initialSearchFieldHeight = (screenWidth * 0.083)
        .clamp(48.0, 64.0)
        .toDouble();
    final compactSearchFieldHeight = (screenWidth * 0.083)
        .clamp(48.0, 64.0)
        .toDouble();
    final initialSearchPadding = (screenWidth * 0.04)
        .clamp(16.0, 20.0)
        .toDouble();
    final searchFieldHeight = _isBrowseScrolled
        ? compactSearchFieldHeight
        : initialSearchFieldHeight;
    final searchVerticalPadding = _isBrowseScrolled
        ? 6.0
        : initialSearchPadding;
    final searchSectionHeight = searchFieldHeight + searchVerticalPadding * 2;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.black),
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: Stack(
          children: [
            Column(
              children: [
                ColoredBox(
                  key: const Key('browse-status-bar-background'),
                  color: Colors.black,
                  child: SizedBox(
                    width: double.infinity,
                    height: statusBarHeight,
                  ),
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
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final naturalHeroHeight =
                                    constraints.maxWidth /
                                        _homeHeroAspectRatio -
                                    statusBarHeight;
                                final compactHeroScale =
                                    0.64 +
                                    ((360 - constraints.maxWidth).clamp(
                                          0.0,
                                          40.0,
                                        ) /
                                        40 *
                                        0.08);
                                final compactHeroHeight =
                                    constraints.maxWidth * compactHeroScale;
                                final heroTransitionProgress =
                                    ((constraints.maxWidth -
                                                _compactHeroMaxWidth) /
                                            (_homeHeroReferenceWidth -
                                                _compactHeroMaxWidth))
                                        .clamp(0.0, 1.0)
                                        .toDouble();
                                final wideHeroReferenceHeight =
                                    _homeHeroReferenceWidth /
                                        _homeHeroAspectRatio -
                                    statusBarHeight;
                                final responsiveHeroHeight =
                                    constraints.maxWidth <= _compactHeroMaxWidth
                                    ? compactHeroHeight
                                    : constraints.maxWidth <
                                          _homeHeroReferenceWidth
                                    ? _compactHeroMaxWidth * 0.64 +
                                          (wideHeroReferenceHeight -
                                                  _compactHeroMaxWidth * 0.64) *
                                              heroTransitionProgress
                                    : naturalHeroHeight;
                                final heroHeight = responsiveHeroHeight
                                    .clamp(180.0, 380.0)
                                    .toDouble();

                                return SizedBox(
                                  height: heroHeight,
                                  child: DashboardHeader(
                                    title: 'Lendy',
                                    onProfileTap: widget.onProfileTap,
                                    onNotificationTap: widget.onNotificationTap,
                                    showUserDetails: false,
                                    backgroundImageAsset:
                                        'assets/images/bg-fabi.png',
                                    roundedBottom: true,
                                    tall: true,
                                    bottomContent: _buildHomeGreeting(context),
                                  ),
                                );
                              },
                            ),
                          ),
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _PinnedBrowseFilters(
                              searchHeight: searchSectionHeight,
                              child: Container(
                                key: const Key('browse-pinned-controls'),
                                color: AppColors.background,
                                child: Column(
                                  children: [
                                    Container(
                                      key: const Key('browse-pinned-search'),
                                      height: searchSectionHeight,
                                      color: AppColors.background,
                                      child: ResponsiveContent(
                                        maxWidth: 980,
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: searchInset,
                                            vertical: searchVerticalPadding,
                                          ),
                                          child: _buildSearchField(
                                            equipmentProvider,
                                            height: searchFieldHeight,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      key: const Key('browse-pinned-filters'),
                                      height:
                                          _PinnedBrowseFilters.filtersHeight,
                                      color: AppColors.background,
                                      child: ResponsiveContent(
                                        maxWidth: 980,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                          child: _buildFilterRow(
                                            equipmentProvider,
                                            horizontalInset: filterInset,
                                          ),
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
                                padding: EdgeInsets.fromLTRB(
                                  20,
                                  12,
                                  20,
                                  listBottomPadding,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                      "Check what's on the shelf and request what you need.",
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
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
                                          if (equipmentProvider.loadError !=
                                              null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 12,
                                              ),
                                              child: Text(
                                                equipmentProvider.loadError!,
                                                style: const TextStyle(
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                          LayoutBuilder(
                                            builder: (context, constraints) {
                                              final cardWidth =
                                                  (constraints.maxWidth - 16) /
                                                  2;

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
                                                                    equipment
                                                                        .id,
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
            Positioned(
              right: 16,
              bottom: _assistantButtonBottomOffset,
              child: _buildAssistantButton(userId),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantMessageIconPainter extends CustomPainter {
  const _AssistantMessageIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 20;
    final scaleY = size.height / 18;
    final bubblePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * scaleX
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final bubble = Path()
      ..moveTo(2 * scaleX, 9 * scaleY)
      ..cubicTo(
        2 * scaleX,
        4.6 * scaleY,
        5.6 * scaleX,
        scaleY,
        10 * scaleX,
        scaleY,
      )
      ..cubicTo(
        14.4 * scaleX,
        scaleY,
        18 * scaleX,
        4.6 * scaleY,
        18 * scaleX,
        9 * scaleY,
      )
      ..cubicTo(
        18 * scaleX,
        13.4 * scaleY,
        14.4 * scaleX,
        16 * scaleY,
        10 * scaleX,
        16 * scaleY,
      )
      ..cubicTo(
        7.7 * scaleX,
        16 * scaleY,
        5.8 * scaleX,
        15.2 * scaleY,
        4.4 * scaleX,
        14 * scaleY,
      )
      ..lineTo(1.5 * scaleX, 17 * scaleY)
      ..lineTo(2.7 * scaleX, 13.4 * scaleY)
      ..cubicTo(
        2.2 * scaleX,
        12.3 * scaleY,
        2 * scaleX,
        10.7 * scaleY,
        2 * scaleX,
        9 * scaleY,
      )
      ..close();
    canvas.drawPath(bubble, bubblePaint);

    final dotPaint = Paint()..color = color;
    for (final x in [6.0, 10.0, 14.0]) {
      canvas.drawCircle(Offset(x * scaleX, 9 * scaleY), 1.1 * scaleX, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_AssistantMessageIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _PinnedBrowseFilters extends SliverPersistentHeaderDelegate {
  const _PinnedBrowseFilters({required this.child, required this.searchHeight});

  final Widget child;
  final double searchHeight;

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
