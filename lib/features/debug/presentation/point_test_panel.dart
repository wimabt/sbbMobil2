import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/services/discovery_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/point_collection_service.dart';
import '../../../core/utils/distance_helper.dart';
import '../../../data/models/models.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/presentation/providers/point_collection_provider.dart';
import '../../home/presentation/providers/points_provider.dart';

/// Mobile endpoint'ten puanlı mekanları çeker.
/// Normal placesProvider /places kullanırken bu provider /api/v1/mobile/places
/// kullanır — dolayısıyla points, visited, visit_count alanları döner.
final _mobilePlacesProvider = FutureProvider.autoDispose<List<Place>>((ref) async {
  final discovery = ref.watch(discoveryServiceProvider);

  final List<Place> all = [];
  int page = 1;
  bool hasMore = true;

  while (hasMore) {
    final raw = await discovery.getPlaces(page: page, limit: 100);
    final list = (raw['data'] as List?) ?? [];
    if (list.isEmpty) break;

    for (final item in list) {
      all.add(Place.fromJson(item as Map<String, dynamic>));
    }

    final meta = raw['meta'] as Map<String, dynamic>?;
    hasMore = meta?['hasNext'] == true || meta?['has_next'] == true;
    page++;
    if (page > 50) break;
  }

  return all;
});

/// Debug/Test paneli — Fiziksel cihazda puan toplama akışını test etmek için.
///
/// Sadece kDebugMode'da erişilebilir.
/// Puanlı mekanları listeler, konumu simüle eder, mesafe durumunu gösterir.
class PointTestPanel extends ConsumerStatefulWidget {
  const PointTestPanel({super.key});

  @override
  ConsumerState<PointTestPanel> createState() => _PointTestPanelState();
}

class _PointTestPanelState extends ConsumerState<PointTestPanel> {
  _SimDistance _selectedDistance = _SimDistance.onTop;
  Place? _selectedPlace;
  String? _statusMessage;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final isLoggedIn = authState.status == AuthStatus.authenticated;
    final mobilePlacesAsync = ref.watch(_mobilePlacesProvider);
    final pointsAsync = ref.watch(pointsBalanceProvider);
    final collectionStates = ref.watch(pointCollectionProvider);

    final mockActive = LocationService.mockLocation != null;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Puan Test Paneli'),
        actions: [
          if (mockActive)
            TextButton.icon(
              onPressed: _clearMock,
              icon: const Icon(Icons.gps_fixed, size: 18),
              label: const Text('Gerçek GPS'),
            ),
        ],
      ),
      body: !isLoggedIn
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Test panelini kullanmak için giriş yapmalısınız.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : mobilePlacesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(
                        'Mobile API hatası:\n$err',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => ref.invalidate(_mobilePlacesProvider),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (allMobilePlaces) {
                final pointPlaces = allMobilePlaces
                    .where((p) =>
                        p.points != null &&
                        p.points! > 0 &&
                        p.lat != null &&
                        p.lng != null)
                    .toList()
                  ..sort(
                      (a, b) => (b.points ?? 0).compareTo(a.points ?? 0));

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildStatusCard(context, isDark, mockActive, pointsAsync),
                    const SizedBox(height: 16),
                    _buildDistanceSelector(context, isDark),
                    const SizedBox(height: 16),
                    if (_statusMessage != null) ...[
                      _buildMessageCard(context, isDark),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Puanlı Mekanlar (${pointPlaces.length})',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          'Toplam: ${allMobilePlaces.length}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).hintColor,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (pointPlaces.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          allMobilePlaces.isEmpty
                              ? 'Mobile API\'den hiç mekan dönmedi.\n'
                                '/api/v1/mobile/places endpoint\'ini ve auth token\'ı kontrol edin.'
                              : '${allMobilePlaces.length} mekan yüklendi ama hiçbirinde puan tanımlı değil.\n'
                                'CMS\'de mekanlara puan atamayı kontrol edin.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ...pointPlaces.map((place) => _buildPlaceCard(
                            context,
                            isDark,
                            place,
                            collectionStates[place.id],
                          )),
                    const SizedBox(height: 80),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context,
    bool isDark,
    bool mockActive,
    AsyncValue<PointsBalance?> pointsAsync,
  ) {
    final mock = LocationService.mockLocation;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: mockActive ? Colors.orange.withAlpha(80) : Colors.transparent,
          width: mockActive ? 2 : 0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                mockActive ? Icons.science : Icons.gps_fixed,
                color: mockActive ? Colors.orange : Colors.green,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                mockActive ? 'MOCK KONUM AKTİF' : 'Gerçek GPS',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: mockActive ? Colors.orange : Colors.green,
                    ),
              ),
            ],
          ),
          if (mock != null) ...[
            const SizedBox(height: 4),
            Text(
              '${mock.latitude.toStringAsFixed(6)}, ${mock.longitude.toStringAsFixed(6)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: Theme.of(context).hintColor,
                  ),
            ),
          ],
          const Divider(height: 20),
          pointsAsync.when(
            data: (balance) => Row(
              children: [
                _miniStat(context, 'Puan', '${balance?.totalPoints ?? 0}'),
                _miniStat(context, 'Ziyaret', '${balance?.placesVisited ?? 0}'),
                _miniStat(context, 'Rütbe', balance?.rank ?? '-'),
              ],
            ),
            loading: () => const Text('Yükleniyor...'),
            error: (_, _) => const Text('Puan bilgisi alınamadı'),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(BuildContext context, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceSelector(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Simülasyon Mesafesi',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _SimDistance.values.map((d) {
            final selected = d == _selectedDistance;
            return ChoiceChip(
              label: Text(d.label),
              selected: selected,
              onSelected: (_) => setState(() => _selectedDistance = d),
              avatar: Icon(d.icon, size: 16),
              selectedColor: d.color.withAlpha(40),
              labelStyle: TextStyle(
                color: selected ? d.color : null,
                fontWeight: selected ? FontWeight.w600 : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMessageCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.neonBlue.withAlpha(15)
            : Colors.blue.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? AppColors.neonBlue.withAlpha(40)
              : Colors.blue.withAlpha(30),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: isDark ? AppColors.neonBlue : Colors.blue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusMessage!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceCard(
    BuildContext context,
    bool isDark,
    Place place,
    PointCollectionState? collectionState,
  ) {
    final isSelected = _selectedPlace?.id == place.id;
    final status = collectionState?.status ?? PointCollectionStatus.noPoints;
    final statusColor = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: Colors.orange, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _onPlaceTap(place),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Puan badge
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '+${place.points}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                        Text(
                          'P',
                          style: TextStyle(
                            fontSize: 10,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${place.lat!.toStringAsFixed(4)}, ${place.lng!.toStringAsFixed(4)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Theme.of(context).hintColor,
                            ),
                      ),
                      if (collectionState != null &&
                          collectionState.distanceMeters != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Mesafe: ${collectionState.formattedDistance} — ${_statusLabel(status)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ] else if (place.visited) ...[
                        const SizedBox(height: 2),
                        const Text(
                          'Zaten ziyaret edildi',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Aksiyon butonları
                Column(
                  children: [
                    _buildSimButton(
                      context,
                      icon: Icons.my_location,
                      label: 'Sim',
                      color: Colors.orange,
                      onTap: () => _simulateLocation(place),
                    ),
                    const SizedBox(height: 4),
                    if (status == PointCollectionStatus.withinRange)
                      _buildSimButton(
                        context,
                        icon: Icons.star_rounded,
                        label: 'Topla',
                        color: Colors.green,
                        onTap: () => _collectPoints(place),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 56,
      child: Material(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                Icon(icon, size: 16, color: color),
                Text(
                  label,
                  style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Aksiyonlar ───────────────────────────────────────────────

  void _onPlaceTap(Place place) {
    setState(() => _selectedPlace = place);
    _simulateLocation(place);
  }

  void _simulateLocation(Place place) {
    if (place.lat == null || place.lng == null) return;

    final target = LatLng(place.lat!, place.lng!);
    final simulated = _selectedDistance.offsetFrom(target);

    LocationService.setMockLocation(simulated);

    final distance = DistanceHelper.calculateHaversineDistance(simulated, target);
    final status = PointCollectionService.statusFromDistance(distance);

    setState(() {
      _selectedPlace = place;
      _statusMessage = '${place.name} için konum simüle edildi:\n'
          '${_selectedDistance.label} → '
          '${DistanceHelper.formatDistance(distance)} uzakta → '
          '${_statusLabel(status)}';
    });

    // Proximity kontrolünü tetikle
    ref.read(pointCollectionProvider.notifier).startProximityCheck(place);
  }

  void _collectPoints(Place place) {
    ref.read(pointCollectionProvider.notifier).collectPlace(place.id);
    setState(() {
      _statusMessage = '${place.name} için puan toplama isteği gönderildi...';
    });
  }

  void _clearMock() {
    LocationService.setMockLocation(null);
    setState(() {
      _selectedPlace = null;
      _statusMessage = 'Gerçek GPS konumuna geri dönüldü.';
    });
  }

  Color _statusColor(PointCollectionStatus status) {
    switch (status) {
      case PointCollectionStatus.withinRange:
        return Colors.green;
      case PointCollectionStatus.nearby:
        return Colors.blue;
      case PointCollectionStatus.collecting:
        return Colors.orange;
      case PointCollectionStatus.collected:
        return Colors.green;
      case PointCollectionStatus.alreadyCollected:
        return Colors.green;
      case PointCollectionStatus.campaignUpcoming:
        return Colors.blueGrey;
      case PointCollectionStatus.campaignExpired:
        return Colors.grey;
      case PointCollectionStatus.error:
        return Colors.red;
      case PointCollectionStatus.velocityAnomaly:
        return Colors.orange;
      case PointCollectionStatus.noPoints:
      case PointCollectionStatus.tooFar:
        return Colors.grey;
    }
  }

  String _statusLabel(PointCollectionStatus status) {
    switch (status) {
      case PointCollectionStatus.noPoints:
        return 'Puansız';
      case PointCollectionStatus.tooFar:
        return 'Uzakta';
      case PointCollectionStatus.nearby:
        return 'Yakın';
      case PointCollectionStatus.withinRange:
        return 'Kabul sınırı içinde!';
      case PointCollectionStatus.alreadyCollected:
        return 'Alındı';
      case PointCollectionStatus.campaignUpcoming:
        return 'Kampanya Yakında';
      case PointCollectionStatus.campaignExpired:
        return 'Kampanya Bitti';
      case PointCollectionStatus.collecting:
        return 'Toplanıyor...';
      case PointCollectionStatus.collected:
        return 'Kazanıldı!';
      case PointCollectionStatus.error:
        return 'Hata';
      case PointCollectionStatus.velocityAnomaly:
        return 'Hız Anomali';
    }
  }
}

/// Simülasyon mesafe seçenekleri
enum _SimDistance {
  onTop(
    label: 'Tam üzerinde (0m)',
    icon: Icons.gps_fixed,
    color: Colors.green,
    offsetMeters: 0,
  ),
  within50(
    label: '50m içinde',
    icon: Icons.near_me,
    color: Colors.green,
    offsetMeters: 50,
  ),
  within150(
    label: '~150m (yakın)',
    icon: Icons.radar,
    color: Colors.blue,
    offsetMeters: 150,
  ),
  at500(
    label: '~500m (uzak)',
    icon: Icons.location_off,
    color: Colors.orange,
    offsetMeters: 500,
  ),
  at2km(
    label: '~2km (çok uzak)',
    icon: Icons.wrong_location,
    color: Colors.red,
    offsetMeters: 2000,
  );

  const _SimDistance({
    required this.label,
    required this.icon,
    required this.color,
    required this.offsetMeters,
  });

  final String label;
  final IconData icon;
  final Color color;
  final double offsetMeters;

  /// Hedef koordinattan [offsetMeters] metre kuzeye kaydır.
  /// 1 derece enlem ~ 111,320 metre
  LatLng offsetFrom(LatLng target) {
    if (offsetMeters == 0) return target;
    final latOffset = offsetMeters / 111320.0;
    return LatLng(target.latitude + latOffset, target.longitude);
  }
}
