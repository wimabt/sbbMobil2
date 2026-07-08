import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/widgets/cached_image.dart';
import '../../../data/models/blog.dart';
import '../../../l10n/l10n.dart';
import 'providers/blog_provider.dart';

/// Şehir Rehberi & Blog liste ekranı — kategori filtresi + arama + sonsuz kaydırma.
class BlogListScreen extends ConsumerStatefulWidget {
  const BlogListScreen({super.key});

  @override
  ConsumerState<BlogListScreen> createState() => _BlogListScreenState();
}

class _BlogListScreenState extends ConsumerState<BlogListScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      ref.read(blogListProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(blogListProvider);
    final notifier = ref.read(blogListProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.titleBlog)),
      body: Column(
        children: [
          // Arama
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.blogSearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              onSubmitted: notifier.search,
            ),
          ),
          // Kategori çipleri
          if (state.categories.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                children: [
                  _CategoryChip(
                    label: l10n.lblAll,
                    selected: state.selectedCategorySlug == null,
                    onTap: () => notifier.setCategory(null),
                  ),
                  ...state.categories.map((c) => _CategoryChip(
                        label: c.name,
                        selected: state.selectedCategorySlug == c.slug,
                        onTap: () => notifier.setCategory(c.slug),
                      )),
                ],
              ),
            ),
          Expanded(child: _buildBody(context, state, notifier)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, BlogListState state, BlogListNotifier notifier) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            FilledButton(onPressed: notifier.refresh, child: Text(context.l10n.btnRetry)),
          ],
        ),
      );
    }
    if (state.posts.isEmpty) {
      return Center(child: Text(context.l10n.blogEmpty));
    }

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: state.posts.length + (state.isLoadingMore ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          if (index >= state.posts.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final post = state.posts[index];
          return _BlogListCard(
            post: post,
            onTap: () => context.push('/blog/${post.slug}', extra: post),
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _BlogListCard extends StatelessWidget {
  const _BlogListCard({required this.post, required this.onTap});
  final BlogPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final metaColor = isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF6B6B7B);
    final img = post.displayImageUrl;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.08)) : null,
            boxShadow: isDark
                ? null
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (img.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
                  child: CachedImage(
                    imageUrl: img,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (post.categoryName != null && post.categoryName!.isNotEmpty)
                      Text(
                        post.categoryName!.toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.7, color: primary),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      post.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.25, color: titleColor),
                    ),
                    if (post.excerpt != null && post.excerpt!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        post.excerpt!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, height: 1.4, color: metaColor),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (post.readTimeMin != null) ...[
                          Icon(Icons.schedule_rounded, size: 13, color: metaColor),
                          const SizedBox(width: 4),
                          Text(context.l10n.blogReadMinutes(post.readTimeMin!),
                              style: TextStyle(fontSize: 11, color: metaColor, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 12),
                        ],
                        Icon(Icons.visibility_outlined, size: 13, color: metaColor),
                        const SizedBox(width: 4),
                        Text('${post.viewCount}', style: TextStyle(fontSize: 11, color: metaColor, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
