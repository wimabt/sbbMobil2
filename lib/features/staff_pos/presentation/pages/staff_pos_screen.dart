import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/design/design_tokens.dart';
import '../../../../core/providers/async_value_widget.dart';
import '../../domain/entities/pos_menu_item.dart';
import '../providers/staff_facility_provider.dart';
import '../providers/staff_pos_providers.dart';
import 'staff_checkout_screen.dart';

/// Yeni akış:
///   1. Çalışan önce menüden ürün seçer ve/veya manuel tutar girer.
///   2. Hazır olduğunda "QR Tara" veya "Kod Gir" ile müşteriyi doğrular.
///   3. Doğrulama başarılıysa checkout ekranına geçer.
class StaffPosScreen extends ConsumerStatefulWidget {
  const StaffPosScreen({super.key});

  @override
  ConsumerState<StaffPosScreen> createState() => _StaffPosScreenState();
}

class _StaffPosScreenState extends ConsumerState<StaffPosScreen> {
  // ── Validating overlay ──────────────────────────────────────────────────
  bool _validating = false;

  void _setValidating(bool v) {
    if (mounted) setState(() => _validating = v);
  }

  Future<void> _validateAndProceed(String tokenOrCode) async {
    _setValidating(true);
    final result = await ref
        .read(staffPosProvider.notifier)
        .validateTokenOrCode(tokenOrCode);
    _setValidating(false);
    if (!mounted) return;

    result.when(
      data: (_) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const StaffCheckoutScreen()),
      ),
      loading: () {},
      error: (e, _) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Future<void> _openQrScanner() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _QrScannerPage()),
    );
    if (!mounted || code == null || code.isEmpty) return;
    await _validateAndProceed(code.trim());
  }

  Future<void> _openManualCodeModal() async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ManualCodeModal(),
    );
    if (!mounted || code == null || code.isEmpty) return;
    final stripped = code.replaceAll('-', '').trim();
    await _validateAndProceed(stripped);
  }

  Future<void> _showChangeFacilitySheet() async {
    final facilityState = ref.read(staffFacilityProvider);
    final list = facilityState.facilities.asData?.value;
    if (list == null || list.length < 2) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.xxl),
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              border: isDark ? AppDarkEffects.subtleBorder(ctx) : null,
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      context.l10n.staffSwitchFacility,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (context, i) {
                        final f = list[i];
                        final sel = facilityState.selected?.id == f.id;
                        return ListTile(
                          leading: Icon(
                            Icons.store_mall_directory_outlined,
                            color: sel
                                ? theme.colorScheme.primary
                                : theme.hintColor,
                          ),
                          title: Text(
                            f.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                          trailing: sel
                              ? Icon(Icons.check_circle,
                                  color: theme.colorScheme.primary)
                              : null,
                          onTap: () {
                            ref
                                .read(staffFacilityProvider.notifier)
                                .selectFacility(f);
                            Navigator.of(ctx).pop();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openManualAmountModal() async {
    final pos = ref.read(staffPosProvider);
    final cartBase = pos.cart.fold<int>(0, (s, e) => s + e.subtotal);
    final currentTotal = pos.cartTotal;

    final newTotal = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ManualAmountModal(
        initialTotal: currentTotal,
        minTotal: cartBase,
      ),
    );
    if (!mounted || newTotal == null) return;
    final manual = (newTotal - cartBase).clamp(0, 50000);
    ref.read(staffPosProvider.notifier).setManualAmount(manual);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pos = ref.watch(staffPosProvider);
    final facilityState = ref.watch(staffFacilityProvider);
    final selectedFacility = facilityState.selected;
    final facilityList = facilityState.facilities.asData?.value;
    final canSwitchFacility = (facilityList?.length ?? 0) > 1;
    final total = pos.cartTotal;
    final itemCount = pos.cart.fold<int>(0, (s, e) => s + e.quantity);
    final hasItems = total > 0;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.posCashier),
            if (selectedFacility != null) ...[
              const SizedBox(height: 2),
              Text(
                selectedFacility.name,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(200),
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        centerTitle: true,
        actions: [
          if (canSwitchFacility && selectedFacility != null)
            IconButton(
              tooltip: context.l10n.staffSwitchFacility,
              onPressed: _showChangeFacilitySheet,
              icon: const Icon(Icons.swap_horiz_rounded),
            ),
          if (pos.manualAmount > 0 || pos.cart.isNotEmpty)
            TextButton(
              onPressed: () =>
                  ref.read(staffPosProvider.notifier).resetForNewTransaction(),
              child: const Text('Temizle'),
            ),
        ],
      ),
      body: Column(
        children: [
          if (selectedFacility != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    avatar: Icon(
                      Icons.storefront_outlined,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    label: Text(
                      selectedFacility.name,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(
                      color: theme.colorScheme.primary.withAlpha(100),
                    ),
                  ),
                ),
              ),
            ),
          // ── Menü grid ──────────────────────────────────────────────────
          Expanded(
            child: AsyncValueWidget<List<PosMenuItem>>(
              value: pos.menu,
              data: (menu) {
                final active = menu.where((e) => e.isActive).toList()
                  ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

                if (active.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.restaurant_menu_outlined,
                            size: 48,
                            color: theme.hintColor.withAlpha(80)),
                        const SizedBox(height: 12),
                        Text(
                          'Menü bulunamadı',
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(color: theme.hintColor),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: active.length,
                  itemBuilder: (context, i) {
                    final item = active[i];
                    final qty = pos.cart
                        .where((c) => c.menuItemId == item.id)
                        .fold(0, (s, c) => s + c.quantity);
                    return _MenuCard(
                      item: item,
                      quantity: qty,
                      onIncrement: () => ref
                          .read(staffPosProvider.notifier)
                          .addMenuItem(item),
                      onDecrement: () => ref
                          .read(staffPosProvider.notifier)
                          .removeMenuItem(item.id),
                    );
                  },
                );
              },
            ),
          ),

          // ── Alt bar ────────────────────────────────────────────────────
          _BottomBar(
            total: total,
            itemCount: itemCount,
            hasManual: pos.manualAmount > 0,
            hasItems: hasItems,
            validating: _validating,
            onManualAmount: _openManualAmountModal,
            onScanQr: _openQrScanner,
            onEnterCode: _openManualCodeModal,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Alt Bar
// ─────────────────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.total,
    required this.itemCount,
    required this.hasManual,
    required this.hasItems,
    required this.validating,
    required this.onManualAmount,
    required this.onScanQr,
    required this.onEnterCode,
  });

  final int total;
  final int itemCount;
  final bool hasManual;
  final bool hasItems;
  final bool validating;
  final VoidCallback onManualAmount;
  final VoidCallback onScanQr;
  final VoidCallback onEnterCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 12),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Toplam satırı
          Row(
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
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.hintColor),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.edit_outlined,
                              size: 13, color: theme.hintColor),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$total Puan',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
              if (hasManual)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _ManualChip(
                    onTap: onManualAmount,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Aksiyon butonları
          Row(
            children: [
              // Kod Gir
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: validating ? null : onEnterCode,
                    icon: const Icon(Icons.keyboard_alt_outlined, size: 18),
                    label: Text(context.l10n.staffEnterCode),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // QR Tara — ana CTA
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: validating ? null : onScanQr,
                    icon: validating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.qr_code_scanner, size: 20),
                    label: Text(
                      validating
                          ? 'Doğrulanıyor…'
                          : hasItems
                              ? 'QR Tara  ($total P)'
                              : 'QR Tara',
                    ),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManualChip extends StatelessWidget {
  const _ManualChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.monetization_on_outlined,
                size: 14, color: theme.colorScheme.onPrimaryContainer),
            const SizedBox(width: 4),
            Text(
              'Manuel',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Menu Card with Stepper
// ─────────────────────────────────────────────────────────────────────────────

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.item,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  final PosMenuItem item;
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasQty = quantity > 0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        boxShadow: isDark ? null : AppElevation.level1,
        border: hasQty
            ? Border.all(
                color: theme.colorScheme.primary.withAlpha(120), width: 2)
            : isDark
                ? AppDarkEffects.subtleBorder(context) as Border?
                : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: InkWell(
          onTap: onIncrement,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item.emoji,
                        style: const TextStyle(fontSize: 28)),
                    if (hasQty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          '$quantity',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  item.itemName,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.pricePoints} puan',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor),
                ),
                if (hasQty) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _StepBtn(icon: Icons.remove, onTap: onDecrement),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '$quantity',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      _StepBtn(icon: Icons.add, onTap: onIncrement),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceElevated
              : const Color(0xFFF0F2F5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 18, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QR Scanner — tam ekran sayfa (modal değil, geri tuşu ile çıkılır)
// ─────────────────────────────────────────────────────────────────────────────

class _QrScannerPage extends StatefulWidget {
  const _QrScannerPage();

  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage>
    with WidgetsBindingObserver {
  late final MobileScannerController _ctrl;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ctrl = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _ctrl.stop();
      case AppLifecycleState.resumed:
        _ctrl.start();
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes.isNotEmpty
        ? capture.barcodes.first.rawValue
        : null;
    if (raw == null || raw.isEmpty) return;
    _handled = true;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(raw.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: MobileScanner(controller: _ctrl, onDetect: _onDetect),
          ),

          // Üst gradient + geri butonu
          Positioned(
            top: 0, left: 0, right: 0, height: 120,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xCC000000), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            top: top + 8,
            left: 4,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            top: top + 14,
            left: 0, right: 0,
            child: Text(
              'QR Tara',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          // Tarama çerçevesi
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: Colors.white.withAlpha(180), width: 2.5),
              ),
            ),
          ),

          // Alt gradient + ipucu
          Positioned(
            bottom: 0, left: 0, right: 0, height: 180,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xCC000000), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: bottom + 40,
            left: 40, right: 40,
            child: Text(
              'Müşterinin QR kodunu kareye hizalayın',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withAlpha(200),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Manual Code Modal (###-###)
// ─────────────────────────────────────────────────────────────────────────────

class _ManualCodeModal extends StatefulWidget {
  const _ManualCodeModal();

  @override
  State<_ManualCodeModal> createState() => _ManualCodeModalState();
}

class _ManualCodeModalState extends State<_ManualCodeModal> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  final _formatter = MaskTextInputFormatter(
    mask: '###-###',
    filter: {'#': RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  bool get _isValid => _formatter.getUnmaskedText().length == 6;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_isValid) return;
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
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
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: theme.hintColor.withAlpha(60),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Kodu Elle Gir',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(context.l10n.staffEnterCodeHint,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.hintColor)),
                const SizedBox(height: 24),
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: [_formatter],
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                  ),
                  decoration: InputDecoration(
                    hintText: '___-___',
                    hintStyle: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w400,
                      letterSpacing: 6,
                      color: theme.hintColor.withAlpha(80),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? AppColors.darkSurfaceElevated
                        : const Color(0xFFF0F2F5),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 18),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _isValid ? _submit : null,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                    ),
                    child: Text(context.l10n.btnVerify,
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Manual Amount Modal — toplam puan girişi, calculator-style
// ─────────────────────────────────────────────────────────────────────────────

class _ManualAmountModal extends StatefulWidget {
  const _ManualAmountModal({
    required this.initialTotal,
    required this.minTotal,
  });

  final int initialTotal;
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
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: theme.hintColor.withAlpha(60),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(context.l10n.staffEditTotal,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 24),
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
                    Text(context.l10n.staffTotalPoints,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.hintColor,
                          fontWeight: FontWeight.w600,
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Min: ${widget.minTotal}  •  Maks: $maxTotal',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor),
                ),
              ),
              const SizedBox(height: 12),
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
                        : 'Manuel Tutarı Kaldır',
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

// ─────────────────────────────────────────────────────────────────────────────
// Calculator Keypad
// ─────────────────────────────────────────────────────────────────────────────

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
        _row(context, [1, 2, 3]),
        const SizedBox(height: 8),
        _row(context, [4, 5, 6]),
        const SizedBox(height: 8),
        _row(context, [7, 8, 9]),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _ActionBtn(label: 'C', onTap: onClear)),
            const SizedBox(width: 8),
            Expanded(child: _DigitBtn(digit: 0, onTap: () => onDigit(0))),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionBtn(
                  icon: Icons.backspace_outlined, onTap: onDelete),
            ),
          ],
        ),
      ],
    );
  }

  Widget _row(BuildContext context, List<int> digits) {
    return Row(
      children: digits.map((d) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: d == digits.first ? 0 : 4,
              right: d == digits.last ? 0 : 4,
            ),
            child: _DigitBtn(digit: d, onTap: () => onDigit(d)),
          ),
        );
      }).toList(),
    );
  }
}

class _DigitBtn extends StatelessWidget {
  const _DigitBtn({required this.digit, required this.onTap});
  final int digit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF0F2F5),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          child: Text('$digit',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({this.label, this.icon, required this.onTap});
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
              : Text(label ?? '',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.hintColor,
                  )),
        ),
      ),
    );
  }
}
