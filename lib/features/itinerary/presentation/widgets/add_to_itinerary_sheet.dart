import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/design_tokens.dart';
import '../../../../data/models/models.dart';
import '../providers/itineraries_provider.dart';

/// Şartname §6.5.2 — Place / Event detayından gezi planına ekleme akışı.
///
/// Bottom sheet:
///   • Üst kısımda mevcut planların listesi.
///   • İlk satır: "+ Yeni Plan Oluştur" — başlık girip eklemeden önce yeni
///     plan üretir.
///   • Bir plana dokunulduğunda place / event bir item olarak eklenir,
///     sheet kapanır, success snackbar gösterilir.
class AddToItinerarySheet extends ConsumerStatefulWidget {
  const AddToItinerarySheet({
    super.key,
    required this.entityId,
    required this.entityName,
    required this.entityType,
    this.entityImageUrl,
  });

  final String entityId;
  final String entityName;
  final ItineraryEntityType entityType;
  final String? entityImageUrl;

  /// Convenience launcher.
  static Future<void> show(
    BuildContext context, {
    required String entityId,
    required String entityName,
    required ItineraryEntityType entityType,
    String? entityImageUrl,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurface
          : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => AddToItinerarySheet(
        entityId: entityId,
        entityName: entityName,
        entityType: entityType,
        entityImageUrl: entityImageUrl,
      ),
    );
  }

  @override
  ConsumerState<AddToItinerarySheet> createState() =>
      _AddToItinerarySheetState();
}

class _AddToItinerarySheetState extends ConsumerState<AddToItinerarySheet> {
  bool _busy = false;

  Future<void> _addTo(String itineraryId) async {
    if (_busy) return;
    setState(() => _busy = true);
    final draft = ItineraryItem(
      id: '',
      entityType: widget.entityType,
      entityId: widget.entityId,
      entityName: widget.entityName,
      entityImageUrl: widget.entityImageUrl,
      sortOrder: 0,
    );
    final updated = await ref
        .read(itinerariesProvider.notifier)
        .addItem(itineraryId, draft);
    if (!mounted) return;
    Navigator.of(context).pop();
    final success = updated != null;

    // Hata mesajını kullanıcıya göster — generic "eklenemedi" yetersiz.
    final errorMsg = success
        ? null
        : (ref.read(itinerariesProvider).error ?? 'bilinmeyen hata');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? '"${widget.entityName}" plana eklendi'
            : 'Plana eklenemedi: $errorMsg'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: success ? 2 : 4),
      ),
    );
  }

  Future<void> _createAndAdd() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.itineraryNewButton),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: context.l10n.itineraryNameLabel),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(context.l10n.btnGiveUp)),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: Text(context.l10n.btnCreate)),
        ],
      ),
    );
    if (title == null || title.isEmpty) return;
    final created = await ref
        .read(itinerariesProvider.notifier)
        .createItinerary(title: title);
    if (created == null) return;
    await _addTo(created.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final list = ref.watch(itinerariesProvider.select((s) => s.items));
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(0, 12, 0, bottomInset),
      child: SizedBox(
        height: MediaQuery.of(context).size.height *
            (list.isEmpty ? 0.4 : 0.65),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.hintColor.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Bir Plana Ekle',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: const Icon(Icons.add_rounded),
                    title: Text(context.l10n.itineraryNewTitle),
                    onTap: _busy ? null : _createAndAdd,
                  ),
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                      child: Text(
                        'Henüz bir gezi planınız yok. Yukarıdan yeni plan oluşturup buraya ekleyebilirsiniz.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.hintColor),
                      ),
                    ),
                  for (final it in list)
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primaryContainer,
                        ),
                        child: Icon(Icons.map_rounded,
                            color: theme.colorScheme.primary),
                      ),
                      title: Text(it.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${it.displayItemCount} durak'),
                      trailing: const Icon(Icons.add_rounded),
                      onTap: _busy ? null : () => _addTo(it.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
