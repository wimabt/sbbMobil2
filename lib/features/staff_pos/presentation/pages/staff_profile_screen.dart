import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design_tokens.dart';
import '../../../../core/providers/async_value_widget.dart';
import '../../../profile/presentation/widgets/theme_selector.dart';
import '../providers/staff_auth_provider.dart';
import '../providers/staff_profile_provider.dart';

class StaffProfileScreen extends ConsumerWidget {
  const StaffProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final meAsync = ref.watch(staffProfileProvider);
    final auth = ref.watch(staffAuthProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(context.l10n.staffProfileTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.staffLogout,
            onPressed: () async {
              // Navigate out immediately; run logout in background to avoid
              // staff tab rebuilds firing requests during the transition.
              context.go('/profile');
              unawaited(ref.read(staffAuthProvider.notifier).logout());
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: AsyncValueWidget<Map<String, dynamic>>(
          value: meAsync,
          data: (json) {
            final data = json['data'] as Map<String, dynamic>? ?? const {};
            final fullName =
                '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim();
            final facilityName = data['facility_name']?.toString();
            final totalTx = data['total_transactions'];
            final totalAmt = data['total_amount_processed'];
            return SingleChildScrollView(
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName.isEmpty ? (auth.user?.username ?? 'Personel') : fullName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Kullanıcı adı: ${data['username'] ?? auth.user?.username ?? '-'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Rol: ${data['role'] ?? auth.user?.role ?? 'STAFF'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(height: 10),
                if (facilityName != null && facilityName.isNotEmpty)
                  _InfoRow(
                    icon: Icons.store_outlined,
                    label: 'Tesis',
                    value: facilityName,
                    theme: theme,
                  )
                else
                  _InfoRow(
                    icon: Icons.store_outlined,
                    label: 'Tesis',
                    value: 'Henüz atanmamış',
                    theme: theme,
                    muted: true,
                  ),
                if (totalTx != null) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.receipt_long_outlined,
                    label: context.l10n.staffTotalTransactions,
                    value: '$totalTx',
                    theme: theme,
                  ),
                ],
                if (totalAmt != null) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.stars_outlined,
                    label: context.l10n.staffProcessedPoints,
                    value: '$totalAmt',
                    theme: theme,
                  ),
                ],
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(staffProfileProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Yenile'),
                ),
                const SizedBox(height: 24),
                const ThemeSelector(padding: EdgeInsets.zero),
              ],
            ),
            );
          },
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final ThemeData theme;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.hintColor),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: muted ? theme.hintColor : null,
              fontWeight: muted ? null : FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
