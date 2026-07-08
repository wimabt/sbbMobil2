import 'package:flutter/material.dart';

/// Mixin for optimized scroll-based collapsing AppBar animations.
/// 
/// This mixin uses ValueNotifier to avoid full widget rebuilds on scroll.
/// Only widgets wrapped with [buildCollapsingWidget] will rebuild.
/// 
/// Usage:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with CollapsingScrollMixin {
///   @override
///   void initState() {
///     super.initState();
///     initScrollController();
///   }
///
///   @override
///   void dispose() {
///     disposeScrollController();
///     super.dispose();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return CustomScrollView(
///       controller: scrollController,
///       slivers: [
///         SliverAppBar(
///           title: buildCollapsingTitle(
///             context,
///             title: 'My Title',
///             visibilityThreshold: 0.8,
///           ),
///         ),
///       ],
///     );
///   }
/// }
/// ```
mixin CollapsingScrollMixin<T extends StatefulWidget> on State<T> {
  late final ScrollController scrollController;
  late final ValueNotifier<double> _scrollOffsetNotifier;

  /// Standard expanded height for the AppBar
  double get expandedHeight => 280.0;

  /// Initialize scroll controller and notifier. Call this in initState.
  @protected
  void initScrollController() {
    _scrollOffsetNotifier = ValueNotifier<double>(0.0);
    scrollController = ScrollController()
      ..addListener(_onScroll);
  }

  /// Dispose scroll controller and notifier. Call this in dispose.
  @protected
  void disposeScrollController() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    _scrollOffsetNotifier.dispose();
  }

  void _onScroll() {
    _scrollOffsetNotifier.value = scrollController.offset;
  }

  /// Calculate collapse ratio (0 = fully expanded, 1 = fully collapsed)
  double _calculateCollapseRatio(double scrollOffset, BuildContext context) {
    final collapsedHeight = MediaQuery.of(context).padding.top + kToolbarHeight;
    final maxScroll = expandedHeight - collapsedHeight;
    return (scrollOffset / maxScroll).clamp(0.0, 1.0);
  }

  /// Build a widget that rebuilds only when collapse ratio changes.
  /// Use this for elements that depend on scroll position.
  Widget buildCollapsingWidget({
    required Widget Function(BuildContext context, double collapseRatio) builder,
  }) {
    return ValueListenableBuilder<double>(
      valueListenable: _scrollOffsetNotifier,
      builder: (context, scrollOffset, _) {
        final collapseRatio = _calculateCollapseRatio(scrollOffset, context);
        return builder(context, collapseRatio);
      },
    );
  }

  /// Build a title that fades in when the AppBar is collapsed.
  /// [visibilityThreshold] determines when the title starts appearing (default: 0.8)
  Widget buildCollapsingTitle(
    BuildContext context, {
    required String title,
    double visibilityThreshold = 0.8,
  }) {
    return ValueListenableBuilder<double>(
      valueListenable: _scrollOffsetNotifier,
      builder: (context, scrollOffset, child) {
        final collapseRatio = _calculateCollapseRatio(scrollOffset, context);
        return AnimatedOpacity(
          opacity: collapseRatio > visibilityThreshold ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: child,
        );
      },
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  /// Build the flexible space content that fades out and translates as user scrolls.
  Widget buildFlexibleContent({
    required Widget child,
    double fadeMultiplier = 1.5,
    double translateMultiplier = 20,
  }) {
    return ValueListenableBuilder<double>(
      valueListenable: _scrollOffsetNotifier,
      builder: (context, scrollOffset, _) {
        final collapseRatio = _calculateCollapseRatio(scrollOffset, context);
        return AnimatedOpacity(
          opacity: (1.0 - collapseRatio * fadeMultiplier).clamp(0.0, 1.0),
          duration: const Duration(milliseconds: 100),
          child: Transform.translate(
            offset: Offset(0, collapseRatio * translateMultiplier),
            child: child,
          ),
        );
      },
    );
  }
}

