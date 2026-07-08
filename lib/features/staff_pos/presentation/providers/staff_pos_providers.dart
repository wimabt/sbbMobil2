import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/staff_api_service.dart';
import '../../data/repositories/staff_pos_repository.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/pos_menu_item.dart';
import '../../domain/entities/validated_customer.dart';

import 'staff_facility_provider.dart';

final staffPosRepositoryProvider = Provider<StaffPosRepository>((ref) {
  final api = ref.watch(staffApiServiceProvider);
  return StaffPosRepository(api);
});

class StaffPosState {
  const StaffPosState({
    required this.menu,
    required this.customer,
    required this.cart,
    required this.manualAmount,
    required this.lastTokenOrCode,
  });

  final AsyncValue<List<PosMenuItem>> menu;
  final ValidatedCustomer? customer;
  final List<CartItem> cart;
  final int manualAmount;
  final String lastTokenOrCode;

  int get cartTotal =>
      cart.fold<int>(0, (sum, item) => sum + item.subtotal) + manualAmount;

  StaffPosState copyWith({
    AsyncValue<List<PosMenuItem>>? menu,
    ValidatedCustomer? customer,
    bool clearCustomer = false,
    List<CartItem>? cart,
    int? manualAmount,
    String? lastTokenOrCode,
  }) {
    return StaffPosState(
      menu: menu ?? this.menu,
      customer: clearCustomer ? null : (customer ?? this.customer),
      cart: cart ?? this.cart,
      manualAmount: manualAmount ?? this.manualAmount,
      lastTokenOrCode: lastTokenOrCode ?? this.lastTokenOrCode,
    );
  }

  factory StaffPosState.initial() => const StaffPosState(
        menu: AsyncLoading(),
        customer: null,
        cart: <CartItem>[],
        manualAmount: 0,
        lastTokenOrCode: '',
      );
}

class StaffPosNotifier extends Notifier<StaffPosState> {
  late final StaffPosRepository _repo;
  int _menuGen = 0;

  @override
  StaffPosState build() {
    _repo = ref.read(staffPosRepositoryProvider);

    ref.listen<String?>(
      staffFacilityProvider.select((s) => s.selected?.id),
      (prev, next) {
        Future.microtask(() {
          if (prev != next) {
            state = state.copyWith(
              cart: const <CartItem>[],
              manualAmount: 0,
              clearCustomer: true,
              lastTokenOrCode: '',
            );
          }
          unawaited(_loadMenuForFacility(next));
        });
      },
      fireImmediately: true,
    );

    return StaffPosState.initial();
  }

  Future<void> _loadMenuForFacility(String? facilityId) async {
    final gen = ++_menuGen;
    if (facilityId == null) {
      if (gen != _menuGen) return;
      state = state.copyWith(menu: const AsyncData([]));
      return;
    }
    state = state.copyWith(menu: const AsyncLoading());
    final menu = await AsyncValue.guard(
      () => _repo.getMenu(facilityId: facilityId),
    );
    if (gen != _menuGen) return;
    state = state.copyWith(menu: menu);
  }

  void addMenuItem(PosMenuItem item) {
    final existingIndex =
        state.cart.indexWhere((e) => e.menuItemId == item.id);
    if (existingIndex < 0) {
      state = state.copyWith(
        cart: [
          ...state.cart,
          CartItem(
            menuItemId: item.id,
            name: item.itemName,
            emoji: item.emoji,
            pricePoints: item.pricePoints,
            quantity: 1,
          ),
        ],
      );
      return;
    }
    final existing = state.cart[existingIndex];
    final updated = existing.copyWith(quantity: existing.quantity + 1);
    final next = [...state.cart]..[existingIndex] = updated;
    state = state.copyWith(cart: next);
  }

  void removeMenuItem(String menuItemId) {
    final idx = state.cart.indexWhere((e) => e.menuItemId == menuItemId);
    if (idx < 0) return;
    final existing = state.cart[idx];
    if (existing.quantity <= 1) {
      state = state.copyWith(
        cart: state.cart.where((e) => e.menuItemId != menuItemId).toList(),
      );
      return;
    }
    final updated = existing.copyWith(quantity: existing.quantity - 1);
    final next = [...state.cart]..[idx] = updated;
    state = state.copyWith(cart: next);
  }

  void setManualAmount(int value) {
    final v = value.clamp(0, 50000);
    state = state.copyWith(manualAmount: v);
  }

  Future<AsyncValue<ValidatedCustomer>> validateTokenOrCode(
    String tokenOrCode,
  ) async {
    final requested = state.cartTotal;
    final result = await AsyncValue.guard(
      () => _repo.validate(
        tokenOrCode: tokenOrCode,
        requestedAmount: requested,
      ),
    );
    state = state.copyWith(lastTokenOrCode: tokenOrCode);
    result.whenData((c) => state = state.copyWith(customer: c));
    return result;
  }

  Future<AsyncValue<Map<String, dynamic>>> checkout() async {
    final customer = state.customer;
    if (customer == null) {
      return AsyncValue.error(
        StateError('Customer not validated'),
        StackTrace.current,
      );
    }
    if (state.cart.isEmpty && state.manualAmount <= 0) {
      return AsyncValue.error(
        StateError('Empty cart'),
        StackTrace.current,
      );
    }
    final facilityId = ref.read(staffFacilityProvider).selected?.id;

    return AsyncValue.guard(
      () => _repo.checkout(
        tokenOrCode: customer.tokenOrCode,
        cart: state.cart,
        manualAmount: state.manualAmount,
        facilityId: facilityId,
      ),
    );
  }

  void clearCustomer() {
    state = state.copyWith(clearCustomer: true, lastTokenOrCode: '');
  }

  void resetForNewTransaction() {
    state = state.copyWith(
      clearCustomer: true,
      cart: const <CartItem>[],
      manualAmount: 0,
      lastTokenOrCode: '',
    );
  }
}

final staffPosProvider = NotifierProvider<StaffPosNotifier, StaffPosState>(
  StaffPosNotifier.new,
);

