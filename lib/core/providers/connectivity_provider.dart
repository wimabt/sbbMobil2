import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Uygulama genelinde ağ bağlantısı durumu.
enum AppConnectivity {
  /// İnternet bağlantısı var.
  online,

  /// İnternet bağlantısı yok.
  offline,

  /// Bağlantı var ama yavaş/kararsız (örn. 2G, geçici paket kaybı).
  degraded,
}

/// Ağ bağlantısı değişikliklerini yayınlayan StreamProvider.
///
/// `StreamProvider` olduğu için:
///   - İlk değer `AsyncLoading` gelir (bağlantı henüz bilinmiyor)
///   - Bağlantı değiştiğinde otomatik olarak yeniden değer yayınlar
///   - `.autoDispose` ile gereksiz listener kaçakları önlenir
///
/// **Kullanım:**
/// ```dart
/// final conn = ref.watch(connectivityProvider);
/// conn.when(
///   data: (status) => status == AppConnectivity.offline
///       ? const OfflineBanner()
///       : const SizedBox.shrink(),
///   loading: () => const SizedBox.shrink(),
///   error: (_, __) => const SizedBox.shrink(),
/// );
/// ```
final connectivityProvider = StreamProvider.autoDispose<AppConnectivity>((ref) {
  final connectivity = Connectivity();

  return connectivity.onConnectivityChanged.map((results) {
    // connectivity_plus v6+ bir List<ConnectivityResult> döndürür
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return AppConnectivity.offline;
    }
    return AppConnectivity.online;
  });
});

/// Anlık bağlantı durumu için yardımcı provider.
///
/// `StreamProvider`'ın aksine, tek seferlik sorgular için kullanılır.
/// Örn: Force-logout öncesinde "gerçekten offline mi?" kontrolü.
final isOfflineProvider = FutureProvider.autoDispose<bool>((ref) async {
  final results = await Connectivity().checkConnectivity();
  return results.isEmpty || results.contains(ConnectivityResult.none);
});
