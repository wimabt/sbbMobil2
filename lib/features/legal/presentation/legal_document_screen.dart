import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_tokens.dart';
import '../data/legal_documents.dart';
import '../providers/legal_documents_provider.dart';

/// Tek bir yasal belgeyi gösterir — `/legal/:docId`.
class LegalDocumentScreen extends ConsumerWidget {
  const LegalDocumentScreen({super.key, required this.docId});

  final String docId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Yayımlanmış metni backend'den (OTA) çek; yoksa koda gömülü fallback.
    final fallback = legalDocumentById(docId);
    final remote = ref.watch(legalDocumentsProvider).maybeWhen(
          data: (m) => m[docId],
          orElse: () => null,
        );
    final doc = fallback == null ? null : resolveLegalDocument(fallback, remote);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(doc?.title ?? 'Belge'),
      ),
      body: doc == null
          ? Center(child: Text(context.l10n.docNotFound))
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              children: [
                if (doc.isDraft) _DraftNotice(isDark: isDark),
                for (final section in doc.sections)
                  _SectionView(section: section),
                const SizedBox(height: AppSpacing.lg),
                Divider(
                  color: theme.dividerColor.withValues(alpha: 0.4),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Son güncelleme: ${doc.lastUpdated}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
    );
  }
}

/// Taslak metin uyarısı — İdare onayı beklendiğini açıkça belirtir.
class _DraftNotice extends StatelessWidget {
  const _DraftNotice({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final c = isDark ? AppColors.neonOrange : AppColors.warningDark;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.withValues(alpha: isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: c, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Bu metin taslaktır ve İdare onayı sonrası nihai hale getirilecektir.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: c,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionView extends StatelessWidget {
  const _SectionView({required this.section});

  final LegalSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (section.heading != null) ...[
            Text(
              section.heading!,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            section.body,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.55,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
