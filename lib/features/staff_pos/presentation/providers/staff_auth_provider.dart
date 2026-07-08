import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/staff_api_service.dart';
import '../../domain/entities/staff_user.dart';

enum StaffAuthStatus { initial, loading, authenticated, unauthenticated }

class StaffAuthState {
  const StaffAuthState({
    required this.status,
    this.user,
    this.errorMessage,
    this.isLoading = false,
  });

  final StaffAuthStatus status;
  final StaffUser? user;
  final String? errorMessage;
  final bool isLoading;

  factory StaffAuthState.initial() =>
      const StaffAuthState(status: StaffAuthStatus.initial);

  StaffAuthState copyWith({
    StaffAuthStatus? status,
    StaffUser? user,
    String? errorMessage,
    bool clearError = false,
    bool? isLoading,
  }) {
    return StaffAuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class StaffAuthNotifier extends Notifier<StaffAuthState> {
  late final StaffApiService _api;
  StreamSubscription<void>? _logoutSub;

  @override
  StaffAuthState build() {
    _api = ref.read(staffApiServiceProvider);

    _logoutSub = _api.onForcedLogout.listen((_) {
      if (kDebugMode) {
        debugPrint('🔐 [StaffAuthNotifier] Forced logout');
      }
      state = StaffAuthState.initial()
          .copyWith(status: StaffAuthStatus.unauthenticated);
    });

    ref.onDispose(() => _logoutSub?.cancel());

    unawaited(_restoreSession());

    return StaffAuthState.initial();
  }

  Future<void> _restoreSession() async {
    try {
      final loggedIn = await _api.isLoggedIn();
      if (!loggedIn) {
        state = state.copyWith(
          status: StaffAuthStatus.unauthenticated,
          user: null,
          clearError: true,
          isLoading: false,
        );
        return;
      }
      state = state.copyWith(
        status: StaffAuthStatus.loading,
        isLoading: true,
        clearError: true,
      );
      final me = await _api.getBackofficeMe();
      // docs/staff_mobile.md: { success: true, user: {...} } (no "data")
      final userJson = me['user'] as Map?;
      final user =
          userJson == null ? null : StaffUser.fromJson(userJson.cast<String, dynamic>());
      state = state.copyWith(
        status: StaffAuthStatus.authenticated,
        user: user,
        isLoading: false,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        status: StaffAuthStatus.unauthenticated,
        user: null,
        isLoading: false,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        status: StaffAuthStatus.unauthenticated,
        user: null,
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(
      status: StaffAuthStatus.loading,
      isLoading: true,
      clearError: true,
    );
    try {
      final result = await _api.login(username: username, password: password);
      final success = result['success'] == true;
      if (!success) {
        final msg = result['error']?.toString() ??
            result['message']?.toString() ??
            'Giriş başarısız.';
        state = state.copyWith(
          status: StaffAuthStatus.unauthenticated,
          isLoading: false,
          errorMessage: msg,
        );
        return false;
      }

      // Token'lar depolanmadıysa (backend response shape'i farklı olabilir),
      // UI'ı authenticated yapıp ardından 401→forced logout döngüsüne sokmayalım.
      final loggedIn = await _api.isLoggedIn();
      if (!loggedIn) {
        state = state.copyWith(
          status: StaffAuthStatus.unauthenticated,
          isLoading: false,
          errorMessage: 'Giris yapildi ancak yetki tokeni saklanamadi.',
        );
        return false;
      }

      // docs/staff_mobile.md: { success: true, user: {...}, tokens: {...} }
      final userJson = result['user'];
      final user =
          userJson is Map<String, dynamic> ? StaffUser.fromJson(userJson) : null;

      state = state.copyWith(
        status: StaffAuthStatus.authenticated,
        isLoading: false,
        user: user,
      );
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        status: StaffAuthStatus.unauthenticated,
        isLoading: false,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: StaffAuthStatus.unauthenticated,
        isLoading: false,
        errorMessage: 'Beklenmeyen bir hata oluştu.',
      );
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(
      status: StaffAuthStatus.loading,
      isLoading: true,
      clearError: true,
    );
    await _api.logout();
    state = StaffAuthState.initial()
        .copyWith(status: StaffAuthStatus.unauthenticated);
  }
}

final staffAuthProvider =
    NotifierProvider<StaffAuthNotifier, StaffAuthState>(StaffAuthNotifier.new);

