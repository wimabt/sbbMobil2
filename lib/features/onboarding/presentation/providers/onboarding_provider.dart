import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../data/repositories/repositories.dart';
import '../../../auth/providers/auth_provider.dart';

/// Şartname §6.3.5 — Onboarding durum yönetimi.
///
/// Versiyonlu anahtar (`_kCompletedKey`) sayesinde onboarding akışı
/// gelecekte revize edilirse `_v2` yapılarak yeniden gösterilebilir.
const String _kCompletedKey = 'onboarding_completed_v1';
const String _kInterestsKey = 'user_interests';

class OnboardingState {
  const OnboardingState({
    this.isCompleted = false,
    this.interests = const <String>{},
    this.isLoading = false,
  });

  /// `true` → onboarding daha önce tamamlandı, akış tekrar gösterilmez.
  final bool isCompleted;

  /// Kullanıcının onboarding sırasında seçtiği ilgi alanı slug'ları.
  /// Daha sonra öneri algoritmasına (`discovery_service`) beslenir.
  final Set<String> interests;
  final bool isLoading;

  OnboardingState copyWith({
    bool? isCompleted,
    Set<String>? interests,
    bool? isLoading,
  }) {
    return OnboardingState(
      isCompleted: isCompleted ?? this.isCompleted,
      interests: interests ?? this.interests,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class OnboardingNotifier extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    return const OnboardingState();
  }

  /// Uygulama açılışında çağrılır (`main.dart`).
  Future<void> loadStatus() async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final completed = prefs.getBool(_kCompletedKey) ?? false;
      final interests =
          prefs.getStringList(_kInterestsKey)?.toSet() ?? const <String>{};
      state = OnboardingState(
        isCompleted: completed,
        interests: interests,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Onboarding sırasında ilgi alanı seçimini günceller.
  /// Akış henüz tamamlanmadan önbelleğe yazılmaz; `complete` çağrısında kalıcı olur.
  void toggleInterest(String slug) {
    final next = Set<String>.from(state.interests);
    if (!next.add(slug)) next.remove(slug);
    state = state.copyWith(interests: next);
  }

  void setInterests(Set<String> interests) {
    state = state.copyWith(interests: interests);
  }

  /// Akışın sonunda çağrılır — bayrak ve seçimleri kalıcı olarak yazar.
  /// Auth varsa sunucuya da push'lar (mobile_integ.md §1.2).
  Future<void> complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kCompletedKey, true);
    final slugs = state.interests.toList();
    await prefs.setStringList(_kInterestsKey, slugs);
    state = state.copyWith(isCompleted: true);

    // Auth varsa sunucuyu da güncelle. Anonim akışta sessizce atla;
    // login sonrası `reconcileWithServer` initial backfill yapacak.
    final auth = ref.read(authProvider);
    if (auth.status == AuthStatus.authenticated) {
      try {
        await ref
            .read(userPreferencesRepositoryProvider)
            .updateInterests(slugs);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[Onboarding] interests PUT failed: $e');
        }
      }
    }
  }

  /// Login sonrası çağrılır. mobile_integ.md §1.2:
  /// - Sunucuda boş + cihazda dolu → ilk PUT (backfill).
  /// - Aksi halde sunucu kazanır.
  Future<void> reconcileWithServer() async {
    final auth = ref.read(authProvider);
    if (auth.status != AuthStatus.authenticated) return;
    final repo = ref.read(userPreferencesRepositoryProvider);
    try {
      final remote = await repo.fetchInterests();
      final local = state.interests;
      if (remote.isEmpty && local.isNotEmpty) {
        await repo.updateInterests(local.toList());
        return; // local zaten state'te
      }
      // Sunucu kazandı (boş ya da dolu)
      final next = remote.toSet();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kInterestsKey, remote);
      state = state.copyWith(interests: next);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Onboarding] reconcileWithServer failed: $e');
      }
    }
  }

  /// Geliştirici/QA için onboarding'i sıfırla. Üretim akışında çağrılmaz.
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCompletedKey);
    await prefs.remove(_kInterestsKey);
    state = const OnboardingState();
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, OnboardingState>(
  OnboardingNotifier.new,
);
