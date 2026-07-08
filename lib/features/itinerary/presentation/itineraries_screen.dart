import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design_tokens.dart';
import '../../../data/models/models.dart';
import '../../../l10n/l10n.dart';
import 'providers/itineraries_provider.dart';

/// Şartname §6.5.2 — Kullanıcının gezi planlarının listelendiği ekran.
class ItinerariesScreen extends ConsumerWidget {
  const ItinerariesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(itinerariesProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(context.l10n.settingsItineraries,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.l10n.itineraryNewButton),
      ),
      body: _buildBody(context, ref, state, isDark),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    ItinerariesState state,
    bool isDark,
  ) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (state.items.isEmpty) {
      return const _EmptyState();
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(itinerariesProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: state.items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _ItineraryCard(itinerary: state.items[index]);
        },
      ),
    );
  }

  Future<void> _showCreateSheet(BuildContext context, WidgetRef ref) async {
    final created = await showModalBottomSheet<Itinerary?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurface
          : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _CreateItinerarySheet(),
    );
    if (created != null && context.mounted) {
      context.push('/itinerary/${created.id}');
    }
  }
}

class _ItineraryCard extends ConsumerWidget {
  const _ItineraryCard({required this.itinerary});

  final Itinerary itinerary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/itinerary/${itinerary.id}'),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isDark
                ? Border.all(color: Colors.white.withAlpha(15))
                : null,
            boxShadow: isDark ? null : AppElevation.level1,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? AppColors.neonBlue.withAlpha(40)
                      : theme.colorScheme.primaryContainer,
                ),
                child: Icon(
                  Icons.map_rounded,
                  color: isDark
                      ? AppColors.neonBlue
                      : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      itinerary.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(itinerary),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Sil',
                onPressed: () => _confirmDelete(context, ref),
                icon: Icon(Icons.delete_outline_rounded,
                    color: theme.hintColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle(Itinerary it) {
    // Liste endpoint'i items dolu döndürmez (sadece items_count). Detay
    // endpoint'i items döndürür. `displayItemCount` ikisini birden kapar.
    final count = it.displayItemCount;
    final dateLabel = it.startsAt != null
        ? ' • ${_fmtDate(it.startsAt!)}${it.endsAt != null ? ' – ${_fmtDate(it.endsAt!)}' : ''}'
        : '';
    return '$count durak$dateLabel';
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.itineraryDeleteTitle),
        content: Text(context.l10n.itineraryDeleteConfirm(itinerary.title)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(context.l10n.btnGiveUp)),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(context.l10n.btnDelete)),
        ],
      ),
    );
    if (ok == true) {
      await ref
          .read(itinerariesProvider.notifier)
          .deleteItinerary(itinerary.id);
    }
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
            Icon(Icons.map_outlined,
                size: 64, color: theme.hintColor.withAlpha(120)),
            const SizedBox(height: 12),
            Text(
              context.l10n.itineraryEmpty,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.itineraryEmptyHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor.withAlpha(180),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateItinerarySheet extends ConsumerStatefulWidget {
  const _CreateItinerarySheet();

  @override
  ConsumerState<_CreateItinerarySheet> createState() =>
      _CreateItinerarySheetState();
}

class _CreateItinerarySheetState extends ConsumerState<_CreateItinerarySheet> {
  final _titleController = TextEditingController();
  DateTime? _startsAt;
  DateTime? _endsAt;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart
        ? (_startsAt ?? DateTime.now())
        : (_endsAt ?? _startsAt ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startsAt = picked;
        if (_endsAt != null && _endsAt!.isBefore(picked)) {
          _endsAt = picked;
        }
      } else {
        _endsAt = picked;
      }
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);
    final created =
        await ref.read(itinerariesProvider.notifier).createItinerary(
              title: title,
              startsAt: _startsAt,
              endsAt: _endsAt,
            );
    if (!mounted) return;
    Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 16),
          Text(context.l10n.itineraryNewTitle,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: context.l10n.itineraryNameLabel,
              hintText: context.l10n.itineraryNameHint,
            ),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(isStart: true),
                  icon: const Icon(Icons.calendar_today_rounded, size: 16),
                  label: Text(
                    _startsAt == null
                        ? context.l10n.lblStart
                        : _fmtDate(_startsAt!),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(isStart: false),
                  icon: const Icon(Icons.event_rounded, size: 16),
                  label: Text(
                    _endsAt == null ? context.l10n.lblEnd : _fmtDate(_endsAt!),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.l10n.btnCreate),
            ),
          ),
        ],
      ),
    );
  }
}

String _fmtDate(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.day)}.${two(dt.month)}.${dt.year}';
}
