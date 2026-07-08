import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/locale_provider.dart';
import '../../../../data/models/models.dart';
import '../../../../data/repositories/repositories.dart';

/// Blog liste ekranı durumu.
class BlogListState {
  const BlogListState({
    this.posts = const [],
    this.categories = const [],
    this.selectedCategorySlug,
    this.searchQuery = '',
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.page = 1,
    this.totalPages = 1,
    this.hasMore = false,
  });

  final List<BlogPost> posts;
  final List<BlogCategory> categories;
  final String? selectedCategorySlug;
  final String searchQuery;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int page;
  final int totalPages;
  final bool hasMore;

  BlogListState copyWith({
    List<BlogPost>? posts,
    List<BlogCategory>? categories,
    String? selectedCategorySlug,
    bool clearCategory = false,
    String? searchQuery,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
    int? page,
    int? totalPages,
    bool? hasMore,
  }) {
    return BlogListState(
      posts: posts ?? this.posts,
      categories: categories ?? this.categories,
      selectedCategorySlug:
          clearCategory ? null : (selectedCategorySlug ?? this.selectedCategorySlug),
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class BlogListNotifier extends Notifier<BlogListState> {
  late BlogRepository _repo;
  String? _lastLang;

  String get _lang =>
      ref.read(localeProvider.select((s) => s.locale.languageCode));

  @override
  BlogListState build() {
    _repo = ref.watch(blogRepositoryProvider);
    final lang = ref.watch(localeProvider.select((s) => s.locale.languageCode));
    if (_lastLang == null || _lastLang != lang) {
      _lastLang = lang;
      Future.microtask(loadInitial);
    }
    return const BlogListState(isLoading: true);
  }

  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await Future.wait([
        _repo.getCategories(lang: _lang),
        _repo.getPosts(
          page: 1,
          limit: 20,
          lang: _lang,
          category: state.selectedCategorySlug,
          search: state.searchQuery,
        ),
      ]);
      final categories = results[0] as List<BlogCategory>;
      final resp = results[1] as ApiResponse<List<BlogPost>>;
      state = state.copyWith(
        categories: categories,
        posts: resp.data ?? const [],
        isLoading: false,
        page: 1,
        totalPages: resp.meta?.totalPages ?? 1,
        hasMore: (resp.meta?.totalPages ?? 1) > 1,
      );
    } catch (e) {
      debugPrint('❌ [BlogListNotifier] loadInitial: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final next = state.page + 1;
      final resp = await _repo.getPosts(
        page: next,
        limit: 20,
        lang: _lang,
        category: state.selectedCategorySlug,
        search: state.searchQuery,
      );
      state = state.copyWith(
        posts: [...state.posts, ...(resp.data ?? const [])],
        page: next,
        totalPages: resp.meta?.totalPages ?? state.totalPages,
        hasMore: next < (resp.meta?.totalPages ?? state.totalPages),
        isLoadingMore: false,
      );
    } catch (e) {
      debugPrint('❌ [BlogListNotifier] loadMore: $e');
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void setCategory(String? slug) {
    if (state.selectedCategorySlug == slug) return;
    state = state.copyWith(
      selectedCategorySlug: slug,
      clearCategory: slug == null,
    );
    loadInitial();
  }

  void search(String query) {
    state = state.copyWith(searchQuery: query);
    loadInitial();
  }

  Future<void> refresh() => loadInitial();
}

final blogListProvider =
    NotifierProvider<BlogListNotifier, BlogListState>(BlogListNotifier.new);

/// Ana sayfa «Şehir Rehberi & Blog» önizleme verisi.
/// Öne çıkanları getirir; yoksa en son yayınlananlara düşer.
final homeBlogPreviewProvider =
    FutureProvider.autoDispose<List<BlogPost>>((ref) async {
  final repo = ref.watch(blogRepositoryProvider);
  final lang = ref.watch(localeProvider.select((s) => s.locale.languageCode));
  try {
    final featured = await repo.getFeatured(limit: 6, lang: lang);
    if (featured.isNotEmpty) return featured;
    final resp = await repo.getPosts(page: 1, limit: 6, lang: lang);
    return resp.data ?? const [];
  } catch (e) {
    debugPrint('❌ [homeBlogPreviewProvider] $e');
    return const [];
  }
});

/// Tek yazı detayı. Yüklenince görüntülenme kaydı (best-effort) atılır.
final blogDetailProvider =
    FutureProvider.autoDispose.family<BlogPost?, String>((ref, slugOrId) async {
  final repo = ref.watch(blogRepositoryProvider);
  final lang = ref.watch(localeProvider.select((s) => s.locale.languageCode));
  final post = await repo.getPost(slugOrId, lang: lang);
  if (post != null) {
    repo.recordView(post.id);
  }
  return post;
});
