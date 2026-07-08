import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

/// SSL public-key (SPKI) pinning helper.
///
/// Configuration is done via `--dart-define` to avoid hardcoding cert pins.
///
/// - `SSL_PINNING_ENABLED` (bool, default: true)
/// - `SSL_PINNED_SHA256` (string, comma-separated)
///    **SPKI** (SubjectPublicKeyInfo DER) SHA-256 pinleri. Geriye uyumluluk
///    için tam sertifika (DER) SHA-256 hash'i de kabul edilir.
///    Example values (either form is accepted):
///      - `sha256/BASE64...`
///      - `BASE64...`
///    Üretim komutu (canlı sunucudan):
///      openssl s_client -connect HOST:443 -servername HOST </dev/null \
///        | openssl x509 -pubkey -noout \
///        | openssl pkey -pubin -outform der \
///        | openssl dgst -sha256 -binary | openssl enc -base64
/// - `SSL_PINNED_HOSTS` (string, comma-separated, optional)
///    If provided, pins are enforced only for these hosts.
///    Boşsa yalnızca Dio'nun baseUrl host'u için uygulanır.
///
/// Neden SPKI (sertifika hash'i değil)?
/// - Let's Encrypt sertifikayı ~60 günde bir yeniler → sertifika DER'i her
///   yenilemede değişir, pin kırılır. SPKI ise **private key aynı kaldığı
///   sürece** sabittir (sunucuda `reuse_key` şart —
///   bkz. docs/SSL_PINNING_SERVER_SETUP.md).
///
/// Neden `validateCertificate` (yalnız `badCertificateCallback` değil)?
/// - `badCertificateCallback` SADECE sistem doğrulamasından GEÇEMEYEN
///   sertifikalarda tetiklenir; sistemce geçerli görünen bir MITM
///   sertifikasını hiç görmez. `IOHttpClientAdapter.validateCertificate`
///   ise HER bağlantıda çalışır → gerçek pinning.
///
/// Behavior:
/// - If pinning enabled and HTTPS is used:
///   - If no pins are configured:
///     - debug: allow (warn)
///     - release: fail closed (secure by default)
class SslPinning {
  SslPinning._();

  static const bool enabled = bool.fromEnvironment(
    'SSL_PINNING_ENABLED',
    defaultValue: true,
  );

  static const String _pinsRaw = String.fromEnvironment(
    'SSL_PINNED_SHA256',
    defaultValue: '',
  );

  static const String _hostsRaw = String.fromEnvironment(
    'SSL_PINNED_HOSTS',
    defaultValue: '',
  );

  /// If true, missing pin configuration in release throws and blocks requests.
  /// Release build scriptleri (`scripts/build_release.*`) bunu `true` geçer;
  /// pin'siz/yanlış konfigürasyonlu release paketi sessizce çıkamaz.
  static const bool strictMode = bool.fromEnvironment(
    'SSL_PINNING_STRICT',
    defaultValue: false,
  );

  static List<String> get pinnedSha256Base64 {
    final raw = _pinsRaw.trim();
    if (raw.isEmpty) return const <String>[];
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map(_normalizePin)
        .toList(growable: false);
  }

  static Set<String> get pinnedHosts {
    final raw = _hostsRaw.trim();
    if (raw.isEmpty) return const <String>{};
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  static String _normalizePin(String pin) {
    final p = pin.trim();
    if (p.startsWith('sha256/')) return p.substring('sha256/'.length);
    return p;
  }

  /// Bu host için pin zorunlu mu?
  ///
  /// `SSL_PINNED_HOSTS` verilmişse yalnız o listedekiler; verilmemişse
  /// yalnız [baseHost] (API host'u). Diğer host'lar (ör. CDN, OSRM)
  /// sistem TLS doğrulamasıyla devam eder.
  static bool _shouldEnforceForHost(String host, String baseHost) {
    final hosts = pinnedHosts;
    if (hosts.isNotEmpty) return hosts.contains(host);
    return host == baseHost;
  }

  static bool _isHttpsBaseUrl(String baseUrl) {
    final parsed = Uri.tryParse(baseUrl);
    return parsed != null && parsed.scheme == 'https';
  }

  // ── SPKI çıkarımı ─────────────────────────────────────────────────────────
  //
  // `dart:io`nun X509Certificate'i ham public key erişimi vermez; SPKI
  // bloğunu sertifika DER'inden minimal bir ASN.1 (TLV) yürüyüşüyle çıkarırız:
  //
  //   Certificate ::= SEQUENCE {
  //     tbsCertificate ::= SEQUENCE {
  //       [0] version OPTIONAL, serialNumber, signature,
  //       issuer, validity, subject,
  //       subjectPublicKeyInfo,   ← hedef (tam TLV bloğu)
  //       ... }
  //     signatureAlgorithm, signatureValue }

  /// [der] içinde [offset]'teki TLV'nin (contentStart, end) çiftini döner.
  static (int, int) _readTlv(Uint8List der, int offset) {
    if (offset + 2 > der.length) {
      throw const FormatException('DER: beklenmedik son');
    }
    final lenByte = der[offset + 1];
    int contentStart;
    int length;
    if (lenByte < 0x80) {
      length = lenByte;
      contentStart = offset + 2;
    } else {
      final numBytes = lenByte & 0x7F;
      if (numBytes == 0 || numBytes > 4 || offset + 2 + numBytes > der.length) {
        throw const FormatException('DER: geçersiz uzunluk');
      }
      length = 0;
      for (var i = 0; i < numBytes; i++) {
        length = (length << 8) | der[offset + 2 + i];
      }
      contentStart = offset + 2 + numBytes;
    }
    final end = contentStart + length;
    if (end > der.length) {
      throw const FormatException('DER: uzunluk taşması');
    }
    return (contentStart, end);
  }

  /// Sertifika DER'inden SubjectPublicKeyInfo bloğunu (tam TLV) çıkarır.
  /// Parse edilemezse `null` (çağıran fail-closed davranır).
  @visibleForTesting
  static Uint8List? extractSpkiDer(Uint8List certDer) {
    try {
      // Certificate → tbsCertificate
      final (certContent, _) = _readTlv(certDer, 0);
      final (tbsContent, _) = _readTlv(certDer, certContent);

      var offset = tbsContent;
      // [0] version (opsiyonel, context-specific tag 0xA0)
      if (certDer[offset] == 0xA0) {
        final (_, end) = _readTlv(certDer, offset);
        offset = end;
      }
      // serialNumber, signature, issuer, validity, subject → atla
      for (var i = 0; i < 5; i++) {
        final (_, end) = _readTlv(certDer, offset);
        offset = end;
      }
      // subjectPublicKeyInfo: tam TLV bloğu (tag + length + content)
      final (_, spkiEnd) = _readTlv(certDer, offset);
      return Uint8List.sublistView(certDer, offset, spkiEnd);
    } on FormatException {
      return null;
    } on RangeError {
      return null;
    }
  }

  /// Sertifika, konfigüre edilmiş pin'lerden birine uyuyor mu?
  ///
  /// Önce SPKI SHA-256 (tercih edilen), sonra geriye uyumluluk için tam
  /// sertifika DER SHA-256 karşılaştırılır.
  @visibleForTesting
  static bool matchesPins(X509Certificate cert) {
    final pins = pinnedSha256Base64;
    if (pins.isEmpty) return false;

    final der = Uint8List.fromList(cert.der);

    final spki = extractSpkiDer(der);
    if (spki != null) {
      final spkiHash = base64.encode(sha256.convert(spki).bytes);
      if (pins.contains(spkiHash)) return true;
    }

    // Legacy: tam sertifika hash'i de pin olarak kabul edilir.
    final certHash = base64.encode(sha256.convert(der).bytes);
    if (pins.contains(certHash)) return true;

    if (kDebugMode) {
      debugPrint(
        '🚫 [SslPinning] Pin mismatch: '
        'spki=sha256/${spki == null ? '<parse-error>' : base64.encode(sha256.convert(spki).bytes)} '
        'cert=sha256/$certHash',
      );
    }
    return false;
  }

  static void configureDio(Dio dio) {
    if (!enabled) return;

    final baseUrl = dio.options.baseUrl;
    if (!_isHttpsBaseUrl(baseUrl)) return;

    final pins = pinnedSha256Base64;
    if (pins.isEmpty) {
      final message =
          '⚠️ [SslPinning] HTTPS kullanılıyor ama SSL_PINNED_SHA256 set edilmemiş. '
          'Pinning uygulanmadan sistem TLS doğrulaması kullanılacak. '
          'Sert fail için --dart-define=SSL_PINNING_STRICT=true verin.';
      debugPrint(message);
      if (!kDebugMode && strictMode) {
        throw StateError(
          'SSL pinning etkin ama SSL_PINNED_SHA256 konfigüre edilmemiş (release strict mode).',
        );
      }
      return;
    }

    final baseHost = Uri.parse(baseUrl).host;
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => createPinnedHttpClient(baseUrl: baseUrl),
      // HER bağlantıda çalışır (sistemce geçerli sertifikalar dahil).
      validateCertificate: (cert, host, port) {
        if (!_shouldEnforceForHost(host, baseHost)) return true;
        if (cert == null) return false;
        return matchesPins(cert);
      },
    );
  }

  /// Ham `HttpClient` kullanan yerler için (ör. QR SSE stream'i).
  ///
  /// Not: `badCertificateCallback` yalnız sistem doğrulamasından geçemeyen
  /// sertifikalarda tetiklenir. Release'te kullanıcı CA'larına güvenilmediği
  /// için (network_security_config) MITM proxy sertifikaları buraya düşer ve
  /// pin kontrolüyle reddedilir.
  static HttpClient createPinnedHttpClient({required String baseUrl}) {
    final base = Uri.parse(baseUrl);
    final pins = pinnedSha256Base64;

    final client = HttpClient();
    client.badCertificateCallback = (cert, host, _) {
      if (!_shouldEnforceForHost(host, base.host)) {
        // Pin kapsamı dışındaki host'un geçersiz sertifikası → reddet
        // (sistem varsayılanıyla aynı davranış).
        return false;
      }

      if (pins.isEmpty) {
        if (kDebugMode) return true;
        return false;
      }

      return matchesPins(cert);
    };
    return client;
  }
}
