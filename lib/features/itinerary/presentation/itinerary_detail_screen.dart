import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../api/api_client.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../core/widgets/cached_image.dart';
import '../../../data/models/models.dart';
import '../../places/presentation/providers/places_provider.dart';
import 'providers/itineraries_provider.dart';

/// Şartname §6.5.2 — Tek bir gezi planının detayı: durakları sıralı listele,
/// yeniden sırala, sil, yeni durak ekle, tarih/saat ata.
class ItineraryDetailScreen extends ConsumerStatefulWidget {
  const ItineraryDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<ItineraryDetailScreen> createState() =>
      _ItineraryDetailScreenState();
}

class _ItineraryDetailScreenState extends ConsumerState<ItineraryDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Liste endpoint'i sadece özet (items_count) dönüyor, durakları getirmek
    // için detay endpoint'ini tetikle. State'te plan zaten varsa items'i
    // güncel hâliyle yerine koyar (items dolu liste).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(itinerariesProvider.notifier).loadDetail(widget.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final itinerary = ref.watch(itineraryByIdProvider(widget.id));

    if (itinerary == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(context.l10n.itineraryNotFound)),
      );
    }

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(itinerary.title,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        actions: [
          if (itinerary.items.isNotEmpty)
            IconButton(
              tooltip: context.l10n.btnShowOnMap,
              icon: const Icon(Icons.map_rounded),
              onPressed: () => context.push('/itinerary/${widget.id}/map'),
            ),
          IconButton(
            tooltip: context.l10n.itineraryRename,
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => _renameDialog(context, ref, itinerary),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddItemSheet(context, ref, itinerary.id),
        icon: const Icon(Icons.add_location_alt_rounded),
        label: Text(context.l10n.itineraryAddPlace),
      ),
      body: itinerary.items.isEmpty
          ? const _EmptyState()
          : _buildList(context, ref, itinerary, isDark),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    Itinerary itinerary,
    bool isDark,
  ) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: itinerary.items.length,
      onReorder: (oldIndex, newIndex) async {
        final ordered = [...itinerary.items];
        if (newIndex > oldIndex) newIndex -= 1;
        final moved = ordered.removeAt(oldIndex);
        ordered.insert(newIndex, moved);
        await ref.read(itinerariesProvider.notifier).reorderItems(
              itinerary.id,
              ordered.map((e) => e.id).toList(),
            );
      },
      proxyDecorator: (child, _, _) => Material(
        color: Colors.transparent,
        elevation: 4,
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
      itemBuilder: (context, index) {
        final item = itinerary.items[index];
        return _ItineraryItemCard(
          key: ValueKey(item.id),
          itineraryId: itinerary.id,
          item: item,
          index: index,
          isDark: isDark,
        );
      },
    );
  }

  Future<void> _renameDialog(
      BuildContext context, WidgetRef ref, Itinerary current) async {
    final controller = TextEditingController(text: current.title);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.itineraryRenameTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: context.l10n.itineraryNewName),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(context.l10n.btnGiveUp)),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: Text(context.l10n.btnSave)),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    await ref.read(itinerariesProvider.notifier).renameItinerary(
          current.id,
          result,
        );
  }

  Future<void> _showAddItemSheet(
      BuildContext context, WidgetRef ref, String itineraryId) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurface
          : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) =>
          _AddItemSheet(itineraryId: itineraryId),
    );
  }
}

class _ItineraryItemCard extends ConsumerWidget {
  const _ItineraryItemCard({
    super.key,
    required this.itineraryId,
    required this.item,
    required this.index,
    required this.isDark,
  });

  final String itineraryId;
  final ItineraryItem item;
  final int index;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Padding(
      key: ValueKey('pad-${item.id}'),
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border:
              isDark ? Border.all(color: Colors.white.withAlpha(15)) : null,
          boxShadow: isDark ? null : AppElevation.level1,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openDetail(context),
            child: Row(
          children: [
            Container(
              width: 32,
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.neonBlue
                      : theme.colorScheme.primary,
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 56,
                height: 56,
                child: item.entityImageUrl != null &&
                        item.entityImageUrl!.isNotEmpty
                    ? CachedImage(
                        imageUrl: item.entityImageUrl!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: isDark
                            ? AppColors.darkSurfaceElevated
                            : Colors.grey[200],
                        child: Icon(
                          item.entityType == ItineraryEntityType.event
                              ? Icons.event_rounded
                              : Icons.place_rounded,
                          color: isDark
                              ? AppColors.neonBlue.withAlpha(120)
                              : Colors.grey,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.entityName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 14, color: theme.hintColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _pickVisitAt(context, ref),
                            child: Text(
                              item.visitAt != null
                                  ? _fmtDateTime(item.visitAt!)
                                  : 'Tarih/saat ekle',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: item.visitAt != null
                                    ? (isDark
                                        ? Colors.white.withAlpha(180)
                                        : theme.colorScheme.onSurface)
                                    : theme.hintColor,
                                fontWeight: item.visitAt != null
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: context.l10n.btnRemove,
              onPressed: () => ref
                  .read(itinerariesProvider.notifier)
                  .removeItem(itineraryId, item.id),
              icon: Icon(Icons.close_rounded, color: theme.hintColor),
            ),
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.drag_handle_rounded,
                    color: theme.hintColor),
              ),
            ),
          ],
            ),
          ),
        ),
      ),
    );
  }

  /// Karta tıklayınca ilgili yerin/etkinliğin detay sayfasına gider.
  /// `push` kullanıldığı için geri dönüldüğünde tekrar gezi planına döner.
  void _openDetail(BuildContext context) {
    switch (item.entityType) {
      case ItineraryEntityType.place:
        context.push('/places/${item.entityId}');
      case ItineraryEntityType.event:
        context.push('/events/${item.entityId}');
    }
  }

  Future<void> _pickVisitAt(BuildContext context, WidgetRef ref) async {
    final initialDate = item.visitAt ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (pickedDate == null || !context.mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (pickedTime == null) return;
    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    await ref.read(itinerariesProvider.notifier).updateItem(
          itineraryId,
          item.copyWith(visitAt: combined),
        );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_location_outlined,
                size: 56, color: theme.hintColor.withAlpha(120)),
            const SizedBox(height: 12),
            Text(context.l10n.itineraryNoStops,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                )),
            const SizedBox(height: 6),
            Text(
              'Aşağıdaki "Mekan Ekle" butonunu kullanarak rotaya yer veya etkinlik ekleyebilirsiniz.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.hintColor.withAlpha(180)),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Add-item sheet — places önbelleğinden seçim
// ═══════════════════════════════════════════════════════════════════════

class _AddItemSheet extends ConsumerStatefulWidget {
  const _AddItemSheet({required this.itineraryId});

  final String itineraryId;

  @override
  ConsumerState<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends ConsumerState<_AddItemSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final places = ref.watch(placesProvider.select((s) => s.allPlaces));
    final lower = _query.trim().toLowerCase();
    final filtered = lower.isEmpty
        ? places
        : places
            .where((p) =>
                p.name.toLowerCase().contains(lower) ||
                (p.category ?? '').toLowerCase().contains(lower))
            .toList();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final baseUrl = ApiConfig.current.baseUrl;

    return Padding(
      padding: EdgeInsets.fromLTRB(0, 12, 0, bottomInset),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
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
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(context.l10n.itinerarySelectPlace,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  Text('${filtered.length}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.hintColor)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: context.l10n.itinerarySearchPlace,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: places.isEmpty
                  ? Center(
                      child: Text(
                        'Mekanlar henüz yüklenmedi. Yerler sekmesini ziyaret edip tekrar deneyin.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.hintColor),
                      ),
                    )
                  : ListView.separated(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final place = filtered[index];
                        final imageUrl = buildImageUrl(
                          place.imageUrl ?? '',
                          baseUrl: baseUrl,
                        );
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: imageUrl != null
                                  ? CachedImage(
                                      imageUrl: imageUrl,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      color: isDark
                                          ? AppColors.darkSurfaceElevated
                                          : Colors.grey[200],
                                      child: Icon(Icons.place,
                                          color: theme.hintColor),
                                    ),
                            ),
                          ),
                          title: Text(place.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          subtitle: Text(place.category ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          trailing: const Icon(Icons.add_rounded),
                          onTap: () async {
                            final draft = ItineraryItem(
                              id: '',
                              entityType: ItineraryEntityType.place,
                              entityId: place.id,
                              entityName: place.name,
                              entityImageUrl: imageUrl,
                              sortOrder: 0,
                            );
                            await ref
                                .read(itinerariesProvider.notifier)
                                .addItem(widget.itineraryId, draft);
                            if (context.mounted) Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmtDateTime(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.day)}.${two(dt.month)}.${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
}
