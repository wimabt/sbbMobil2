import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/feature_flags.dart';
import '../../../../core/services/discovery_service.dart';
import '../../../auth/providers/auth_provider.dart';
import '../models/campaign.dart';

/// Campaigns feature state (§2.6 pagination destekli)
class CampaignsState {
  const CampaignsState({
    this.activeCampaigns = const [],
    this.completedCampaigns = const [],
    this.selectedTab = 0,
    this.userPoints = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.currentPage = 1,
    this.totalPages = 1,
    this.error,
  });

  final List<Campaign> activeCampaigns;
  final List<Campaign> completedCampaigns;
  final int selectedTab;
  final int userPoints;
  final bool isLoading;
  final bool isLoadingMore;
  final int currentPage;
  final int totalPages;
  final String? error;

  List<Campaign> get currentCampaigns =>
      selectedTab == 0 ? activeCampaigns : completedCampaigns;

  bool get hasMore => currentPage < totalPages;

  CampaignsState copyWith({
    List<Campaign>? activeCampaigns,
    List<Campaign>? completedCampaigns,
    int? selectedTab,
    int? userPoints,
    bool? isLoading,
    bool? isLoadingMore,
    int? currentPage,
    int? totalPages,
    String? error,
  }) {
    return CampaignsState(
      activeCampaigns: activeCampaigns ?? this.activeCampaigns,
      completedCampaigns: completedCampaigns ?? this.completedCampaigns,
      selectedTab: selectedTab ?? this.selectedTab,
      userPoints: userPoints ?? this.userPoints,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      error: error,
    );
  }
}

/// Campaigns Notifier
class CampaignsNotifier extends Notifier<CampaignsState> {
  late DiscoveryService _discovery;

  @override
  CampaignsState build() {
    _discovery = ref.read(discoveryServiceProvider);
    // Auth değişikliğini dinle: login/logout olduğunda kampanyaları tazele.
    ref.listen<AuthState>(authProvider, (previous, next) {
      final wasAuthed = previous?.status == AuthStatus.authenticated;
      final isAuthed = next.status == AuthStatus.authenticated;
      final prevUserId = previous?.user?.id;
      final nextUserId = next.user?.id;

      if (isAuthed && (!wasAuthed || prevUserId != nextUserId)) {
        debugPrint('📢 [Campaigns] Auth → login/user-change, refreshing campaigns...');
        // ignore: discarded_futures
        loadCampaigns(refresh: true);
      } else if (!isAuthed && wasAuthed) {
        debugPrint('📢 [Campaigns] Auth → logout, clearing user progress...');
        // Logout: kampanya içeriğini koru ama kullanıcıya özel ilerlemeyi sıfırla.
        final clearedActive = state.activeCampaigns.map(_clearUserProgress).toList();
        final clearedCompleted = state.completedCampaigns.map(_clearUserProgress).toList();
        state = state.copyWith(
          activeCampaigns: clearedActive,
          completedCampaigns: clearedCompleted,
          userPoints: 0,
        );
      }
    });

    // İlk build: kampanyaları yükle.
    // Auth durumuna göre endpoint ya kullanıcıya özel veri döner ya da
    // genel kampanya listesini döner. _fetch içinde hata yakalanır.
    Future.microtask(_fetch);
    return const CampaignsState(isLoading: false, userPoints: 0);
  }

  static const _pageLimit = 20;

  Future<void> _fetch({int page = 1, bool append = false}) async {
    // Points/gamification kapalıysa kampanya listesi getirilmez.
    // UI da campaigns ekranını gizleyecek — defense-in-depth.
    if (!FeatureFlags.pointsEnabled) {
      state = const CampaignsState(
        isLoading: false,
        isLoadingMore: false,
        userPoints: 0,
      );
      return;
    }
    if (!append) {
      state = state.copyWith(isLoading: true, error: null);
    } else {
      state = state.copyWith(isLoadingMore: true, error: null);
    }

    try {
      final result = await _discovery.getCampaigns(page: page, limit: _pageLimit);
      debugPrint('📢 [Campaigns] Page $page — ${result.items.length} items');

      final active = append ? List<Campaign>.from(state.activeCampaigns) : <Campaign>[];
      final completed = append ? List<Campaign>.from(state.completedCampaigns) : <Campaign>[];

      final existingIds = <String>{
        ...active.map((c) => c.id),
        ...completed.map((c) => c.id),
      };

      for (final item in result.items) {
        final campaign = Campaign.fromMobileJson(item);
        if (existingIds.contains(campaign.id)) continue;

        final status = campaign.campaignStatus?.toLowerCase();
        final isExpired = status == 'expired';

        if (!isExpired) {
          active.add(campaign);
        }

        if (campaign.isCompleted || isExpired) {
          completed.add(campaign);
        }
      }

      state = state.copyWith(
        activeCampaigns: active,
        completedCampaigns: completed,
        isLoading: false,
        isLoadingMore: false,
        currentPage: result.currentPage,
        totalPages: result.totalPages,
      );
    } catch (e) {
      debugPrint('❌ [Campaigns] _fetch error: $e');
      // Hata durumunda mevcut kampanya listesini koru.
      // Sadece loading flag'lerini kapat; ilk yüklemede liste boşsa error göster.
      final hasData = state.activeCampaigns.isNotEmpty ||
          state.completedCampaigns.isNotEmpty;
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: hasData ? null : e.toString(),
      );
    }
  }

  /// Kullanıcıya özel ilerleme alanlarını sıfırlar, kampanya içeriğini korur.
  Campaign _clearUserProgress(Campaign c) {
    return Campaign(
      id: c.id,
      type: c.type,
      title: c.title,
      description: c.description,
      points: c.points,
      claimed: false,
      progress: 0,
      target: c.target,
      reward: c.reward,
      icon: c.icon,
      color: c.color,
      visitedPlaceIds: const [],
      externalPlaceId: c.externalPlaceId,
      externalRouteId: c.externalRouteId,
      imageUrl: c.imageUrl,
      daysLeft: c.daysLeft,
      campaignName: c.campaignName,
      campaignStatus: c.campaignStatus,
      routeDistanceKm: c.routeDistanceKm,
      durationMinutes: c.durationMinutes,
    );
  }

  Future<void> loadCampaigns({bool refresh = false}) async {
    if (state.isLoading && !refresh) return;
    await _fetch();
  }

  /// §2.6: Sonraki sayfayı yükle (sonsuz scroll desteği).
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    await _fetch(page: state.currentPage + 1, append: true);
  }

  void setTab(int tab) {
    state = state.copyWith(selectedTab: tab);
  }

  Future<void> refresh() => _fetch();
}

/// Provider
final campaignsProvider = NotifierProvider<CampaignsNotifier, CampaignsState>(
  CampaignsNotifier.new,
);
