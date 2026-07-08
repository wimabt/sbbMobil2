import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/widgets/cached_image.dart';
import '../../../data/models/blog.dart';
import '../../../l10n/l10n.dart';
import 'providers/blog_provider.dart';

/// Blog yazısı detay ekranı.
///
/// [slugOrId] ile [blogDetailProvider]'dan çekilir. Listeden gelirken [post]
/// extra olarak verilirse anında gösterilir, içerik arkada tazelenir.
class BlogDetailScreen extends ConsumerWidget {
  const BlogDetailScreen({super.key, required this.slugOrId, this.post});

  final String slugOrId;
  final BlogPost? post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(blogDetailProvider(slugOrId));

    return Scaffold(
      body: async.when(
        loading: () => _ScaffoldBody(
          post: post,
          loading: true,
          child: const Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => _ErrorView(
          onRetry: () => ref.invalidate(blogDetailProvider(slugOrId)),
        ),
        data: (data) {
          final p = data ?? post;
          if (p == null) {
            return _ErrorView(
              onRetry: () => ref.invalidate(blogDetailProvider(slugOrId)),
            );
          }
          return _BlogContent(post: p);
        },
      ),
    );
  }
}

class _ScaffoldBody extends StatelessWidget {
  const _ScaffoldBody({this.post, required this.child, this.loading = false});
  final BlogPost? post;
  final Widget child;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const _TopBar(),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}

class _BlogContent extends StatelessWidget {
  const _BlogContent({required this.post});
  final BlogPost post;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final primary = Theme.of(context).colorScheme.primary;
    final metaColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : const Color(0xFF6B6B7B);
    final content = post.content ?? post.excerpt ?? '';

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: post.coverImageUrl != null && post.coverImageUrl!.isNotEmpty ? 240 : 0,
          pinned: true,
          leading: const BackButton(),
          flexibleSpace: post.coverImageUrl != null && post.coverImageUrl!.isNotEmpty
              ? FlexibleSpaceBar(
                  background: CachedImage(
                    imageUrl: post.coverImageUrl!,
                    fit: BoxFit.cover,
                  ),
                )
              : null,
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.categoryName != null && post.categoryName!.isNotEmpty)
                  Text(
                    post.categoryName!.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: primary,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 12),
                // Meta satırı: yazar · tarih · okuma süresi · görüntülenme
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (post.authorName != null && post.authorName!.isNotEmpty)
                      _MetaChip(icon: Icons.person_outline_rounded, label: post.authorName!, color: metaColor),
                    if (post.publishedAt != null)
                      _MetaChip(icon: Icons.calendar_today_rounded, label: _formatDate(post.publishedAt!), color: metaColor),
                    if (post.readTimeMin != null)
                      _MetaChip(
                        icon: Icons.schedule_rounded,
                        label: l10n.blogReadMinutes(post.readTimeMin!),
                        color: metaColor,
                      ),
                    _MetaChip(icon: Icons.visibility_outlined, label: '${post.viewCount}', color: metaColor),
                  ],
                ),
                const SizedBox(height: 20),
                if (content.isNotEmpty)
                  Html(
                    data: content,
                    style: {
                      'body': Style(
                        color: isDark ? Colors.white.withAlpha(220) : null,
                        lineHeight: const LineHeight(1.7),
                        fontSize: FontSize(15.5),
                        margin: Margins.zero,
                        padding: HtmlPaddings.zero,
                      ),
                      'p': Style(margin: Margins.only(bottom: 16)),
                      'ul': Style(margin: Margins.only(left: 16, bottom: 16)),
                      'ol': Style(margin: Margins.only(left: 16, bottom: 16)),
                      'li': Style(margin: Margins.only(bottom: 8)),
                      'h1': Style(fontSize: FontSize(22), fontWeight: FontWeight.bold, margin: Margins.only(top: 24, bottom: 12)),
                      'h2': Style(fontSize: FontSize(20), fontWeight: FontWeight.bold, margin: Margins.only(top: 20, bottom: 10)),
                      'h3': Style(fontSize: FontSize(18), fontWeight: FontWeight.w600, margin: Margins.only(top: 16, bottom: 8)),
                      'a': Style(color: primary, textDecoration: TextDecoration.underline),
                      'strong': Style(fontWeight: FontWeight.w700),
                      'img': Style(width: Width(100, Unit.percent)),
                    },
                  )
                else
                  Text(post.excerpt ?? '', style: TextStyle(fontSize: 15, color: metaColor, height: 1.6)),
                if (post.tags.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: post.tags
                        .map((t) => Chip(
                              label: Text('#${t.name}'),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : const Color(0xFFF0F2F5),
                              side: BorderSide.none,
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _formatDate(DateTime d) {
    const months = [
      'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
      'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
    ];
    final local = d.toLocal();
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const _TopBar(),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(context.l10n.blogEmpty),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: onRetry, child: Text(context.l10n.btnRetry)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
