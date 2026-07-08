import 'dart:math' as math;

import 'package:ar_flutter_plugin_2/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin_2/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_2/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_2/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_2/models/ar_anchor.dart';
import 'package:ar_flutter_plugin_2/models/ar_node.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../../../../core/services/ar_sensor_service.dart';
import '../../../../core/services/log_service.dart';
import '../../../../core/utils/image_url_helper.dart';
import '../../../../data/models/ar_point.dart';
import '../providers/ar_geo_provider.dart';

const _tag = 'ArModelScene';

/// Aynı anda sahnede tutulacak azami 3B model sayısı (kalabalık/performans).
const int _kMaxModels = 4;

/// Modelin yerleştirileceği rahat AR mesafesi aralığı (metre). Gerçek POI
/// mesafesi bu aralığa sıkıştırılır — 500 m uzaktaki bir modeli oraya koymak
/// anlamsız; yön doğru kalır, mesafe görünür bir uzaklığa indirilir.
const double _kMinPlaceDist = 1.5;
const double _kMaxPlaceDist = 6.0;

/// POI'nin `radius_m`'ine eklenen GPS-gürültüsü payı (metre). Sınırın hemen
/// dışındaki (GPS jitter'ı yüzünden 25 m yerine 35 m ölçülen) 3B modellerin de
/// sahnede görünmesini sağlar. Model yine `_kMaxPlaceDist`'e klamplı render olur.
const double _kPlacementToleranceM = 20.0;

/// Kaldırma toleransı (m) — yerleşmiş modelin korunacağı menzil. Yerleştirme
/// toleransından geniş tutulur (histerezis): GPS sınırda zıplarken model
/// sürekli kaldırılıp yeniden eklenmesin diye.
const double _kRemovalToleranceM = 60.0;

/// Modelin baş aşağı/ters gelmesini düzelten model-yerel X-ekseni dönüşü (°).
/// 180 = baş aşağı→dik. Sorun farklı eksendeyse değiştir, düzgünse 0 yap.
const double _kModelFlipXDeg = 180.0;

/// Drift-free yerleştirme: modeli ARCore **Anchor**'a bağla — konumu ARCore
/// takip eder, dünya yeniden konumlanınca model kaymaz ("yüzme" biter).
/// Anchor konumu taşır, node yön+ölçeği (yerel) taşır. Sorun çıkarsa `false`
/// yap → eski (anchor'sız) çalışan yola anında döner. **Geri-alınabilir bayrak.**
const bool _kUseAnchors = true;

/// Uygulama-içi ARCore/ARKit sahnesi (`ar_flutter_plugin_2`).
///
/// Canlı kamerayı native/GPU ile render eder (Flutter `camera` Texture'ı gibi
/// donmaz) ve **`content_type == 'model_3d'` olan POI'lerin 3B modellerini
/// otomatik olarak**, gerçek dünya yön/mesafesine göre sahneye yerleştirir
/// (kart yok, dokunma yok — kullanıcı o yöne döndüğünde modeli orada görür).
///
/// Etkileşim:
///   • tek parmak sürükle → dokunulan modeli taşı (native pan)
///   • iki parmak → pinch ile aktif modeli ölçekle + döndür (Flutter `Listener`)
///
/// Cihaz ARCore/ARKit desteklemiyorsa session açılışı hata verir →
/// [onUnavailable] ile çağıran ekran kamera-overlay fallback'ine düşer (orada
/// 3B model kartla cihazın native AR uygulamasında açılır).
class ArModelScene extends ConsumerStatefulWidget {
  const ArModelScene({super.key, required this.onUnavailable});

  /// AR oturumu başlatılamadığında çağrılır; çağıran ekran fallback'e geçmeli.
  final VoidCallback onUnavailable;

  @override
  ConsumerState<ArModelScene> createState() => _ArModelSceneState();
}

class _ArModelSceneState extends ConsumerState<ArModelScene>
    with WidgetsBindingObserver {
  ARSessionManager? _sessionManager;
  ARObjectManager? _objectManager;
  ARAnchorManager? _anchorManager;

  /// POI id → yerleştirilmiş node.
  final Map<String, ARNode> _nodes = {};

  /// POI id → modeli taşıyan ARCore anchor'ı (yalnız anchor modunda dolu).
  final Map<String, ARPlaneAnchor> _anchors = {};

  /// Yerleştirme devam eden POI id'leri (yeniden tetiklenmesin).
  final Set<String> _placing = {};

  bool _arViewReady = false;
  int _arViewGeneration = 0;
  bool _isBackgrounded = false;
  bool _reportedUnavailable = false;

  /// AR teşhis logu — release dahil görünür (`print`; release'de `debugPrint`
  /// no-op). Filtre: `adb logcat | findstr AR-DIAG`.
  void _arLog(String m) {
    // ignore: avoid_print
    print('🛰️ [AR-DIAG][scene] $m');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionManager?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Sadece gerçek arka plana geçişte teardown; `inactive` (çoklu-dokunuş /
    // kenar geri-jesti / bildirim gölgesi gibi geçici olaylar) yok sayılır —
    // aksi halde jest sırasında sahne yok olup model kaybolur.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (_isBackgrounded) return;
      _sessionManager?.dispose();
      _sessionManager = null;
      _objectManager = null;
      _anchorManager = null;
      _nodes.clear();
      _anchors.clear();
      _placing.clear();
      if (mounted) {
        setState(() {
          _isBackgrounded = true;
          _arViewReady = false;
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      if (!_isBackgrounded) return;
      if (mounted) {
        setState(() {
          _isBackgrounded = false;
          _arViewGeneration += 1;
        });
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // AR session
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _onARViewCreated(
    ARSessionManager sessionManager,
    ARObjectManager objectManager,
    ARAnchorManager anchorManager,
    ARLocationManager locationManager,
  ) async {
    _sessionManager = sessionManager;
    _objectManager = objectManager;
    _anchorManager = anchorManager;
    try {
      sessionManager.onInitialize(
        showFeaturePoints: false,
        showPlanes: false,
        showWorldOrigin: false,
        // Tüm dokunma jestleri KAPALI — model otomatik yerleşip olduğu yerde
        // sabit kalır (kullanıcı isteği). Native pan'in `onPanEnd` decode'u da
        // bu cihazlarda Map↦List cast hatası atıyordu; kapalı olunca o da yok.
        handleTaps: false,
        handlePans: false,
        handleRotation: false,
        showAnimatedGuide: false,
      );
      objectManager.onInitialize();
      sessionManager.onError = _onArError;
      sessionManager.onPlaneOrPointTap = (_) {};
      _arLog('onARViewCreated OK (jestler kapalı, model sabit)');
      if (mounted) setState(() => _arViewReady = true);
      // İlk senkron: o anda menzilde olan modelleri yerleştir.
      _syncModels();
    } catch (e, st) {
      LogService.e('AR session init failed: $e\n$st', tag: _tag);
      _reportUnavailable();
    }
  }

  void _onArError(String message) {
    LogService.w('AR session error: $message', tag: _tag);
    _reportUnavailable();
  }

  void _reportUnavailable() {
    if (_reportedUnavailable) return;
    _reportedUnavailable = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onUnavailable();
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 3B model senkronizasyonu — geo eşleşmelerine göre otomatik yerleştir/kaldır
  // ═══════════════════════════════════════════════════════════════════════

  void _syncModels() {
    if (!_arViewReady || _objectManager == null) return;
    final geo = ref.read(arGeoControllerProvider);
    final reading = geo.sensor;
    if (reading == null) return;

    // Menzildeki 3B model POI'leri (öncelik/yakınlık sıralı), azami sayıda.
    // NOT: Sıkı `inRadius` yerine GPS gürültüsüne dayanıklı bir mesafe eşiği
    // kullanıyoruz: 3B modeller zaten 1.5–6 m'ye klamplanıp kullanıcının önüne
    // yerleştiği için, sınırın hemen dışındaki (örn. radius 25 m, ölçülen 27–38 m
    // GPS jitter'ı) bir modeli göstermek doğru UX. `_kPlacementToleranceM`
    // payı ile tetiklenir.
    final desired = <ArMatchedPoint>[];
    for (final m in geo.matches) {
      if (m.point.contentType != 'model_3d') continue;
      if ((m.point.modelUrl ?? '').isEmpty) continue;
      final placeLimit = m.point.radiusM + _kPlacementToleranceM;
      if (m.distanceM > placeLimit) continue;
      desired.add(m);
      if (desired.length >= _kMaxModels) break;
    }
    // Yapışkan kaldırma: bir kez yerleşen model, GPS jitter'ı `placeLimit`'i
    // anlık aşsa bile kaldırılmaz (yoksa kaldır→yeniden ekle ile "geziyor").
    // Yalnızca POI eşleşmelerden tamamen çıkınca ya da çok uzaklaşınca (büyük
    // histerezis) kaldırılır.
    final keepIds = <String>{};
    for (final m in geo.matches) {
      if (m.point.contentType != 'model_3d') continue;
      if ((m.point.modelUrl ?? '').isEmpty) continue;
      if (m.distanceM > m.point.radiusM + _kRemovalToleranceM) continue;
      keepIds.add(m.point.id);
    }

    // Eşleşmeden çıkan / çok uzaklaşan modelleri kaldır.
    final toRemove = _nodes.keys.where((id) => !keepIds.contains(id))
        .toList(growable: false);
    for (final id in toRemove) {
      final anchor = _anchors.remove(id);
      final node = _nodes.remove(id);
      if (anchor != null) {
        // Anchor'ı kaldır → child model node'u da birlikte gider (native).
        _anchorManager?.removeAnchor(anchor);
      } else if (node != null) {
        _objectManager?.removeNode(node);
      }
    }
    // Ölçek kontrollerinin görünürlüğü için yalnızca değişimde rebuild
    // (yerleştirme _placeOne içinde ayrıca setState eder).
    if (toRemove.isNotEmpty && mounted) setState(() {});

    // Yeni girenleri yerleştir.
    for (final m in desired) {
      final id = m.point.id;
      if (_nodes.containsKey(id) || _placing.contains(id)) continue;
      _placeOne(m, reading);
    }
  }

  Future<void> _placeOne(ArMatchedPoint match, ArSensorReading reading) async {
    final objectManager = _objectManager;
    final url = match.point.modelUrl;
    if (objectManager == null || url == null || url.isEmpty) return;
    final id = match.point.id;
    _placing.add(id);
    try {
      final resolved = rewriteStorageUrl(url);
      final target = await _geoWorldPose(match, reading.headingDeg);

      final anchorManager = _anchorManager;
      if (_kUseAnchors && anchorManager != null) {
        final placed =
            await _placeAnchored(id, resolved, target, objectManager, anchorManager);
        if (placed) return;
        // Anchor yolu başarısızsa eski (serbest) yola düş.
        _arLog('placeOne[$id] anchor yolu başarısız → serbest node\'a düşülüyor');
      }
      await _placeFreeNode(id, resolved, target, objectManager);
    } catch (e) {
      _arLog('❌ placeOne[$id] FIRLATTI: ${e.runtimeType} → $e');
      LogService.w('placeOne threw for $id: $e', tag: _tag);
    } finally {
      _placing.remove(id);
    }
  }

  /// Drift-free: konumu ARCore anchor'a, yön+ölçeği node'a (yerel) verir.
  /// Başarılı olursa `true` döner. ([_kUseAnchors] açıkken birincil yol.)
  Future<bool> _placeAnchored(
    String id,
    String resolved,
    vm.Matrix4 target,
    ARObjectManager objectManager,
    ARAnchorManager anchorManager,
  ) async {
    // target'ı ayır: anchor KONUM+DÖNÜŞ taşır (ARCore takip eder), node yalnız
    // ÖLÇEK taşır. Böylece child-transform'a bağımlı olmadan — `scaleToUnits`
    // node ölçeğini, anchor pozu yön+konumu doğru verir.
    final t = vm.Vector3.zero();
    final r = vm.Quaternion.identity();
    final s = vm.Vector3.zero();
    target.decompose(t, r, s);
    final anchorPose = vm.Matrix4.compose(t, r, vm.Vector3(1, 1, 1));
    final localTf =
        vm.Matrix4.compose(vm.Vector3.zero(), vm.Quaternion.identity(), s);

    final anchor = ARPlaneAnchor(transformation: anchorPose, name: 'anchor_$id');
    final anchorAdded = await anchorManager.addAnchor(anchor);
    _arLog('placeOne[$id] addAnchor → $anchorAdded');
    if (anchorAdded != true) return false;

    final node = ARNode(
      type: NodeType.webGLB,
      uri: resolved,
      name: _nameFromId(id),
      transformation: localTf,
    );
    final didAdd = await objectManager.addNode(node, planeAnchor: anchor);
    _arLog('placeOne[$id] addNode(anchored) → $didAdd');
    if (didAdd == true) {
      node.transform = localTf; // yön/ölçeği yerel uygula
      _nodes[id] = node;
      _anchors[id] = anchor;
      if (mounted) setState(() {});
      return true;
    }
    // Node eklenemedi → anchor'ı geri al (sızıntı olmasın).
    anchorManager.removeAnchor(anchor);
    return false;
  }

  /// Eski (anchor'sız) yol — top-level node. Anchor kapalıyken ya da anchor
  /// kurulamadığında fallback. ARCore drift'ine açıktır ama her zaman çalışır.
  Future<void> _placeFreeNode(
    String id,
    String resolved,
    vm.Matrix4 target,
    ARObjectManager objectManager,
  ) async {
    final node = ARNode(
      type: NodeType.webGLB,
      uri: resolved,
      name: _nameFromId(id),
      transformation: target,
    );
    final didAdd = await objectManager.addNode(node);
    _arLog('placeOne[$id] addNode(free) → didAdd=$didAdd');
    if (didAdd == true) {
      node.transform = target;
      _nodes[id] = node;
      if (mounted) setState(() {});
    } else {
      _arLog('❌ placeOne[$id] free addNode başarısız (didAdd=$didAdd)');
      LogService.w('addNode returned false for $id', tag: _tag);
    }
  }

  /// POI'nin gerçek dünya yön (bearing) + mesafesini, o anki kamera pozu ve
  /// pusula heading'i kullanarak ARCore dünya koordinatına çevirir. Model
  /// kullanıcının baktığı yönde, doğru tarafta, dik durur ve önü kullanıcıya
  /// bakar. Heading/kamera pozu yoksa kameranın düz önüne düşer.
  Future<vm.Matrix4> _geoWorldPose(
      ArMatchedPoint match, double? headingDeg) async {
    final s = match.point.modelScale;
    final rotY = match.point.modelRotationYDeg * math.pi / 180.0;
    final dist = match.distanceM.clamp(_kMinPlaceDist, _kMaxPlaceDist);

    // Bazı GLB'ler bu motorda baş aşağı/ters geliyor → model-yerel düzeltme
    // (X ekseni 180° = baş aşağı→dik). Farklı eksen gerekirse _kModelFlipXDeg'i
    // değiştir ya da 0 yap. Yaw'dan ÖNCE (model-yerel) uygulanır.
    final uprightFix =
        vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), _kModelFlipXDeg * math.pi / 180.0);

    final cam = await _sessionManager?.getCameraPose();
    if (cam == null || headingDeg == null) {
      // Fallback: düz önde.
      final rot =
          (vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), rotY) * uprightFix)
            ..normalize();
      return vm.Matrix4.compose(
        vm.Vector3(0, 0, -dist),
        rot,
        vm.Vector3(s, s, s),
      );
    }

    final camPos = cam.getTranslation();
    final col0 = cam.getColumn(0); // kamera +X (sağ)
    final col2 = cam.getColumn(2); // kamera +Z (geri)
    var forward = vm.Vector3(-col2.x, 0, -col2.z); // ileri = −Z, yatay
    var right = vm.Vector3(col0.x, 0, col0.z); // sağ, yatay
    if (forward.length2 < 1e-6) forward = vm.Vector3(0, 0, -1);
    if (right.length2 < 1e-6) right = vm.Vector3(1, 0, 0);
    forward.normalize();
    right.normalize();

    // Cihaz heading'i ile POI bearing'i arasındaki işaretli fark
    // (pozitif = POI sağda) — kartlarla aynı mantık.
    final deltaDeg =
        (match.bearingFromUserDeg - headingDeg + 540) % 360 - 180;
    final delta = deltaDeg * math.pi / 180.0;

    final dir = (right * math.sin(delta) + forward * math.cos(delta))
      ..normalize();
    final pos = camPos + dir * dist;

    // Dikey: güvenilir elevation verisi varsa hafifçe yukarı/aşağı.
    if (match.hasElevationData) {
      final elev = match.elevationAngleDeg * math.pi / 180.0;
      pos.y = camPos.y + (dist * math.tan(elev)).clamp(-2.0, 4.0);
    } else {
      pos.y = camPos.y;
    }

    // Modelin önü kullanıcıya baksın (model +Z, −dir yönüne) + dik dur.
    final yaw = math.atan2(-dir.x, -dir.z) + rotY;
    final rot = (vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), yaw) * uprightFix)
      ..normalize();
    return vm.Matrix4.compose(pos, rot, vm.Vector3(s, s, s));
  }

  // NOT: Dokunma jestleri (tek parmak taşıma + iki parmak pinch/twist)
  // kullanıcı isteğiyle kaldırıldı — model otomatik yerleşip sabit kalır.

  String _nameFromId(String id) => 'model_$id';

  // ═══════════════════════════════════════════════════════════════════════
  // UI
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // Geo eşleşmeleri değiştikçe modelleri otomatik senkronla.
    ref.listen(arGeoControllerProvider, (_, _) => _syncModels());

    return Stack(
      fit: StackFit.expand,
      children: [
        if (!_isBackgrounded)
          // Dokunma jesti yok — model otomatik yerleşip sabit kalır.
          ARView(
            key: ValueKey<int>(_arViewGeneration),
            onARViewCreated: _onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.none,
          )
        else
          const ColoredBox(color: Colors.black),
      ],
    );
  }
}
