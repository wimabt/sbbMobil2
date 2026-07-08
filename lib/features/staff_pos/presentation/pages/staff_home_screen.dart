import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design_tokens.dart';
import '../../domain/entities/staff_facility.dart';
import '../providers/staff_auth_provider.dart';
import '../providers/staff_facility_provider.dart';
import 'staff_pos_screen.dart';
import 'staff_profile_screen.dart';
import 'staff_transactions_screen.dart';

class StaffHomeScreen extends ConsumerStatefulWidget {
  const StaffHomeScreen({super.key});

  @override
  ConsumerState<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends ConsumerState<StaffHomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    ref.listen(staffAuthProvider, (prev, next) {
      if (next.status == StaffAuthStatus.unauthenticated) {
        if (context.mounted) context.go('/profile');
      }
    });

    final auth = ref.watch(staffAuthProvider);
    if (auth.status == StaffAuthStatus.initial ||
        auth.status == StaffAuthStatus.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final facilityState = ref.watch(staffFacilityProvider);

    return facilityState.facilities.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    size: 48, color: theme.colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  e.toString(),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () =>
                      ref.read(staffFacilityProvider.notifier).retry(),
                  icon: const Icon(Icons.refresh),
                  label: Text(context.l10n.btnRetry),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (facilities) {
        if (facilities.isEmpty) {
          return Scaffold(
            backgroundColor:
                isDark ? AppColors.darkBackground : AppColors.lightBackground,
            appBar: AppBar(title: const Text('Tesis')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Size atanmış tesis yok. Süper yönetici panelinden tesis '
                  'ataması yapılması gerekir.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ),
            ),
          );
        }

        if (facilities.length > 1 && facilityState.selected == null) {
          return _FacilitySelectScaffold(
            facilities: facilities,
            onSelect: (f) =>
                ref.read(staffFacilityProvider.notifier).selectFacility(f),
          );
        }

        return _StaffMainShell(
          index: _index,
          onIndexChanged: (i) => setState(() => _index = i),
          isDark: isDark,
        );
      },
    );
  }
}

class _StaffMainShell extends StatelessWidget {
  const _StaffMainShell({
    required this.index,
    required this.onIndexChanged,
    required this.isDark,
  });

  final int index;
  final ValueChanged<int> onIndexChanged;
  final bool isDark;

  static const _pages = <Widget>[
    StaffPosScreen(),
    StaffTransactionsScreen(),
    StaffProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: IndexedStack(index: index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onIndexChanged,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: const Icon(Icons.qr_code_scanner),
            label: context.l10n.staffScan,
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long),
            label: context.l10n.staffTransactions,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: context.l10n.navProfile,
          ),
        ],
      ),
    );
  }
}

class _FacilitySelectScaffold extends StatelessWidget {
  const _FacilitySelectScaffold({
    required this.facilities,
    required this.onSelect,
  });

  final List<StaffFacility> facilities;
  final ValueChanged<StaffFacility> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(context.l10n.staffSelectFacility),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: facilities.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final f = facilities[i];
          return Material(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: InkWell(
              onTap: () => onSelect(f),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 18,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer
                            .withAlpha(isDark ? 60 : 80),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        Icons.store_mall_directory_outlined,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        f.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: theme.hintColor,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
