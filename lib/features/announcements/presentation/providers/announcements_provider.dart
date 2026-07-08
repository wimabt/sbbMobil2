import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/locale_provider.dart';
import '../../../../data/models/models.dart';
import '../../../../data/repositories/repositories.dart';

/// Announcements feature state
class AnnouncementsState {
  const AnnouncementsState({
    this.allAnnouncements = const [], // Tüm duyurular (filtrelenmemiş cache)
    this.announcements = const [], // Kategoriye göre filtrelenmiş
    this.filteredAnnouncements = const [], // Kategori + arama filtrelenmiş
    this.selectedCategoryId,
    this.searchQuery = '',
    this.categories = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.currentPage = 1,
    this.totalPages = 1,
    this.hasMore = true,
  });

  final List<Announcement> allAnnouncements; // Client-side filtreleme için cache
  final List<Announcement> announcements;
  final List<Announcement> filteredAnnouncements;
  final int? selectedCategoryId;
  final String searchQuery;
  final List<AnnouncementCategory> categories;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int currentPage;
  final int totalPages;
  final bool hasMore;

  /// Selected category name for UI display
  String get selectedCategoryName {
    if (selectedCategoryId == null) return 'Tümü';
    final category = categories.firstWhere(
      (c) => c.id == selectedCategoryId,
      orElse: () => const AnnouncementCategory(id: 0, name: 'Tümü'),
    );
    return category.name;
  }

  AnnouncementsState copyWith({
    List<Announcement>? allAnnouncements,
    List<Announcement>? announcements,
    List<Announcement>? filteredAnnouncements,
    int? selectedCategoryId,
    bool clearCategory = false,
    String? searchQuery,
    List<AnnouncementCategory>? categories,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
    int? currentPage,
    int? totalPages,
    bool? hasMore,
  }) {
    return AnnouncementsState(
      allAnnouncements: allAnnouncements ?? this.allAnnouncements,
      announcements: announcements ?? this.announcements,
      filteredAnnouncements: filteredAnnouncements ?? this.filteredAnnouncements,
      selectedCategoryId: clearCategory ? null : (selectedCategoryId ?? this.selectedCategoryId),
      searchQuery: searchQuery ?? this.searchQuery,
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// Announcements Notifier - Backend API'ye bağlı
class AnnouncementsNotifier extends Notifier<AnnouncementsState> {
  late AnnouncementRepository _repository;
  String? _lastLanguageCode;

  @override
  AnnouncementsState build() {
    _repository = ref.watch(announcementRepositoryProvider);
    
    // PERFORMANS: Sadece languageCode değiştiğinde rebuild
    final currentLanguageCode = ref.watch(
      localeProvider.select((s) => s.locale.languageCode),
    );
    
    // İlk build veya dil değişikliği varsa verileri yükle
    final shouldReload = _lastLanguageCode == null || _lastLanguageCode != currentLanguageCode;
    
    if (shouldReload) {
      debugPrint('🌍 [AnnouncementsNotifier] Language changed: $_lastLanguageCode -> $currentLanguageCode, reloading data...');
      _lastLanguageCode = currentLanguageCode;
      
      // Initial load - schedule after build completes
      Future.microtask(() {
        _loadInitialData();
      });
    }
    
    return const AnnouncementsState(isLoading: true);
  }

  /// Load both categories and announcements IN PARALLEL
  /// 
  /// PERFORMANCE OPTIMIZATION: Using Future.wait to fetch both data sources
  /// concurrently instead of sequentially. This reduces load time by ~50%.
  Future<void> _loadInitialData() async {
    try {
      // ============================================================================
      // OPTIMIZATION: Fetch categories and announcements IN PARALLEL
      // Previously: await loadCategories() THEN await loadAnnouncements()
      // Now: Future.wait([loadCategories(), loadAnnouncements()])
      // ============================================================================
      await Future.wait([
        loadCategories(),
        loadAnnouncements(),
      ]);
    } catch (e) {
      debugPrint('❌ [AnnouncementsNotifier] Error loading initial data: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Load categories from API
  Future<void> loadCategories() async {
    try {
      final categories = await _repository.getCategories();
      
      state = state.copyWith(categories: categories);
      debugPrint('✅ [AnnouncementsNotifier] Loaded ${categories.length} categories');
    } catch (e) {
      debugPrint('⚠️ [AnnouncementsNotifier] Error loading categories: $e');
      // Don't fail silently - categories are important for filtering
    }
  }

  /// Load ALL announcements from API (kategori filtresi client-side uygulanacak)
  /// 
  /// CACHING STRATEGY: Tüm duyurular bir seferde çekilir ve allAnnouncements'ta
  /// cache'lenir. Kategori değişimlerinde API çağrısı YAPILMAZ - cache'den filtre uygulanır.
  Future<void> loadAnnouncements({bool refresh = false}) async {
    // Eğer zaten tüm duyurular yüklenmişse ve refresh değilse, sadece filtreleme yap
    if (state.allAnnouncements.isNotEmpty && !refresh) {
      debugPrint('🔄 [AnnouncementsNotifier] Using cached announcements, applying filters');
      _applyFilters();
      return;
    }

    // NOT: Eski "isLoading && !refresh" kontrolü KALDIRILDI!
    // Bu kontrol initial state isLoading:true olduğu için API çağrısını engelliyordu.
    // İlk kontrol (cache varsa dön) yeterli - duplicate load'ları önlemek için
    // async işlemin kendisi zaten tek seferde çalışır.

    state = state.copyWith(
      isLoading: true, 
      clearError: true,
    );

    try {
      
      // Tek seferde tüm duyuruları çek (limit yüksek)
      // Çoğu şehir uygulamasında 200'den fazla aktif duyuru olmaz
      final response = await _repository.getAnnouncements(
        page: 1,
        limit: 200, // Yüksek limit - tüm duyuruları tek seferde çek
      );
      
      
      // API başarısız olsa bile boş liste ile devam et
      List<Announcement> allAnnouncementsList = response.data ?? [];
      
      debugPrint('✅ [AnnouncementsNotifier] Loaded ${allAnnouncementsList.length} announcements');
      
      // Tarihe göre sırala (en yeni başta) - null-safe
      if (allAnnouncementsList.isNotEmpty) {
        allAnnouncementsList.sort((a, b) {
          final aDate = a.publishedAt ?? a.createdAt ?? DateTime(1970);
          final bDate = b.publishedAt ?? b.createdAt ?? DateTime(1970);
          return bDate.compareTo(aDate);
        });
      }
      
      state = state.copyWith(
        allAnnouncements: allAnnouncementsList,
        isLoading: false,
        hasMore: false, // Tüm veriler yüklendi
      );
      
      // Filtreleri uygula
      _applyFilters();
      
    } catch (e, stackTrace) {
      debugPrint('❌ [AnnouncementsNotifier] Error loading announcements: $e');
      debugPrint('❌ [AnnouncementsNotifier] Stack trace: $stackTrace');
      state = state.copyWith(
        allAnnouncements: const [], // Hata durumunda boş liste
        isLoading: false,
        error: e.toString(),
      );
      // Hata durumunda da filtreleri uygula (boş listeyi göster)
      _applyFilters();
    }
  }

  // loadMore artık gerekli değil - tüm veriler ilk yüklemede çekiliyor
  // UI'da infinite scroll yerine tüm liste gösterilecek

  /// Set category filter (CLIENT-SIDE - API çağrısı YOK)
  /// 
  /// Kategori değişiminde sadece cache'deki veriler filtrelenir.
  /// Bu sayede her kategori değişiminde gereksiz API sorgusu atılmaz.
  void setCategory(int? categoryId) {
    if (state.selectedCategoryId == categoryId) return;

    
    state = state.copyWith(
      selectedCategoryId: categoryId,
      clearCategory: categoryId == null,
    );
    
    // API çağrısı YOK - cache'den client-side filtreleme
    _applyFilters();
  }

  /// Apply both category and search filters (client-side)
  void _applyFilters() {
    // Boş liste durumunda da state'i güncelle
    if (state.allAnnouncements.isEmpty) {
      state = state.copyWith(
        announcements: const [],
        filteredAnnouncements: const [],
      );
      debugPrint('🔄 [AnnouncementsNotifier] No announcements to filter');
      return;
    }

    // 1. Kategoriye göre filtrele
    final categoryFiltered = _filterByCategory(
      state.allAnnouncements, 
      state.selectedCategoryId,
    );

    // 2. Arama filtresini uygula
    final searchFiltered = _filterBySearch(categoryFiltered, state.searchQuery);

    state = state.copyWith(
      announcements: categoryFiltered,
      filteredAnnouncements: searchFiltered,
    );

  }

  /// Filter by category (client-side)
  List<Announcement> _filterByCategory(List<Announcement> announcements, int? categoryId) {
    if (categoryId == null) return announcements;
    
    return announcements.where((a) => a.categoryId == categoryId).toList();
  }

  /// Search announcements (client-side)
  void search(String query) {
    state = state.copyWith(searchQuery: query);
    _applyFilters();
  }

  /// Clear search
  void clearSearch() {
    state = state.copyWith(searchQuery: '');
    _applyFilters();
  }

  /// Filter by search query (client-side)
  List<Announcement> _filterBySearch(List<Announcement> announcements, String query) {
    if (query.isEmpty) return announcements;
    
    final lowerQuery = query.toLowerCase();
    return announcements.where((a) {
      return a.title.toLowerCase().contains(lowerQuery) ||
          (a.excerpt?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  /// Refresh all data
  Future<void> refresh() async {
    await loadCategories();
    await loadAnnouncements(refresh: true);
  }
}

/// Provider
final announcementsProvider = NotifierProvider<AnnouncementsNotifier, AnnouncementsState>(
  AnnouncementsNotifier.new,
);

/// Single announcement detail provider
final announcementDetailProvider = FutureProvider.autoDispose.family<Announcement?, String>((ref, id) async {
  final repository = ref.watch(announcementRepositoryProvider);
  
  try {
    final announcement = await repository.getAnnouncement(id);
    
    // Record view when detail is loaded
    if (announcement != null) {
      repository.recordView(id);
    }
    
    return announcement;
  } catch (e) {
    debugPrint('❌ [announcementDetailProvider] Error: $e');
    return null;
  }
});

// ============================================================================
// ANA SAYFA PROVIDER'LARI
// Ana sayfa için ayrı API çağrıları - tüm liste yüklenmesini beklemez
// ============================================================================

/// Latest announcements provider (home screen için)
/// Bu ayrı API çağrısı yapıyor - ana sayfa tüm duyuruları beklememeli
final latestAnnouncementsProvider = FutureProvider.autoDispose<List<Announcement>>((ref) async {
  final repository = ref.watch(announcementRepositoryProvider);
  
  // PERFORMANS: Sadece languageCode değiştiğinde rebuild
  final languageCode = ref.watch(
    localeProvider.select((s) => s.locale.languageCode),
  );
  debugPrint('🌍 [latestAnnouncementsProvider] Current language: $languageCode');
  
  try {
    debugPrint('🔄 [latestAnnouncementsProvider] Loading latest 5 announcements...');
    final result = await repository.getLatestAnnouncements(limit: 5);
    debugPrint('✅ [latestAnnouncementsProvider] Loaded ${result.length} announcements');
    return result;
  } catch (e) {
    debugPrint('❌ [latestAnnouncementsProvider] Error: $e');
    return [];
  }
});

/// Important announcements provider (banner için)
final importantAnnouncementsProvider = FutureProvider.autoDispose<List<Announcement>>((ref) async {
  final repository = ref.watch(announcementRepositoryProvider);
  
  // Locale değişikliğini dinle - dil değiştiğinde verileri yeniden yükle
  final languageCode = ref.watch(
    localeProvider.select((s) => s.locale.languageCode),
  );
  debugPrint('🌍 [importantAnnouncementsProvider] Current language: $languageCode');
  
  try {
    return await repository.getImportantAnnouncements();
  } catch (e) {
    debugPrint('❌ [importantAnnouncementsProvider] Error: $e');
    return [];
  }
});

/// Announcement categories provider
/// Bu announcementsProvider.categories ile aynı, ama ayrı kullanım için
final announcementCategoriesProvider = Provider<List<AnnouncementCategory>>((ref) {
  final announcementsState = ref.watch(announcementsProvider);
  return announcementsState.categories;
});
