import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/active_locale.dart';
import '../network/api_service.dart';
import '../network/ssl_pinning.dart';
import '../../api/endpoints.dart';
import '../../l10n/l10n.dart';

/// QR ile puan harcama servisi (kullanıcı tarafı)
///
/// staff_mobile.md §10 akışına göre:
///
/// **Birincil mod — `POST /api/v1/mobile/wallet/generate-qr`**
/// - 60 saniyelik token üretir; `qr_data` (QR görseli için) + `numeric_code` (sayısal kod) döner.
/// - 60 saniye sonra otomatik olarak yeni token üretilir.
///
/// **Arka plan — SSE `GET /api/v1/mobile/qr/stream`**
/// - Sadece `pos_redeemed` / `redeemed` event'lerini dinler.
/// - QR görseli için SSE'den gelen `qr_data` KULLANILMAZ; sadece harcama bildirimi için.
///
/// **Kapatma — `DELETE /api/v1/mobile/qr/session`**
/// - QR ekranı kapandığında çağrılır.
class QRSpendingService {
  QRSpendingService(this._apiService);

  final ApiService _apiService;

  /// SSE HTTP client ve subscription (sadece redeemed event'leri için)
  HttpClient? _httpClient;
  StreamSubscription<String>? _sseSubscription;

  /// 60 saniyelik token yenileme timer'ı
  Timer? _renewTimer;

  /// Yeni QR üretildiğinde tetiklenir.
  /// [qrData]: QR görseline encode edilecek base64url string (backend token).
  /// [numericCode]: Vatandaşın sözel iletebileceği "XXX-XXX" formatı.
  /// [balance]: Mevcut puan bakiyesi.
  /// [expiresIn]: Token geçerlilik süresi (saniye).
  void Function(
    String qrData,
    String numericCode,
    int balance,
    int expiresIn,
  )? onQRUpdated;

  /// POS checkout tamamlandığında tetiklenir (pos_redeemed / redeemed SSE event).
  void Function(int amount, int balanceAfter, String message)? onRedeemed;

  /// Herhangi bir hata oluştuğunda tetiklenir.
  void Function(String error)? onError;

  Dio get _dio => _apiService.dio;

  Uri _normalizeBaseUri(Uri base) {
    var path = base.path;
    if (path.endsWith('/')) path = path.substring(0, path.length - 1);
    if (path.endsWith('/api/v1')) {
      path = path.substring(0, path.length - '/api/v1'.length);
      if (path.isEmpty) path = '/';
    }
    return base.replace(path: path);
  }

  Uri _buildSseUri() {
    final base = _normalizeBaseUri(Uri.parse(ApiService.baseUrl));
    final basePath = base.path == '/' ? '' : base.path;
    return base.replace(path: '$basePath${ApiEndpoints.mobileQrStream}');
  }

  // ─── Public API ───────────────────────────────────────────────────

  /// QR ekranı açıldığında çağrılmalı.
  /// Hemen `generate-qr` çağırır; arka planda SSE'yi başlatır.
  Future<void> startQRSession() async {
    await stopQRSession();
    await _generateNewToken();
    _startSseListener();
  }

  /// QR ekranı kapandığında çağrılmalı.
  Future<void> stopQRSession() async {
    _renewTimer?.cancel();
    _renewTimer = null;

    await _sseSubscription?.cancel();
    _sseSubscription = null;
    _httpClient?.close(force: true);
    _httpClient = null;

    try {
      await _dio.delete(ApiEndpoints.mobileQrSession);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [QRSpendingService] Failed to close QR session: $e');
      }
    }
  }

  void dispose() {
    _renewTimer?.cancel();
    _sseSubscription?.cancel();
    _httpClient?.close(force: true);
  }

  // ─── Token generation ─────────────────────────────────────────────

  /// POST /api/v1/mobile/wallet/generate-qr
  /// Döner: data.qr_data + data.numeric_code + data.expires_in + data.total_points
  Future<void> _generateNewToken() async {
    try {
      final response =
          await _dio.post(ApiEndpoints.mobileWalletGenerateQr);
      final data = response.data['data'] as Map<String, dynamic>?;
      if (data == null) throw StateError('generate-qr: no data field');

      final qrData = data['qr_data'] as String?;
      final numericCode =
          (data['numeric_code'] as String?)?.replaceAll('-', '') ?? '';
      final balance = (data['total_points'] as num?)?.toInt() ?? 0;
      final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 60;

      if (qrData == null || qrData.isEmpty) {
        throw StateError('generate-qr: qr_data is empty');
      }

      onQRUpdated?.call(qrData, numericCode, balance, expiresIn);

      // Schedule next renewal slightly before expiry (5s buffer)
      final renewAfter = Duration(seconds: (expiresIn - 5).clamp(5, 120));
      _renewTimer?.cancel();
      _renewTimer = Timer(renewAfter, _generateNewToken);
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [QRSpendingService] generate-qr failed: $e');
      }
      final l10n = lookupAppLocalizations(
          Locale(ActiveLocale.cachedLanguageCode));
      final msg = e.response?.data is Map
          ? (e.response!.data['message'] as String? ?? l10n.qrCreateFailed)
          : l10n.qrCreateFailed;
      onError?.call(msg);
      // Retry after 10 seconds on error
      _renewTimer?.cancel();
      _renewTimer = Timer(const Duration(seconds: 10), _generateNewToken);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔥 [QRSpendingService] Unexpected error: $e');
      }
      onError?.call('QR oluşturulamadı');
      _renewTimer?.cancel();
      _renewTimer = Timer(const Duration(seconds: 10), _generateNewToken);
    }
  }

  // ─── SSE listener (only for redeemed events) ──────────────────────

  void _startSseListener() {
    final streamUrl = _buildSseUri();
    _connectSse(streamUrl);
  }

  Future<void> _connectSse(Uri streamUrl) async {
    try {
      final accessToken = await _apiService.getAccessToken();
      if (kDebugMode) {
        debugPrint(
          'ℹ️ [QRSpendingService] SSE connect → $streamUrl',
        );
      }

      _httpClient = SslPinning.enabled && streamUrl.scheme == 'https'
          ? SslPinning.createPinnedHttpClient(baseUrl: ApiService.baseUrl)
          : HttpClient();
      final request = await _httpClient!.getUrl(streamUrl);
      if (accessToken != null) {
        request.headers
            .set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
      }
      request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');

      final response = await request.close();
      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ [QRSpendingService] SSE status=${response.statusCode}',
          );
        }
        return; // SSE olmadan devam et; generate-qr yeterli
      }

      String? eventName;
      final dataLines = <String>[];

      _sseSubscription = response
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          if (line.isEmpty) {
            if (dataLines.isNotEmpty) {
              _handleSseEvent(eventName, dataLines);
            }
            eventName = null;
            dataLines.clear();
            return;
          }
          if (line.startsWith('event:')) {
            eventName = line.substring(6).trim();
          } else if (line.startsWith('data:')) {
            dataLines.add(line);
          }
        },
        onError: (_) {/* SSE koptu, generate-qr devam ediyor */},
        onDone: () {/* SSE kapandı, generate-qr devam ediyor */},
        cancelOnError: true,
      );
    } catch (_) {
      // SSE bağlanamadı — generate-qr akışı yeterli, sessizce devam et
    }
  }

  void _handleSseEvent(String? eventName, List<String> dataLines) {
    if (eventName != 'redeemed' && eventName != 'pos_redeemed') return;
    try {
      final dataString = dataLines
          .map((l) => l.startsWith('data:') ? l.substring(5).trim() : l)
          .join('\n');
      final data = jsonDecode(dataString) as Map<String, dynamic>;
      final amount =
          ((data['amount'] ?? data['total_deducted'] ?? 0) as num).toInt();
      final balanceAfter = ((data['balance_after'] ?? 0) as num).toInt();
      final message = data['message']?.toString() ??
          lookupAppLocalizations(Locale(ActiveLocale.cachedLanguageCode))
              .qrPointsSpent(amount);
      onRedeemed?.call(amount, balanceAfter, message);
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ [QRSpendingService] Failed to parse redeemed event: $e',
        );
      }
    }
  }
}

/// Staff uygulaması için QR harcama servisi
///
/// flutter-integration.md §18.3'teki `StaffQRService`'e karşılık gelir.
class StaffQRService {
  StaffQRService(this._apiService);

  final ApiService _apiService;

  Dio get _dio => _apiService.dio;

  /// QR kodunu okut ve puan harca.
  ///
  /// Endpoint: `POST /api/v1/staff/qr/redeem`
  Future<Map<String, dynamic>> redeemPoints({
    required String qrToken,
    required int amount,
    String? description,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.staffQrRedeem,
      data: <String, dynamic>{
        'qr_token': qrToken,
        'amount': amount,
        'description': ?description,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Staff işlem geçmişi
  ///
  /// Endpoint: `GET /api/v1/staff/transactions`
  Future<Map<String, dynamic>> getTransactions({int page = 1, int limit = 20}) async {
    final response = await _dio.get(
      ApiEndpoints.staffTransactions,
      queryParameters: <String, dynamic>{
        'page': page,
        'limit': limit,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Çalışan profili
  ///
  /// Endpoint: `GET /api/v1/staff/profile`
  Future<Map<String, dynamic>> getProfile() async {
    final response = await _dio.get(ApiEndpoints.staffProfile);
    final data = response.data as Map<String, dynamic>;
    return data['data'] as Map<String, dynamic>;
  }
}

/// Riverpod provider – Kullanıcı QR harcama servisi
final qrSpendingServiceProvider = Provider<QRSpendingService>((ref) {
  final api = ref.watch(apiServiceProvider);
  final service = QRSpendingService(api);

  ref.onDispose(service.dispose);

  return service;
});

/// Riverpod provider – Staff QR servisi
final staffQRServiceProvider = Provider<StaffQRService>((ref) {
  final api = ref.watch(apiServiceProvider);
  return StaffQRService(api);
});

