import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/locale_provider.dart';

import '../../../../l10n/l10n.dart';
import '../../../../data/models/models.dart';
import '../../../../data/repositories/repositories.dart';

/// §6.4.5 — Etkinlik listesi sıralama seçenekleri.
enum EventSortMode {
  date, // Tarihe göre (yakın → uzak) — varsayılan
  name, // İsme göre (A-Z)
  popularity, // Popülerlik (katılımcı sayısı)
}

String eventSortLabel(AppLocalizations l10n, EventSortMode m) {
  switch (m) {
    case EventSortMode.date:
      return l10n.sortByDate;
    case EventSortMode.name:
      return l10n.sortByName;
    case EventSortMode.popularity:
      return l10n.sortPopularity;
  }
}

/// Etkinlik listesi + sayfalama state
class EventsListState {
  const EventsListState({
    this.allEvents = const [],
    this.items = const [],
    this.meta,
    this.upcoming = const [],
    this.categories = const [],
    this.selectedType,
    this.searchQuery = '',
    this.showFreeOnly = false,
    this.dateRange,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.sortMode = EventSortMode.date,
  });

  /// Tüm etkinlikler (API'den çekilen)
  final List<Event> allEvents;
  /// Filtrelenmiş etkinlikler (gösterilen)
  final List<Event> items;
  final ApiMeta? meta;
  final List<Event> upcoming;
  final List<EventCategoryItem> categories;
  /// type/category filter (slug veya name); null = tümü
  final String? selectedType;
  final String searchQuery;
  /// Sadece ücretsiz etkinlikleri göster
  final bool showFreeOnly;
  /// Tarih aralığı filtresi
  final DateTimeRange? dateRange;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final EventSortMode sortMode;

  bool get hasNextPage => meta?.hasNext ?? false;
  bool get isSearchActive => searchQuery.length >= 2;
  
  /// Toplam etkinlik sayısı (filtrelenmemiş)
  int get totalCount => allEvents.length;

  /// Geçmiş etkinlikler hariç toplam (bugünkü + ileri tarihli). Üstteki sayaç
  /// rozeti bunu kullanır; aksi halde gizlenen geçmiş etkinlikleri de sayardı.
  int get upcomingCount {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return allEvents.where((e) {
      final d = e.parsedStartDate;
      if (d == null) return true;
      return !DateTime(d.year, d.month, d.day).isBefore(today);
    }).length;
  }
  
  /// Filtrelenmiş etkinlik sayısı
  int get filteredCount => items.length;
  
  /// Aktif filtre var mı? (Filter button badge için)
  bool get hasActiveFilters => showFreeOnly || dateRange != null;

  EventsListState copyWith({
    List<Event>? allEvents,
    List<Event>? items,
    ApiMeta? meta,
    List<Event>? upcoming,
    List<EventCategoryItem>? categories,
    String? selectedType,
    String? searchQuery,
    bool? showFreeOnly,
    DateTimeRange? dateRange,
    bool clearDateRange = false,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
    EventSortMode? sortMode,
  }) {
    return EventsListState(
      allEvents: allEvents ?? this.allEvents,
      items: items ?? this.items,
      meta: meta ?? this.meta,
      upcoming: upcoming ?? this.upcoming,
      categories: categories ?? this.categories,
      selectedType: selectedType ?? this.selectedType,
      searchQuery: searchQuery ?? this.searchQuery,
      showFreeOnly: showFreeOnly ?? this.showFreeOnly,
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      sortMode: sortMode ?? this.sortMode,
    );
  }
}

/// Etkinlik listesi notifier – API'ye bağlı
class EventsListNotifier extends Notifier<EventsListState> {
  String? _lastLanguageCode;

  @override
  EventsListState build() {
    _repo = ref.read(eventRepositoryProvider);
    
    // PERFORMANS: Sadece languageCode değiştiğinde rebuild
    final currentLanguageCode = ref.watch(
      localeProvider.select((s) => s.locale.languageCode),
    );
    
    // İlk build veya dil değişikliği varsa verileri yükle
    final shouldReload = _lastLanguageCode == null || _lastLanguageCode != currentLanguageCode;
    
    if (shouldReload) {
      _lastLanguageCode = currentLanguageCode;
      
      Future.microtask(() {
        load(refresh: true);
      });
    }
    
    return const EventsListState(isLoading: true);
  }

  late EventRepository _repo;

  Future<void> load({bool refresh = false}) async {
    
    // İlk yükleme için refresh kontrolünü kaldır
    if (state.isLoading && !refresh && state.items.isNotEmpty) {
      return;
    }

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      items: refresh ? [] : state.items,
      meta: refresh ? null : state.meta,
    );

    List<EventCategoryItem> categories = [];
    List<Event> upcoming = [];

    // Kategorileri çek (başarısız olsa bile devam et)
    try {
      categories = await _repo.getCategories();
    } catch (e) {
      debugPrint('⚠️ [EventsProvider] Failed to load categories: $e');
      // Kategoriler başarısız olsa bile devam et
    }

    // Yaklaşan etkinlikleri çek (başarısız olsa bile devam et)
    try {
      upcoming = await _repo.getUpcoming(limit: 10, days: 30);
    } catch (e) {
      debugPrint('⚠️ [EventsProvider] Failed to load upcoming: $e');
      // Yaklaşan etkinlikler başarısız olsa bile devam et
    }

    // Ana liste veya arama
    try {
      if (state.searchQuery.length >= 2) {
        final list = await _repo.search(
          q: state.searchQuery,
          limit: 50,
          category: state.selectedType,
        );
        // Arama sonuçlarını da filtrele (ücretsiz filtresi)
        final filteredList = _applyFilters(list, null, state.showFreeOnly, state.dateRange);
        state = state.copyWith(
          items: filteredList,
          upcoming: upcoming,
          categories: categories,
          meta: null,
          isLoading: false,
        );
        return;
      }

      // Tüm etkinlikleri çek (sayfalama ile tüm sayfalar)
      final List<Event> allEvents = [];

      int page = 1;
      const int limit = 100; // API dokümanına göre max 100
      ApiMeta? meta;

      do {
        final response = await _repo.getEvents(
          page: page,
          limit: limit,
          order: 'ASC',
        );

        final pageItems = response.data ?? [];
        allEvents.addAll(pageItems);
        meta = response.meta;

        debugPrint(
          '✅ [EventsProvider] Page $page loaded: ${pageItems.length} items, '
          'total so far=${allEvents.length}, hasNext=${meta?.hasNext}',
        );

        page++;
      } while (meta?.hasNext == true);


      // Filtreleme yap
      final filteredItems = _applyFilters(allEvents, state.selectedType, state.showFreeOnly, state.dateRange);
      
      
      state = state.copyWith(
        allEvents: allEvents,
        items: filteredItems,
        meta: meta,
        upcoming: upcoming,
        categories: categories,
        isLoading: false,
      );
    } catch (e, stackTrace) {
      debugPrint('🔥 [EventsProvider] Failed to load events: $e');
      debugPrint('🔥 [EventsProvider] StackTrace: $stackTrace');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        // Kategoriler ve yaklaşan etkinlikler başarılı olduysa onları koru
        categories: categories.isNotEmpty ? categories : state.categories,
        upcoming: upcoming.isNotEmpty ? upcoming : state.upcoming,
      );
    }
  }

  /// Filtreleme fonksiyonu
  List<Event> _applyFilters(List<Event> events, String? type, bool showFreeOnly, DateTimeRange? dateRange) {
    var filtered = events;

    // Geçmiş etkinlikleri gizle — bugünden ÖNCE başlamış olanları çıkar.
    // `/events` listesi geçmiş+gelecek hepsini döndürür; etkinlik sayfasında
    // yalnız bugünkü ve ileri tarihliler gösterilmeli (kullanıcı talebi).
    // "Yaklaşan Etkinlikler" bölümü ayrıca `getUpcoming` ile besleniyor; bu
    // filtre "Tüm Etkinlikler" + arama sonuçları içindir.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    filtered = filtered.where((e) {
      final d = e.parsedStartDate;
      if (d == null) return true; // tarihi çözülemeyen etkinliği gizleme
      final day = DateTime(d.year, d.month, d.day);
      return !day.isBefore(today);
    }).toList();

    // Kategori filtresi
    if (type != null && type.isNotEmpty) {
      filtered = filtered.where((e) {
        final eventType = e.type.toUpperCase();
        final categoryLabel = e.categoryLabel?.toUpperCase() ?? '';
        final filterType = type.toUpperCase();
        return eventType == filterType || categoryLabel == filterType;
      }).toList();
    }
    
    // Ücretsiz filtresi
    if (showFreeOnly) {
      filtered = filtered.where((e) => e.isFree).toList();
    }
    
    // Tarih aralığı filtresi
    if (dateRange != null) {
      filtered = filtered.where((e) {
        final eventDate = e.parsedStartDate;
        if (eventDate == null) return false;
        
        final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
        final startDay = DateTime(dateRange.start.year, dateRange.start.month, dateRange.start.day);
        final endDay = DateTime(dateRange.end.year, dateRange.end.month, dateRange.end.day);
        
        return !eventDay.isBefore(startDay) && !eventDay.isAfter(endDay);
      }).toList();
    }

    return _sortEvents(filtered);
  }

  /// §6.4.5 — Seçili [EventSortMode]'a göre sırala.
  List<Event> _sortEvents(List<Event> events) {
    final sorted = List<Event>.of(events);
    int byName(Event a, Event b) =>
        a.title.toLowerCase().compareTo(b.title.toLowerCase());
    switch (state.sortMode) {
      case EventSortMode.name:
        sorted.sort(byName);
        return sorted;
      case EventSortMode.popularity:
        sorted.sort((a, b) {
          final byCount =
              (b.attendeeCount ?? 0).compareTo(a.attendeeCount ?? 0);
          if (byCount != 0) return byCount;
          return byName(a, b);
        });
        return sorted;
      case EventSortMode.date:
        // Yakın tarih → uzak; tarihi olmayanlar sona.
        sorted.sort((a, b) {
          final da = a.parsedStartDate;
          final db = b.parsedStartDate;
          if (da == null && db == null) return byName(a, b);
          if (da == null) return 1;
          if (db == null) return -1;
          final byDate = da.compareTo(db);
          return byDate != 0 ? byDate : byName(a, b);
        });
        return sorted;
    }
  }

  /// §6.4.5 — Sıralama tercihini değiştirir ve görüntülenen listeyi yeniden
  /// sıralar. Mevcut `items` üzerinde çalışır; böylece hem filtre hem de
  /// (server taraflı) arama sonuçları için doğru sonuç verir.
  void setSortMode(EventSortMode mode) {
    if (state.sortMode == mode) return;
    state = state.copyWith(sortMode: mode);
    state = state.copyWith(items: _sortEvents(state.items));
  }

  void setType(String? type) {
    if (state.selectedType == type) return;
    
    // Sadece filtreleme yap, API çağrısı yapma
    final filteredItems = _applyFilters(state.allEvents, type, state.showFreeOnly, state.dateRange);
    state = state.copyWith(
      selectedType: type,
      items: filteredItems,
    );
  }

  void setSearch(String query) {
    if (state.searchQuery == query) return;
    
    // Arama için API çağrısı yap (çünkü backend'de arama yapılıyor)
    state = state.copyWith(searchQuery: query, items: [], meta: null);
    if (query.length >= 2) {
      load(); // Arama için API çağrısı yap
    } else {
      // Arama temizlendi, filtreleme yap
      final filteredItems = _applyFilters(state.allEvents, state.selectedType, state.showFreeOnly, state.dateRange);
      state = state.copyWith(items: filteredItems);
    }
  }
  
  void toggleFreeOnly() {
    final newValue = !state.showFreeOnly;
    final filteredItems = _applyFilters(state.allEvents, state.selectedType, newValue, state.dateRange);
    state = state.copyWith(
      showFreeOnly: newValue,
      items: filteredItems,
    );
  }
  
  void setDateRange(DateTimeRange? range) {
    if (state.dateRange == range) return;
    
    final filteredItems = _applyFilters(state.allEvents, state.selectedType, state.showFreeOnly, range);
    state = state.copyWith(
      dateRange: range,
      clearDateRange: range == null,
      items: filteredItems,
    );
  }

  Future<void> loadMore() async {
    // Artık sayfalama yok, tüm etkinlikler bir kerede çekiliyor
    // Bu metod artık kullanılmıyor ama interface uyumluluğu için bırakıyoruz
    return;
  }

  Future<void> refresh() => load(refresh: true);
}

final eventsListProvider =
    NotifierProvider<EventsListNotifier, EventsListState>(EventsListNotifier.new);

/// Tek etkinlik detayı
final eventDetailProvider =
    FutureProvider.family<Event?, String>((ref, id) async {
  final repo = ref.watch(eventRepositoryProvider);
  return repo.getEvent(id);
});
