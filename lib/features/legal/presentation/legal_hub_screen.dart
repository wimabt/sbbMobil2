import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design_tokens.dart';
import '../data/legal_documents.dart';
import '../providers/legal_documents_provider.dart';

/// Yasal belgeler merkezi (§10.6.3, §14.2.3) — `/legal`.
///
/// Aydınlatma Metni, Açık Rıza, Gizlilik Politikası ve Kullanım Koşulları
/// buradan görüntülenir. Profil → "Yasal" ve kayıt ekranındaki bağlantılar
/// bu ekrana yönlendirir.
class LegalHubScreen extends ConsumerWidget {
  const LegalHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Yayımlanmış metinler backend'den (OTA). Boş/yükleniyor → koda gömülü fallback.
    final remote = ref.watch(legalDocumentsProvider).maybeWhen(
          data: (m) => m,
          orElse: () => const <String, RemoteLegalDoc>{},
        );

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Yasal'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          Text(
            'Kişisel verilerinizin korunmasına ilişkin metinler ve kullanım '
            'koşulları aşağıda yer alır.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.hintColor,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final fallback in kLegalDocuments)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _LegalCard(
                doc: resolveLegalDocument(fallback, remote[fallback.id]),
                isDark: isDark,
              ),
            ),
        ],
      ),
    );
  }
}

class _LegalCard extends StatelessWidget {
  const _LegalCard({required this.doc, required this.isDark});

  final LegalDocument doc;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent =
        isDark ? AppColors.brandGreenBright : theme.colorScheme.primary;

    return Material(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/legal/${doc.id}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(doc.icon, color: accent, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            doc.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (doc.isDraft) ...[
                          const SizedBox(width: 8),
                          const _DraftBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      doc.summary,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Taslak" rozeti — metin İdare onayı beklerken gösterilir.
class _DraftBadge extends StatelessWidget {
  const _DraftBadge();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? AppColors.neonOrange : AppColors.warningDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Text(
        'Taslak',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: c,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
