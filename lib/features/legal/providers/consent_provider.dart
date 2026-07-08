import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/repositories/consent_repository.dart';
import '../data/legal_documents.dart';

/// KVKK açık rıza durumu (§10.6.2, §14.2.2).
///
/// Üyelik gerektiren akışlarda (kayıt) kullanıcıdan alınan açık rıza burada
/// kalıcılaştırılır. [version] kabul edilen metin sürümünü tutar; metinler
/// güncellenip [kLegalContentVersion] artırılırsa rıza yeniden istenir.
@immutable
class ConsentState {
  const ConsentState({
    this.accepted = false,
    this.version = 0,
    this.acceptedAt,
  });

  final bool accepted;

  /// Kabul edilen yasal metin sürümü.
  final int version;

  /// Rızanın alındığı an (ISO-8601) — denetim izi için.
  final String? acceptedAt;

  /// Güncel metin sürümü için geçerli rıza var mı?
  bool get isValidForCurrentVersion =>
      accepted && version >= kLegalContentVersion;

  ConsentState copyWith({bool? accepted, int? version, String? acceptedAt}) =>
      ConsentState(
        accepted: accepted ?? this.accepted,
        version: version ?? this.version,
        acceptedAt: acceptedAt ?? this.acceptedAt,
      );
}

class ConsentNotifier extends Notifier<ConsentState> {
  static const _kAccepted = 'kvkk_consent_accepted';
  static const _kVersion = 'kvkk_consent_version';
  static const _kAt = 'kvkk_consent_at';

  /// Sunucuya başarıyla yazılmış son rıza sürümü. Backend kaydı append-only
  /// olduğundan ([ConsentRepository.submitConsent]) aynı sürümü tekrar
  /// göndermeyi engeller. 0 = henüz senkronlanmadı.
  static const _kServerSyncedVersion = 'kvkk_consent_server_version';

  @override
  ConsentState build() => const ConsentState();

  /// Startup'ta kalıcı rıza durumunu okur.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = ConsentState(
      accepted: prefs.getBool(_kAccepted) ?? false,
      version: prefs.getInt(_kVersion) ?? 0,
      acceptedAt: prefs.getString(_kAt),
    );
  }

  /// Açık rızayı kaydeder (güncel metin sürümüyle damgalanır).
  Future<void> accept() async {
    final now = DateTime.now().toIso8601String();
    state = ConsentState(
      accepted: true,
      version: kLegalContentVersion,
      acceptedAt: now,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAccepted, true);
    await prefs.setInt(_kVersion, kLegalContentVersion);
    await prefs.setString(_kAt, now);
    // Her accept() bilinçli, yeni bir rıza eylemidir → sunucu senkron işaretini
    // sıfırla. Aksi halde aynı cihazda ikinci bir kullanıcı kayıt olup rıza
    // verdiğinde (işaret cihaz-global) syncToServer guard'ı atlar ve o
    // kullanıcının rızası backend'e hiç yazılmazdı.
    await prefs.remove(_kServerSyncedVersion);
  }

  /// Rızayı geri alır (hesap silme / çıkış senaryolarında).
  Future<void> revoke() async {
    state = const ConsentState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccepted);
    await prefs.remove(_kVersion);
    await prefs.remove(_kAt);
    // Yeni bir rıza alınırsa tekrar sunucuya yazılabilsin.
    await prefs.remove(_kServerSyncedVersion);
  }

  /// A2 (KVKK §10.6.3, §14.2.3) — Yerelde alınmış açık rızayı sunucudaki
  /// denetim iznine yazar. Auth tamamlandığında ([postLoginSyncProvider])
  /// çağrılır; OTP doğrulanmadan önce kullanıcının JWT'si olmadığı için
  /// kayıt ekranında değil burada gönderilir.
  ///
  /// Aynı sürümü tekrar göndermez (backend append-only). Hata durumunda
  /// sessizce yutar — bir sonraki login'de yeniden denenir.
  Future<void> syncToServer(ConsentRepository repo) async {
    if (!state.accepted || state.version < 1) return;

    final prefs = await SharedPreferences.getInstance();
    final synced = prefs.getInt(_kServerSyncedVersion) ?? 0;
    if (synced >= state.version) return; // zaten yazılmış

    await repo.submitConsent(version: state.version, accepted: true);
    await prefs.setInt(_kServerSyncedVersion, state.version);
  }
}

final consentProvider =
    NotifierProvider<ConsentNotifier, ConsentState>(ConsentNotifier.new);
