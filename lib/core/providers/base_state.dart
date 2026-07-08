/// Base state class for feature states with common patterns
/// Provides loading, error, success states with data
abstract class BaseState<T> {
  const BaseState();

  /// Initial state
  factory BaseState.initial() => InitialState<T>();

  /// Loading state
  factory BaseState.loading() => LoadingState<T>();

  /// Success state with data
  factory BaseState.success(T data) => SuccessState<T>(data);

  /// Error state with message
  factory BaseState.error(String message, [Object? error]) =>
      ErrorState<T>(message, error);

  bool get isInitial => this is InitialState<T>;
  bool get isLoading => this is LoadingState<T>;
  bool get isSuccess => this is SuccessState<T>;
  bool get isError => this is ErrorState<T>;

  /// Get data if success, otherwise null
  T? get data => isSuccess ? (this as SuccessState<T>).data : null;

  /// Get error message if error, otherwise null
  String? get errorMessage => isError ? (this as ErrorState<T>).message : null;

  /// Pattern matching helper
  R when<R>({
    required R Function() initial,
    required R Function() loading,
    required R Function(T data) success,
    required R Function(String message, Object? error) error,
  }) {
    if (this is InitialState<T>) return initial();
    if (this is LoadingState<T>) return loading();
    if (this is SuccessState<T>) return success((this as SuccessState<T>).data);
    if (this is ErrorState<T>) {
      final e = this as ErrorState<T>;
      return error(e.message, e.error);
    }
    throw StateError('Unknown state type');
  }

  /// Pattern matching with optional handlers
  R maybeWhen<R>({
    R Function()? initial,
    R Function()? loading,
    R Function(T data)? success,
    R Function(String message, Object? error)? error,
    required R Function() orElse,
  }) {
    if (this is InitialState<T> && initial != null) return initial();
    if (this is LoadingState<T> && loading != null) return loading();
    if (this is SuccessState<T> && success != null) {
      return success((this as SuccessState<T>).data);
    }
    if (this is ErrorState<T> && error != null) {
      final e = this as ErrorState<T>;
      return error(e.message, e.error);
    }
    return orElse();
  }
}

class InitialState<T> extends BaseState<T> {
  const InitialState();
}

class LoadingState<T> extends BaseState<T> {
  const LoadingState();
}

class SuccessState<T> extends BaseState<T> {
  const SuccessState(this.data);
  @override
  final T data;
}

class ErrorState<T> extends BaseState<T> {
  const ErrorState(this.message, [this.error]);
  final String message;
  final Object? error;
}

/// Paginated list state for features with pagination
class PaginatedState<T> {
  const PaginatedState({
    this.items = const [],
    this.page = 1,
    this.totalPages = 1,
    this.total = 0,
    this.hasNext = false,
    this.hasPrev = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
  });

  final List<T> items;
  final int page;
  final int totalPages;
  final int total;
  final bool hasNext;
  final bool hasPrev;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;

  bool get isEmpty => items.isEmpty && !isLoading;
  bool get hasData => items.isNotEmpty;

  PaginatedState<T> copyWith({
    List<T>? items,
    int? page,
    int? totalPages,
    int? total,
    bool? hasNext,
    bool? hasPrev,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
  }) {
    return PaginatedState(
      items: items ?? this.items,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      total: total ?? this.total,
      hasNext: hasNext ?? this.hasNext,
      hasPrev: hasPrev ?? this.hasPrev,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
    );
  }
}

/// Filter state for features with filtering capability
class FilterState<T> {
  const FilterState({
    this.selectedCategory,
    this.searchQuery = '',
    this.sortBy,
    this.filters = const {},
  });

  final T? selectedCategory;
  final String searchQuery;
  final String? sortBy;
  final Map<String, dynamic> filters;

  bool get hasActiveFilters =>
      selectedCategory != null ||
      searchQuery.isNotEmpty ||
      sortBy != null ||
      filters.isNotEmpty;

  FilterState<T> copyWith({
    T? selectedCategory,
    String? searchQuery,
    String? sortBy,
    Map<String, dynamic>? filters,
    bool clearCategory = false,
    bool clearSort = false,
  }) {
    return FilterState(
      selectedCategory:
          clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      searchQuery: searchQuery ?? this.searchQuery,
      sortBy: clearSort ? null : (sortBy ?? this.sortBy),
      filters: filters ?? this.filters,
    );
  }

  FilterState<T> clear() {
    return const FilterState();
  }
}
