import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/design_tokens.dart';
import '../providers/staff_facility_provider.dart';
import '../providers/staff_pos_providers.dart';

/// Checkout screen — shown after customer validation (QR/code) or manual amount.
///
/// [manualOnly] = true  -> show a simple confirmation card (no menu grid)
/// [manualOnly] = false -> show menu grid with steppers + optional manual add
class StaffCheckoutScreen extends ConsumerStatefulWidget {
  const StaffCheckoutScreen({super.key, this.manualOnly = false});

  final bool manualOnly;

  @override
  ConsumerState<StaffCheckoutScreen> createState() =>
      _StaffCheckoutScreenState();
}

class _StaffCheckoutScreenState extends ConsumerState<StaffCheckoutScreen> {
  bool _busy = false;

  Future<void> _checkout() async {
    if (_busy) return;
    setState(() => _busy = true);

    final result = await ref.read(staffPosProvider.notifier).checkout();

    if (!mounted) return;
    setState(() => _busy = false);

    result.when(
      data: (json) async {
        HapticFeedback.heavyImpact();

        final data = json['data'];
        final masked =
            data is Map<String, dynamic> ? data['masked_name'] : null;
        final total =
            data is Map<String, dynamic> ? data['total_deducted'] : null;

        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => _SuccessDialog(
            maskedName: masked?.toString(),
            totalDeducted: total,
          ),
        );
        if (!mounted) return;
        ref.read(staffPosProvider.notifier).resetForNewTransaction();
        Navigator.of(context).pop();
      },
      loading: () {},
      error: (e, _) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pos = ref.watch(staffPosProvider);
    final facilityName = ref.watch(
      staffFacilityProvider.select((s) => s.selected?.name),
    );
    final customer = pos.customer;
    final total = pos.cartTotal;
    final itemCount = pos.cart.fold<int>(0, (s, e) => s + e.quantity);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(context.l10n.staffPaymentApproval),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Müşteriyi sıfırla ama sepeti koru — geri dönünce tekrar tara
            ref.read(staffPosProvider.notifier).clearCustomer();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Column(
        children: [
          if (facilityName != null && facilityName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tesis: $facilityName',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          // Müşteri bilgisi
          if (customer != null)
            _CustomerInfoCard(
              maskedName: customer.maskedName,
              hasSufficientBalance: customer.hasSufficientBalance,
            ),

          // Sipariş özeti
          Expanded(
            child: _OrderSummary(pos: pos),
          ),

          // Tahsil et barı
          _StickyCartBar(
            total: total,
            itemCount: itemCount + (pos.manualAmount > 0 ? 1 : 0),
            busy: _busy,
            enabled: total > 0 && customer != null,
            onCheckout: _checkout,
            onManualAmount: null,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Customer Info Card (Privacy-Masked)
// ---------------------------------------------------------------------------

class _CustomerInfoCard extends StatelessWidget {
  const _CustomerInfoCard({
    required this.maskedName,
    required this.hasSufficientBalance,
  });

  final String maskedName;
  final bool? hasSufficientBalance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final sufficient = hasSufficientBalance == true;
    final insufficient = hasSufficientBalance == false;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        boxShadow: isDark ? null : AppElevation.level1,
        border: isDark ? AppDarkEffects.subtleBorder(context) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (sufficient ? AppColors.success : AppColors.info)
                  .withAlpha(25),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              Icons.person_outline,
              color: sufficient ? AppColors.success : AppColors.info,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  maskedName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Bakiye: **** Puan',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          ),
          if (sufficient)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(20),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: AppColors.success, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Yeterli',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          if (insufficient)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(20),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber, color: AppColors.error, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Yetersiz',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Order Summary — sadece okunabilir liste, düzenleme yok
// ---------------------------------------------------------------------------

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.pos});

  final StaffPosState pos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final items = pos.cart;
    final hasManual = pos.manualAmount > 0;

    if (items.isEmpty && !hasManual) {
      return Center(
        child: Text(
          'Sipariş boş',
          style: theme.textTheme.bodyLarge
              ?.copyWith(color: theme.hintColor),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        ...items.map(
          (item) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              boxShadow: isDark ? null : AppElevation.level1,
              border: isDark ? AppDarkEffects.subtleBorder(context) : null,
            ),
            child: Row(
              children: [
                Text(item.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text(context.l10n.posPriceTimesQty(item.pricePoints, item.quantity),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.hintColor)),
                    ],
                  ),
                ),
                Text(
                  '${item.subtotal} P',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
        if (hasManual)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              boxShadow: isDark ? null : AppElevation.level1,
              border: isDark ? AppDarkEffects.subtleBorder(context) : null,
            ),
            child: Row(
              children: [
                const Text('💰', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.staffManualAmount,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text(context.l10n.staffExtraFee,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.hintColor)),
                    ],
                  ),
                ),
                Text(
                  '${pos.manualAmount} P',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sticky Cart Bar
// ---------------------------------------------------------------------------

class _StickyCartBar extends StatelessWidget {
  const _StickyCartBar({
    required this.total,
    required this.itemCount,
    required this.busy,
    required this.enabled,
    required this.onCheckout,
    this.onManualAmount,
  });

  final int total;
  final int itemCount;
  final bool busy;
  final bool enabled;
  final VoidCallback onCheckout;
  final VoidCallback? onManualAmount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 40 : 10),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onManualAmount,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'Toplam',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                      if (onManualAmount != null) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.edit_outlined,
                          size: 14,
                          color: theme.hintColor,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$total Puan',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: enabled && !busy ? onCheckout : null,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      itemCount > 0
                          ? 'Tahsil Et ($itemCount)'
                          : 'Tahsil Et',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Success Dialog
// ---------------------------------------------------------------------------

class _SuccessDialog extends StatelessWidget {
  const _SuccessDialog({this.maskedName, this.totalDeducted});

  final String? maskedName;
  final dynamic totalDeducted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.success.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: AppColors.success,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Ödeme Başarılı',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (maskedName != null)
            Text(
              maskedName!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
            ),
          if (totalDeducted != null) ...[
            const SizedBox(height: 4),
            Text(
              '$totalDeducted puan harcandı',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
            child: const Text(
              'Yeni İşlem',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Manual Amount Modal — Calculator-style input (used on checkout screen)
// ---------------------------------------------------------------------------

class _ManualAmountModal extends StatefulWidget {
  const _ManualAmountModal({
    required this.initialTotal,
    required this.minTotal,
  });

  /// Başlangıçtaki mevcut toplam (menü + manuel)
  final int initialTotal;

  /// Sadece menüden gelen zorunlu minimum toplam
  final int minTotal;

  @override
  State<_ManualAmountModal> createState() => _ManualAmountModalState();
}

class _ManualAmountModalState extends State<_ManualAmountModal> {
  static const int maxTotal = 50000;
  late int _total =
      widget.initialTotal.clamp(widget.minTotal, maxTotal);

  void _appendDigit(int digit) {
    final next = _total * 10 + digit;
    if (next > maxTotal) return;
    setState(() => _total = next);
    HapticFeedback.selectionClick();
  }

  void _deleteDigit() {
    setState(() => _total = _total ~/ 10);
    HapticFeedback.selectionClick();
  }

  void _clear() {
    setState(() => _total = 0);
    HapticFeedback.lightImpact();
  }

  void _submit() {
    // Kullanıcı minimumdan daha az girdiyse, en az menü toplamına çek.
    final effective = _total < widget.minTotal ? widget.minTotal : _total;
    Navigator.of(context).pop(effective);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        boxShadow: isDark ? null : AppElevation.level3,
        border: isDark ? AppDarkEffects.subtleBorder(context) : null,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.hintColor.withAlpha(60),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Manuel Tutar',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),
              // Amount display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceElevated
                      : const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Column(
                  children: [
                    Text(
                      _total == 0 ? '0' : _total.toString(),
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: _total == 0 ? theme.hintColor : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Toplam Puan',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.hintColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Min: ${widget.minTotal}  •  Maks: $maxTotal',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Calculator keypad
              _Keypad(
                onDigit: _appendDigit,
                onDelete: _deleteDigit,
                onClear: _clear,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                  ),
                  child: Text(
                    _total > 0
                        ? 'Toplamı $_total Puan Yap'
                        : 'Toplamı Güncelle',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Calculator Keypad
// ---------------------------------------------------------------------------

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onDelete,
    required this.onClear,
  });

  final ValueChanged<int> onDigit;
  final VoidCallback onDelete;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildRow(context, [1, 2, 3]),
        const SizedBox(height: 8),
        _buildRow(context, [4, 5, 6]),
        const SizedBox(height: 8),
        _buildRow(context, [7, 8, 9]),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _KeypadActionButton(label: 'C', onTap: onClear)),
            const SizedBox(width: 8),
            Expanded(
              child: _KeypadDigitButton(digit: 0, onTap: () => onDigit(0)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _KeypadActionButton(
                icon: Icons.backspace_outlined,
                onTap: onDelete,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, List<int> digits) {
    return Row(
      children: digits
          .map(
            (d) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                    left: d == digits.first ? 0 : 4,
                    right: d == digits.last ? 0 : 4),
                child: _KeypadDigitButton(digit: d, onTap: () => onDigit(d)),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _KeypadDigitButton extends StatelessWidget {
  const _KeypadDigitButton({required this.digit, required this.onTap});

  final int digit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF0F2F5),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          child: Text(
            '$digit',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _KeypadActionButton extends StatelessWidget {
  const _KeypadActionButton({this.label, this.icon, required this.onTap});

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark
          ? AppColors.darkSurfaceElevated.withAlpha(180)
          : const Color(0xFFE8EBF0),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          child: icon != null
              ? Icon(icon, size: 22, color: theme.hintColor)
              : Text(
                  label ?? '',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.hintColor,
                  ),
                ),
        ),
      ),
    );
  }
}
