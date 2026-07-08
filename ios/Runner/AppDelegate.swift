import Flutter
import UIKit
import GoogleMaps
import CoreLocation
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyCyaM27r8IFwv73_2YyD_yoWy4KG_sFKPE")
    GeneratedPluginRegistrant.register(with: self)

    // ── Native geofencing köprüsü (region monitoring) ───────────────────────
    // GeofenceManager.shared'a erişmek delegate'i kurar; arka plan relaunch'ta
    // (didEnterRegion) bölge olaylarının alınması için bu ŞART.
    GeofenceManager.shared.activate()

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.smartsamsun.mobil/geofence",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { (call, result) in
        switch call.method {
        case "registerZones":
          let args = call.arguments as? [String: Any]
          let zones = args?["zones"] as? String ?? "[]"
          let cooldown = args?["cooldownHours"] as? Int ?? 24
          GeofenceManager.shared.register(zonesJson: zones, cooldownHours: cooldown)
          result(nil)
        case "clearZones":
          GeofenceManager.shared.clear()
          result(nil)
        case "monitoredCount":
          result(GeofenceManager.shared.monitoredCount())
        case "consumePendingTap":
          result(GeofenceManager.shared.consumePendingTap())
        case "requestAlwaysPermission":
          GeofenceManager.shared.requestAlwaysPermission { granted in result(granted) }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // ── App switcher gizlilik örtüsü (iOS) ────────────────────────────────────
  // Android'de hassas ekranlar FLAG_SECURE ile korunuyor (SecureScreenMixin),
  // ama iOS FLAG_SECURE'u desteklemez. Uygulama arka plana alınırken iOS,
  // app-switcher önizlemesi için ekranın anlık görüntüsünü alır; bu görüntü
  // OTP / QR gibi hassas içerik taşıyabilir. Uygulama inaktif olurken ekranın
  // üstüne opak bir örtü koyup, tekrar aktifleşince kaldırıyoruz — böylece
  // app-switcher'da ve arka plan snapshot'ında hassas içerik görünmez.
  private var privacyOverlay: UIView?

  override func applicationWillResignActive(_ application: UIApplication) {
    super.applicationWillResignActive(application)
    showPrivacyOverlay()
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    hidePrivacyOverlay()
  }

  private func showPrivacyOverlay() {
    guard let window = window, privacyOverlay == nil else { return }
    let overlay = UIView(frame: window.bounds)
    overlay.backgroundColor = UIColor(red: 0.10, green: 0.16, blue: 0.24, alpha: 1.0)
    overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    // Ortaya uygulama ikonu benzeri basit bir kilit simgesi (SF Symbol).
    if #available(iOS 13.0, *) {
      let icon = UIImageView(
        image: UIImage(systemName: "lock.shield.fill")?
          .withTintColor(.white, renderingMode: .alwaysOriginal)
      )
      icon.translatesAutoresizingMaskIntoConstraints = false
      icon.contentMode = .scaleAspectFit
      overlay.addSubview(icon)
      NSLayoutConstraint.activate([
        icon.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
        icon.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
        icon.widthAnchor.constraint(equalToConstant: 64),
        icon.heightAnchor.constraint(equalToConstant: 64),
      ])
    }

    window.addSubview(overlay)
    privacyOverlay = overlay
  }

  private func hidePrivacyOverlay() {
    privacyOverlay?.removeFromSuperview()
    privacyOverlay = nil
  }
}

/// iOS native geofencing — CLLocationManager region monitoring.
///
/// AppDelegate.swift içinde tutulur (yeni dosya Xcode projesine eklenmeden
/// derlenmez). OneSignal'in `UNUserNotificationCenter` delegesine DOKUNULMAZ —
/// yalnız local notification eklenir (arka plan/öldürülmüş durumda OS gösterir).
/// Tetiklenince bildirimi native taraf üretir (Flutter motoru çalışmıyor olabilir).
final class GeofenceManager: NSObject, CLLocationManagerDelegate {
  static let shared = GeofenceManager()

  private let manager = CLLocationManager()
  private let defaults = UserDefaults.standard

  private let kZones = "sbb_geofence_zones"
  private let kCooldownHours = "sbb_geofence_cooldown_hours"
  private let kPendingTap = "sbb_geofence_pending_tap"
  private let kLastPrefix = "sbb_geofence_last_"

  override init() {
    super.init()
    manager.delegate = self
  }

  /// AppDelegate açılışta çağırır — singleton'ı (ve delegate'i) garanti eder.
  func activate() { /* init yeterli; çağrı sadece instantiation içindir */ }

  func requestAlwaysPermission(_ completion: @escaping (Bool) -> Void) {
    let status: CLAuthorizationStatus
    if #available(iOS 14.0, *) { status = manager.authorizationStatus }
    else { status = CLLocationManager.authorizationStatus() }
    if status == .authorizedAlways { completion(true); return }
    manager.requestAlwaysAuthorization()
    completion(false) // sonuç async; Dart yine de kaydı dener.
  }

  func register(zonesJson: String, cooldownHours: Int) {
    requestNotificationAuthorization()
    manager.requestAlwaysAuthorization()

    // Mevcut izlenen bölgeleri durdur.
    for region in manager.monitoredRegions {
      manager.stopMonitoring(for: region)
    }

    guard let data = zonesJson.data(using: .utf8),
          let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
      return
    }

    var contentMap: [String: [String: String]] = [:]
    let maxRadius = manager.maximumRegionMonitoringDistance

    for z in arr {
      guard let id = z["id"] as? String, !id.isEmpty,
            let lat = (z["lat"] as? NSNumber)?.doubleValue,
            let lng = (z["lng"] as? NSNumber)?.doubleValue,
            let radius = (z["radius"] as? NSNumber)?.doubleValue, radius > 0 else { continue }
      // iOS bölge yarıçapını cihaz sınırına clamp'ler.
      let r = min(radius, maxRadius)
      let region = CLCircularRegion(
        center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
        radius: r,
        identifier: id
      )
      region.notifyOnEntry = true
      region.notifyOnExit = false
      manager.startMonitoring(for: region)

      contentMap[id] = [
        "title": (z["title"] as? String) ?? "",
        "body": (z["body"] as? String) ?? "",
        "deeplinkId": (z["deeplinkId"] as? String) ?? ""
      ]
    }

    defaults.set(contentMap, forKey: kZones)
    defaults.set(cooldownHours, forKey: kCooldownHours)
  }

  func clear() {
    for region in manager.monitoredRegions {
      manager.stopMonitoring(for: region)
    }
    defaults.removeObject(forKey: kZones)
  }

  func monitoredCount() -> Int { manager.monitoredRegions.count }

  func consumePendingTap() -> String? {
    let p = defaults.string(forKey: kPendingTap)
    if p != nil { defaults.removeObject(forKey: kPendingTap) }
    return p
  }

  // MARK: - CLLocationManagerDelegate
  func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    handleEnter(region.identifier)
  }

  private func handleEnter(_ id: String) {
    guard let map = defaults.dictionary(forKey: kZones) as? [String: [String: String]],
          let z = map[id] else { return }

    let hours = defaults.integer(forKey: kCooldownHours)
    let cooldown = Double(hours <= 0 ? 24 : hours) * 3600.0
    let lastKey = kLastPrefix + id
    let last = defaults.double(forKey: lastKey)
    let now = Date().timeIntervalSince1970
    if last > 0 && (now - last) < cooldown { return }
    defaults.set(now, forKey: lastKey)

    let content = UNMutableNotificationContent()
    content.title = z["title"] ?? ""
    content.body = z["body"] ?? ""
    content.sound = .default
    if let deeplinkId = z["deeplinkId"], !deeplinkId.isEmpty {
      let payload = ["target": "district_detail", "id": deeplinkId]
      if let pdata = try? JSONSerialization.data(withJSONObject: payload),
         let pstr = String(data: pdata, encoding: .utf8) {
        content.userInfo = ["geofence_payload": pstr]
      }
    }
    let request = UNNotificationRequest(
      identifier: "geofence_\(id)",
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
  }

  private func requestNotificationAuthorization() {
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .sound, .badge]
    ) { _, _ in }
  }
}
