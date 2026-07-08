import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../core/widgets/search_bar.dart';
import '../../../l10n/l10n.dart';
import 'models/culture_models.dart';
import 'providers/events_provider.dart';
import 'widgets/event_card.dart';
import 'widgets/event_filter_modal.dart';
import 'widgets/upcoming_events_section.dart';

/// Events Screen – Etkinlikler sayfası (Events API'ye bağlı)
class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final notifier = ref.read(eventsListProvider.notifier);
    final state = ref.read(eventsListProvider);
    if (state.isSearchActive || state.isLoadingMore || !state.hasNextPage) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      notifier.loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eventsListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Debug: State değişikliklerini logla
    debugPrint('🎨 [EventsScreen] build() - isLoading=${state.isLoading}, items=${state.items.length}, error=${state.error}');

    if (state.isLoading && state.items.isEmpty) {
      _animationController.reset();
    } else if (state.items.isNotEmpty && !_animationController.isAnimating) {
      _animationController.forward();
    }

    SystemChrome.setSystemUIOverlayStyle(
      isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );

    final upcomingForSection = state.upcoming
        .map((e) => UpcomingEvent(
              title: e.title,
              date: e.date,
              time: e.time,
              location: e.displayLocation,
              type: e.displayCategory,
            ))
        .toList();

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: RefreshIndicator(
        onRefresh: () => ref.read(eventsListProvider.notifier).refresh(),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildHeader(context, isDark, state),
            SliverToBoxAdapter(
              child: UpcomingEventsSection(
                events: upcomingForSection,
              ),
            ),
            SliverToBoxAdapter(child: _buildSectionTitle(context, isDark, state)),
            state.isLoading && state.items.isEmpty
                ? _buildSkeletonList()
                : state.error != null && state.items.isEmpty
                    ? _buildErrorState(context, state.error!)
                    : _buildEventsList(context, state),
            if (state.isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            SliverToBoxAdapter(
              child: SizedBox(height: AppNavBar.bottomPadding + 24),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, bool isDark, EventsListState state) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      expandedHeight: 200,
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTitleRow(context, isDark, state),
                const SizedBox(height: 12),
                _buildSearchBar(context, isDark, state),
                const SizedBox(height: 12),
                _buildCategoryPills(context, isDark, state),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleRow(
      BuildContext context, bool isDark, EventsListState state) {
    // Toplam etkinlik sayısı (filtrelenmemiş)
    final total = state.isSearchActive ? state.items.length : state.upcomingCount;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.titleEvents,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : null,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              context.l10n.heroSubtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? Colors.white.withAlpha(150)
                        : Theme.of(context).hintColor,
                  ),
            ),
          ],
        ),
        _buildEventCountBadge(context, isDark, total),
      ],
    );
  }

  Widget _buildEventCountBadge(BuildContext context, bool isDark, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  AppColors.neonPurple.withAlpha(180),
                  AppColors.neonPurple.withAlpha(100)
                ]
              : [Colors.teal.shade500, Colors.teal.shade300],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isDark ? AppColors.neonPurple : Colors.teal).withAlpha(40),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            context.l10n.eventsCount(count),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(
      BuildContext context, bool isDark, EventsListState state) {
    // Etkinlikler sayfası için filtre butonu rengini tema ile uyumlu yap
    final baseFilterColor =
        isDark ? AppColors.neonPurple : Colors.teal.shade500;
    final activeFilterColor =
        isDark ? AppColors.neonPurple : Colors.teal.shade700;

    return AppSearchBar(
      hintText: context.l10n.lblSearchEvents,
      showFilterButton: true,
      isFilterActive: state.hasActiveFilters,
       // Sayfa temasına göre filtre butonu renkleri
      filterButtonColor: baseFilterColor,
      filterButtonActiveColor: activeFilterColor,
      onChanged: (value) =>
          ref.read(eventsListProvider.notifier).setSearch(value),
      onFilterTap: () => EventFilterModal.show(context),
    );
  }
  
  Widget _buildCategoryPills(
      BuildContext context, bool isDark, EventsListState state) {
    final categories = state.categories;
    final selectedType = state.selectedType;
    return SizedBox(
      height: 40,
      child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  final isActive = selectedType == null;
                  return _categoryChip(
                    context,
                    isDark: isDark,
                    label: context.l10n.lblAll,
                    isActive: isActive,
                    onTap: () =>
                        ref.read(eventsListProvider.notifier).setType(null),
                  );
                }
                final cat = categories[index - 1];
                final isActive =
                    selectedType == cat.slug || selectedType == cat.name;
                return _categoryChip(
                  context,
                  isDark: isDark,
                  label: cat.name,
                  isActive: isActive,
                  onTap: () =>
                      ref.read(eventsListProvider.notifier).setType(cat.slug),
                );
              },
            ),
    );
  }

  Widget _categoryChip(
    BuildContext context, {
    required bool isDark,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  colors: isDark
                      ? [
                          AppColors.neonPurple,
                          AppColors.neonPurple.withAlpha(180)
                        ]
                      : [Colors.teal.shade500, Colors.teal.shade400],
                )
              : null,
          color: isActive
              ? null
              : (isDark ? AppColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: isActive
              ? null
              : Border.all(
                  color: isDark
                      ? Colors.white.withAlpha(15)
                      : Colors.grey.shade300,
                ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: (isDark ? AppColors.neonPurple : Colors.teal)
                        .withAlpha(40),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive
                ? Colors.white
                : (isDark
                    ? Colors.white.withAlpha(180)
                    : Colors.grey.shade700),
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(
      BuildContext context, bool isDark, EventsListState state) {
    // Filtrelenmiş etkinlik sayısı
    final filteredCount = state.filteredCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            state.isSearchActive ? 'Arama Sonuçları' : 'Tüm Etkinlikler',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : null,
                ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withAlpha(10)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$filteredCount sonuç',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? Colors.white.withAlpha(150)
                        : Theme.of(context).hintColor,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SkeletonLoader(
            width: double.infinity,
            height: 280,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        childCount: 3,
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.read(eventsListProvider.notifier).refresh(),
              child: Text(context.l10n.btnRetry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsList(BuildContext context, EventsListState state) {
    final events = state.items;
    if (events.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptyState(context));
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final event = events[index];
          return FadeTransition(
            opacity: _animationController,
            child: EventCard(event: event),
          );
        },
        childCount: events.length,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.neonPurple.withAlpha(30)
                  : Colors.teal.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_busy,
              size: 48,
              color: isDark ? AppColors.neonPurple : Colors.teal,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            context.l10n.errNoEvents,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : null,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Arama kriterlerinize uygun etkinlik bulunamadı.\nFarklı bir kategori veya arama terimi deneyin.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? Colors.white.withAlpha(150)
                      : Theme.of(context).hintColor,
                ),
          ),
        ],
      ),
    );
  }
}
