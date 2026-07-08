import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/design_tokens.dart';
import '../../../../core/providers/async_value_widget.dart';
import '../providers/staff_transactions_provider.dart';

class StaffTransactionsScreen extends ConsumerWidget {
  const StaffTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final txAsync = ref.watch(staffTransactionsProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(context.l10n.staffMyTransactions),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: () => ref.invalidate(staffTransactionsProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AsyncValueWidget<Map<String, dynamic>>(
        value: txAsync,
        data: (json) {
          final list = (json['data'] as List?) ?? const [];
          final today = json['today'] as Map?;
          final todayCount = today?['transaction_count'];
          final todaySpent = today?['total_spent'];

          return Column(
            children: [
              if (today != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isDark
                        ? AppColors.darkSurfaceElevated
                        : AppColors.lightSurface,
                    boxShadow: isDark ? null : AppElevation.level1,
                    border: isDark ? AppDarkEffects.subtleBorder(context) : null,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.today_outlined, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Bugün: $todayCount işlem  •  $todaySpent puan',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (list.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      'İşlem bulunamadı',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
              final item = list[index];
              if (item is! Map) return const SizedBox.shrink();
              final m = item.cast<String, dynamic>();
              final amount = m['amount']?.toString() ?? '-';
              final desc = m['description']?.toString() ?? '';
              final masked = m['masked_user_name']?.toString() ?? '';
              final createdAt = m['created_at']?.toString() ?? '';
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  boxShadow: isDark ? null : AppElevation.level1,
                  border: isDark ? AppDarkEffects.subtleBorder(context) : null,
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$amount puan',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (masked.isNotEmpty)
                      Text(
                        masked,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(desc, style: theme.textTheme.bodyMedium),
                    ],
                    if (createdAt.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        createdAt,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

