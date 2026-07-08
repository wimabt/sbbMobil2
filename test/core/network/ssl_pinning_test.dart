import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbb_mobile/core/network/ssl_pinning.dart';

/// mobil.smartsamsun.com'un GERÇEK leaf sertifikası (2026-07-07'de canlı
/// sunucudan alındı; Let's Encrypt E7, ECC — kamuya açık veri).
///
/// Bu test, `SslPinning.extractSpkiDer`'in (minimal ASN.1 yürüyüşü)
/// gerçek dünya sertifikasından doğru SubjectPublicKeyInfo bloğunu
/// çıkardığını, openssl ile bağımsız hesaplanan pin'e karşı doğrular:
///
///   openssl x509 -pubkey -noout | openssl pkey -pubin -outform der \
///     | openssl dgst -sha256 -binary | openssl enc -base64
const _livePem = '''
MIIDljCCAxygAwIBAgISBqL6ag+1C6l70BBEBeTLqj/4MAoGCCqGSM49BAMDMDIx
CzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1MZXQncyBFbmNyeXB0MQswCQYDVQQDEwJF
NzAeFw0yNjA1MjYxNjUwMjNaFw0yNjA4MjQxNjUwMjJaMCAxHjAcBgNVBAMTFW1v
YmlsLnNtYXJ0c2Ftc3VuLmNvbTBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABE5D
S0z87bJ5G0AHr/51i0OK4H6Tjxht1xIHW15VyF0Ymx+7Pu+6pWuwTtbYCewiz54J
iMzhropg0CWw7V5/20KjggIiMIICHjAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAww
CgYIKwYBBQUHAwEwDAYDVR0TAQH/BAIwADAdBgNVHQ4EFgQUgp3Rk2lSxD/FcCq2
d7QgYOQ1ptMwHwYDVR0jBBgwFoAUrkie3IcdRKBv2qLlYHQEeMKcAIAwMgYIKwYB
BQUHAQEEJjAkMCIGCCsGAQUFBzAChhZodHRwOi8vZTcuaS5sZW5jci5vcmcvMCAG
A1UdEQQZMBeCFW1vYmlsLnNtYXJ0c2Ftc3VuLmNvbTATBgNVHSAEDDAKMAgGBmeB
DAECATAuBgNVHR8EJzAlMCOgIaAfhh1odHRwOi8vZTcuYy5sZW5jci5vcmcvMTIx
LmNybDCCAQwGCisGAQQB1nkCBAIEgf0EgfoA+AB3AMs49xWJfIShRF9bwd37yW7y
mlnNRwppBYWwyxTDFFjnAAABnmVnYDUAAAQDAEgwRgIhAP1lRHCjxLH6vxaUQiu2
Doukb6CA+PljJXcXQN3UMkUKAiEAmEEnL+26qGRAZAEi8ukYvRMhLGinWEmgv1Tm
Kq7G8K0AfQAai51rD/6/gbR5OcbSMQqG1tEC1PBG4hgsneNfXiYl7wAAAZ5lZ2Is
AAgAAAUAFy7e/gQDAEYwRAIgSuG//xX31Efvf9MSIxw4dB0EqMCxEQTBLd1qPBXj
0SMCIFj5EuXX643KUNW2ABBLR7LMa5mSYDCFBm+uDmIaP7COMAoGCCqGSM49BAMD
A2gAMGUCMQDlWYQLRLpjKyaLIkjcLH5P3lkZykcAfN9nmMlTncL+CyrznIlO1BwR
boUevNYsM0QCMHZuwUiluDEWNTssHYTZP/48lXX3OWkdIIg8XCeNOOzx8cy3gLiu
ZHXnN5FYNG2xHw==
''';

/// openssl ile bağımsız hesaplanan beklenen SPKI SHA-256 pin'i.
/// `scripts/build_release.*` içindeki varsayılan pin ile aynı olmalı.
const _expectedSpkiPin = 'BcKsW3xTBEvdNXN2hJyQmHuX3ZJVrs+5EIFvuL+E7yo=';

Uint8List _derFromPem(String pem) =>
    Uint8List.fromList(base64.decode(pem.replaceAll(RegExp(r'\s'), '')));

void main() {
  group('SslPinning.extractSpkiDer', () {
    test('gerçek sertifikadan openssl ile aynı SPKI pinini üretir', () {
      final der = _derFromPem(_livePem);

      final spki = SslPinning.extractSpkiDer(der);
      expect(spki, isNotNull, reason: 'SPKI bloğu parse edilemedi');

      final pin = base64.encode(sha256.convert(spki!).bytes);
      expect(pin, _expectedSpkiPin);
    });

    test('SPKI, tam sertifika hashinden farklıdır (yenileme dayanıklılığı)',
        () {
      final der = _derFromPem(_livePem);
      final certHash = base64.encode(sha256.convert(der).bytes);
      // Pin sertifika hash'ine eşit olsaydı SPKI çıkarımı çalışmıyor demekti.
      expect(certHash, isNot(_expectedSpkiPin));
    });

    test('bozuk DER girdisinde null döner (fail-closed)', () {
      expect(SslPinning.extractSpkiDer(Uint8List.fromList([0x30])), isNull);
      expect(
        SslPinning.extractSpkiDer(Uint8List.fromList([0x02, 0x01, 0x01])),
        isNull,
      );
      expect(SslPinning.extractSpkiDer(Uint8List(0)), isNull);
      // Geçerli başlayıp yarıda kesilen DER:
      final der = _derFromPem(_livePem);
      expect(
        SslPinning.extractSpkiDer(Uint8List.sublistView(der, 0, 40)),
        isNull,
      );
    });
  });
}
