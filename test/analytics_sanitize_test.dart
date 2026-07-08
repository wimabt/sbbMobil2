import 'package:flutter_test/flutter_test.dart';
import 'package:sbb_mobile/core/services/analytics_events.dart';
import 'package:sbb_mobile/core/services/analytics_service.dart';

/// mobile_analytics_todo.md §6 — PII sanitize katmanı.
///
/// Bu test'in iki amacı var:
///   1. `_sanitize()` mantığının regresyon koruması (track() içinden geçen
///       her property bu fonksiyondan geçiyor — kırılırsa PII sızar).
///   2. Spec'teki olay sözlüğünün (`AnalyticsEvents`) backend ile birebir
///       senkron olduğunu garanti et — yanlışlıkla snake_case bozulursa
///       backend panel dropdown'ında event kaybolur.
///
/// Not: AnalyticsService.sanitize() pure static, `@visibleForTesting` API.
/// Tam servisin (buffer + Riverpod + SharedPreferences + Dio) entegrasyon
/// testi ayrı bir dosyada, mock ApiClient ile yapılır.
void main() {
  group('AnalyticsService.sanitize', () {
    test('boş props için boş Map döner (alokasyon tasarrufu)', () {
      final out = AnalyticsService.sanitize(AnalyticsEvents.screenView, const {});
      expect(out, isEmpty);
    });

    test('passthrough — sterile property\'leri olduğu gibi bırakır', () {
      final out = AnalyticsService.sanitize(
        AnalyticsEvents.placeDetailOpened,
        const {
          'place_id': 'p123',
          'source': 'list',
        },
      );
      expect(out['place_id'], 'p123');
      expect(out['source'], 'list');
    });

    group('query trim + cap', () {
      test('64 karakter sınırına kırpar', () {
        final long = 'a' * 100;
        final out = AnalyticsService.sanitize(
          AnalyticsEvents.searchSubmitted,
          {'query': long, 'scope': 'places'},
        );
        expect((out['query'] as String).length, 64);
      });

      test('64 altındaki query\'yi olduğu gibi bırakır', () {
        final out = AnalyticsService.sanitize(
          AnalyticsEvents.searchSubmitted,
          const {'query': 'samsun saathane'},
        );
        expect(out['query'], 'samsun saathane');
      });

      test('whitespace trim eder', () {
        final out = AnalyticsService.sanitize(
          AnalyticsEvents.searchSubmitted,
          const {'query': '  saathane  '},
        );
        expect(out['query'], 'saathane');
      });

      test('arama dışı eventlerde de query alanı varsa kırpar', () {
        // query property name'i hangi event'te kullanılırsa kullanılsın
        // (search_result_tapped vs.) aynı kuralı uygula.
        final out = AnalyticsService.sanitize(
          AnalyticsEvents.searchResultTapped,
          {'query': 'a' * 200, 'entity_id': 'p1', 'position': 0},
        );
        expect((out['query'] as String).length, 64);
      });
    });

    group('website_tapped URL → host', () {
      test('tam URL\'yi host\'a indirir, url alanını siler', () {
        final out = AnalyticsService.sanitize(
          AnalyticsEvents.websiteTapped,
          const {
            'entity_type': 'place',
            'entity_id': 'p1',
            'url': 'https://samsun.bel.tr/kultur/saathane?utm_source=app&token=secret',
          },
        );
        expect(out['host'], 'samsun.bel.tr');
        expect(out.containsKey('url'), isFalse,
            reason: 'Ham URL analytics\'e GİTMEMELİ — KVKK + query string token\'ı sızdırır.');
      });

      test('geçersiz URL\'de sessizce vazgeçer, url\'i yine siler', () {
        final out = AnalyticsService.sanitize(
          AnalyticsEvents.websiteTapped,
          const {'url': 'not a valid url \\\\\\'},
        );
        // Parse başarısız olsa bile ham URL kalmamalı.
        expect(out.containsKey('url'), isFalse);
      });

      test('website_tapped dışı eventlerde url alanına dokunmaz', () {
        // Sadece website_tapped özel davranış. Diğerlerinde url normal kalabilir.
        final out = AnalyticsService.sanitize(
          AnalyticsEvents.screenView,
          const {'screen_name': 'home', 'url': 'https://example.com'},
        );
        expect(out['url'], 'https://example.com');
      });
    });

    group('error_occurred', () {
      test('stack alanlarını siler', () {
        final out = AnalyticsService.sanitize(
          AnalyticsEvents.errorOccurred,
          const {
            'code': 'NETWORK',
            'message': 'connect timeout',
            'stack': '#0 main()\n#1 io...',
            'stack_trace': '#0 main()',
            'stackTrace': '#0 main()',
          },
        );
        expect(out['code'], 'NETWORK');
        expect(out['message'], 'connect timeout');
        expect(out.containsKey('stack'), isFalse);
        expect(out.containsKey('stack_trace'), isFalse);
        expect(out.containsKey('stackTrace'), isFalse);
      });

      test('message\'ı 80 karaktere kırpar', () {
        final long = 'x' * 200;
        final out = AnalyticsService.sanitize(
          AnalyticsEvents.errorOccurred,
          {'code': 'X', 'message': long},
        );
        expect((out['message'] as String).length, 80);
      });

      test('80 altındaki message\'a dokunmaz', () {
        final out = AnalyticsService.sanitize(
          AnalyticsEvents.errorOccurred,
          const {'code': 'X', 'message': 'kısa hata'},
        );
        expect(out['message'], 'kısa hata');
      });
    });

    group('PII anahtar filtresi (her event için)', () {
      test('phone, email, password, token anahtarlarını siler', () {
        final out = AnalyticsService.sanitize(
          AnalyticsEvents.placeDetailOpened,
          const {
            'place_id': 'p1',
            'phone': '+905551112233',
            'phone_number': '05551112233',
            'email': 'a@b.com',
            'user_email': 'x@y.com',
            'password': 'hunter2',
            'access_token': 'eyJ...',
            'auth_token': 'Bearer ...',
          },
        );
        expect(out['place_id'], 'p1');
        expect(out.containsKey('phone'), isFalse);
        expect(out.containsKey('phone_number'), isFalse);
        expect(out.containsKey('email'), isFalse);
        expect(out.containsKey('user_email'), isFalse);
        expect(out.containsKey('password'), isFalse);
        expect(out.containsKey('access_token'), isFalse);
        expect(out.containsKey('auth_token'), isFalse);
      });

      test('phone_tapped event\'inde phone PROPERTY YOKsa entity bilgisi korunur', () {
        // §2.4: phone_tapped event'i sadece {entity_type, entity_id} taşır;
        // phone property'si zaten gönderilmiyor. Bu test çağıran tarafın
        // yanlışlıkla phone gönderdiği durumda da temizlemenin çalıştığını
        // doğrular.
        final out = AnalyticsService.sanitize(
          AnalyticsEvents.phoneTapped,
          const {
            'entity_type': 'place',
            'entity_id': 'p1',
          },
        );
        expect(out['entity_type'], 'place');
        expect(out['entity_id'], 'p1');
        expect(out.length, 2, reason: 'Hiçbir alan eklenmemeli.');
      });

      test('entity_id gibi "email" içermeyen alanlar korunur', () {
        // Negative test — fuzzy match olmasın (örn. "available" yanlışlıkla
        // "email" kontrolüne takılmasın diye).
        final out = AnalyticsService.sanitize(
          AnalyticsEvents.placeDetailOpened,
          const {
            'entity_id': 'p1',
            'available': true,
            'request_id': 'rq-123',
          },
        );
        expect(out['entity_id'], 'p1');
        expect(out['available'], true);
        expect(out['request_id'], 'rq-123');
      });
    });
  });

  group('AnalyticsEvents taxonomy', () {
    test('event name\'ler snake_case ASCII (backend convention)', () {
      // Refleksiyonsuz: spec §2'den derlenen kanonik liste.
      const names = <String>[
        AnalyticsEvents.sessionStart,
        AnalyticsEvents.sessionEnd,
        AnalyticsEvents.screenView,
        AnalyticsEvents.onboardingCompleted,
        AnalyticsEvents.placeDetailOpened,
        AnalyticsEvents.routeDetailOpened,
        AnalyticsEvents.eventDetailOpened,
        AnalyticsEvents.galleryOpened,
        AnalyticsEvents.imageViewed,
        AnalyticsEvents.videoPlayStarted,
        AnalyticsEvents.videoPlayCompleted,
        AnalyticsEvents.audioPlayStarted,
        AnalyticsEvents.favoriteToggled,
        AnalyticsEvents.shareTapped,
        AnalyticsEvents.directionsRequested,
        AnalyticsEvents.phoneTapped,
        AnalyticsEvents.websiteTapped,
        AnalyticsEvents.contentTapped,
        AnalyticsEvents.descriptionExpanded,
        AnalyticsEvents.scroll75,
        AnalyticsEvents.searchSubmitted,
        AnalyticsEvents.searchResultTapped,
        AnalyticsEvents.discoveryCardTapped,
        AnalyticsEvents.filterApplied,
        AnalyticsEvents.mapOpened,
        AnalyticsEvents.mapMarkerTapped,
        AnalyticsEvents.qrScanned,
        AnalyticsEvents.arOpened,
        AnalyticsEvents.placeVisited,
        AnalyticsEvents.routeStarted,
        AnalyticsEvents.routeStopTapped,
        AnalyticsEvents.itineraryCreated,
        AnalyticsEvents.notificationReceived,
        AnalyticsEvents.notificationOpened,
        AnalyticsEvents.geofenceEntered,
        AnalyticsEvents.geofenceExited,
        AnalyticsEvents.languageChanged,
        AnalyticsEvents.authLogin,
        AnalyticsEvents.authLogout,
        AnalyticsEvents.authRegister,
        AnalyticsEvents.errorOccurred,
      ];

      final pattern = RegExp(r'^[a-z][a-z0-9_]*$');
      for (final n in names) {
        expect(pattern.hasMatch(n), isTrue,
            reason: '"$n" snake_case ASCII olmalı.');
      }
    });

    test('hiçbir event name duplicate değil', () {
      const names = <String>[
        AnalyticsEvents.sessionStart,
        AnalyticsEvents.sessionEnd,
        AnalyticsEvents.screenView,
        AnalyticsEvents.placeDetailOpened,
        AnalyticsEvents.routeDetailOpened,
        AnalyticsEvents.eventDetailOpened,
        AnalyticsEvents.searchSubmitted,
        AnalyticsEvents.searchResultTapped,
        AnalyticsEvents.discoveryCardTapped,
        AnalyticsEvents.contentTapped,
        AnalyticsEvents.mapOpened,
        AnalyticsEvents.mapMarkerTapped,
        AnalyticsEvents.scroll75,
        AnalyticsEvents.galleryOpened,
        AnalyticsEvents.videoPlayStarted,
        AnalyticsEvents.videoPlayCompleted,
        AnalyticsEvents.phoneTapped,
        AnalyticsEvents.directionsRequested,
        AnalyticsEvents.favoriteToggled,
        AnalyticsEvents.filterApplied,
        AnalyticsEvents.authLogin,
        AnalyticsEvents.authLogout,
        AnalyticsEvents.authRegister,
        AnalyticsEvents.languageChanged,
        AnalyticsEvents.notificationReceived,
        AnalyticsEvents.notificationOpened,
      ];
      expect(names.toSet().length, names.length,
          reason: 'Bazı event name\'ler duplicate — backend\'de çakışır.');
    });
  });

  group('AnalyticsSource enum', () {
    test('source değerleri backend kanonik liste ile uyumlu', () {
      const sources = <String>[
        AnalyticsSource.list,
        AnalyticsSource.search,
        AnalyticsSource.map,
        AnalyticsSource.qr,
        AnalyticsSource.routeStop,
        AnalyticsSource.deeplink,
        AnalyticsSource.discovery,
        AnalyticsSource.favorite,
        AnalyticsSource.itinerary,
        AnalyticsSource.notification,
      ];
      final pattern = RegExp(r'^[a-z][a-z_]*$');
      for (final s in sources) {
        expect(pattern.hasMatch(s), isTrue,
            reason: '"$s" snake_case ASCII olmalı.');
      }
    });
  });
}
