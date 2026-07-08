import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/design_tokens.dart';
import '../../../../core/utils/haptics.dart';
import '../../providers/auth_provider.dart';

/// KVKK / hesap silme — cold start'ta pending durumdaysa home ekranı tepesinde
/// gösterilen turuncu banner. Kullanıcı tek dokunuşla hesabı geri yükleyebilir.
///
/// Backend kontratı: `GET /api/v1/user/account/status` → `pending: true` +
/// `days_remaining`. AuthState içine `AccountStatusResult` olarak çekilir.
class PendingDeletionBanner extends ConsumerWidget {
  const PendingDeletionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(
      authProvider.select((s) => s.pendingDeletion),
    );

    if (pending == null || !pending.isPending) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final days = pending.daysRemaining ?? 30;

    final bg = isDark
        ? const Color(0xFF3D2A1A)
        : const Color(0xFFFFF3E0);
    final fg = isDark
        ? const Color(0xFFFFCC80)
        : const Color(0xFFE65100);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: fg.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: fg, size: 22),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Hesabınız silinmek üzere',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Kalıcı silinmesine $days gün kaldı.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: fg.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _RestoreButton(fg: fg),
          ],
        ),
      ),
    );
  }
}

class _RestoreButton extends ConsumerStatefulWidget {
  const _RestoreButton({required this.fg});

  final Color fg;

  @override
  ConsumerState<_RestoreButton> createState() => _RestoreButtonState();
}

class _RestoreButtonState extends ConsumerState<_RestoreButton> {
  bool _busy = false;

  Future<void> _onRestore() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final restoredMsg = context.l10n.accountRestoredShort;
    final failedMsg = context.l10n.accountRestoreFailed;
    await Haptics.selection();
    if (!mounted) return;
    setState(() => _busy = true);
    final ok = await ref.read(authProvider.notifier).restoreCurrentAccount();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      await Haptics.success();
      messenger.showSnackBar(
        SnackBar(content: Text(restoredMsg)),
      );
    } else {
      await Haptics.error();
      messenger.showSnackBar(
        SnackBar(
          content: Text(failedMsg),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: _busy ? null : _onRestore,
      style: TextButton.styleFrom(
        foregroundColor: widget.fg,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: _busy
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(widget.fg),
              ),
            )
          : const Text(
              'Geri Yükle',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
    );
  }
}
