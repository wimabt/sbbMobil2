import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/staff_api_service.dart';
import '../../data/repositories/staff_pos_repository.dart';
import '../../domain/entities/staff_facility.dart';
import 'staff_auth_provider.dart';

const _kSelectedFacilityPrefKey = 'staff_pos_selected_facility_id';

class StaffFacilityState {
  const StaffFacilityState({
    this.facilities = const AsyncLoading(),
    this.selected,
  });

  final AsyncValue<List<StaffFacility>> facilities;
  final StaffFacility? selected;

  StaffFacilityState copyWith({
    AsyncValue<List<StaffFacility>>? facilities,
    StaffFacility? selected,
    bool clearSelected = false,
  }) {
    return StaffFacilityState(
      facilities: facilities ?? this.facilities,
      selected: clearSelected ? null : (selected ?? this.selected),
    );
  }

  static StaffFacilityState cleared() => const StaffFacilityState(
        facilities: AsyncData([]),
        selected: null,
      );
}

class StaffFacilityNotifier extends Notifier<StaffFacilityState> {
  int _loadGen = 0;

  StaffPosRepository get _repo =>
      StaffPosRepository(ref.read(staffApiServiceProvider));

  @override
  StaffFacilityState build() {
    // fireImmediately: auth zaten authenticated iken de ilk yükleme yapılsın.
    // Dinleyici build() dönmeden çalışabildiği için state yazımını microtask'a
    // alıyoruz; aksi halde "uninitialized provider" hatası oluşur.
    ref.listen(
      staffAuthProvider,
      (prev, next) {
        Future.microtask(() {
          if (next.status == StaffAuthStatus.unauthenticated) {
            state = StaffFacilityState.cleared();
            return;
          }
          if (next.status == StaffAuthStatus.authenticated &&
              prev?.status != StaffAuthStatus.authenticated) {
            unawaited(_loadFacilities());
          }
        });
      },
      fireImmediately: true,
    );

    return const StaffFacilityState(
      facilities: AsyncLoading(),
      selected: null,
    );
  }

  Future<void> _loadFacilities() async {
    final gen = ++_loadGen;
    state = state.copyWith(facilities: const AsyncLoading());

    try {
      final list = await _repo.getFacilities();
      if (gen != _loadGen) return;

      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_kSelectedFacilityPrefKey);

      StaffFacility? selected;
      if (savedId != null) {
        for (final f in list) {
          if (f.id == savedId) {
            selected = f;
            break;
          }
        }
      }
      selected ??= list.length == 1 ? list.first : null;

      if (selected != null) {
        await prefs.setString(_kSelectedFacilityPrefKey, selected.id);
      }

      state = state.copyWith(
        facilities: AsyncData(list),
        selected: selected,
      );
    } catch (e, st) {
      if (gen != _loadGen) return;
      state = state.copyWith(
        facilities: AsyncError(e, st),
        clearSelected: true,
      );
    }
  }

  Future<void> retry() => _loadFacilities();

  Future<void> selectFacility(StaffFacility facility) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSelectedFacilityPrefKey, facility.id);
    state = state.copyWith(selected: facility);
  }

  Future<void> clearSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSelectedFacilityPrefKey);
    state = state.copyWith(clearSelected: true);
  }
}

final staffFacilityProvider =
    NotifierProvider<StaffFacilityNotifier, StaffFacilityState>(
  StaffFacilityNotifier.new,
);
