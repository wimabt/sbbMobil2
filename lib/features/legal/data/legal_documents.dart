import 'package:flutter/material.dart';

/// KVKK / yasal metin altyapısı (§10.6.3, §14.2.3, §6.3.1).
///
/// Metinler **tek noktada** ve İdare onayına hazır biçimde tutulur. Nihai
/// metinler İdare tarafından onaylanınca yalnızca bu dosyadaki içerik ve
/// [kLegalContentVersion] güncellenir; UI veya akış değişmez.
///
/// > ⚠️ Buradaki metinler **taslaktır** ([LegalDocument.isDraft]); ekranda
/// > "İdare onayı bekleniyor" rozetiyle gösterilir. Onay sonrası `isDraft`
/// > false yapılır.

/// Açık rıza / yasal metinlerin sürümü. Metin değişince artırılır; kullanıcıdan
/// rızanın yeniden alınması ([consentProvider]) bu sürüme bağlanır.
const int kLegalContentVersion = 1;

/// Tek bir yasal belge bölümü (opsiyonel başlık + gövde).
class LegalSection {
  const LegalSection({this.heading, required this.body});

  final String? heading;
  final String body;
}

/// İçerik yönetimi tek noktadan yapılan yasal belge.
class LegalDocument {
  const LegalDocument({
    required this.id,
    required this.title,
    required this.summary,
    required this.icon,
    required this.version,
    required this.lastUpdated,
    required this.sections,
    this.isDraft = true,
  });

  /// Route slug'ı (`/legal/:id`).
  final String id;
  final String title;

  /// Hub listesinde gösterilen tek satırlık açıklama.
  final String summary;
  final IconData icon;
  final String version;

  /// İnsan-okunur tarih (ör. "29 Mayıs 2026").
  final String lastUpdated;
  final List<LegalSection> sections;

  /// İdare onayı bekleyen taslak mı?
  final bool isDraft;
}

/// Belge kimlikleri — derleme zamanı güvenli referans için.
class LegalDocIds {
  const LegalDocIds._();
  static const aydinlatma = 'aydinlatma-metni';
  static const acikRiza = 'acik-riza';
  static const gizlilik = 'gizlilik-politikasi';
  static const kullanim = 'kullanim-kosullari';
}

/// İletişim / veri sorumlusu — tek noktada.
const String _kDataController = 'Samsun Büyükşehir Belediyesi';

/// Tüm yasal belgeler (hub sırasıyla).
const List<LegalDocument> kLegalDocuments = [
  LegalDocument(
    id: LegalDocIds.aydinlatma,
    title: 'KVKK Aydınlatma Metni',
    summary: 'Kişisel verilerinizin hangi amaçla işlendiği.',
    icon: Icons.shield_outlined,
    version: 'v1 (taslak)',
    lastUpdated: '29 Mayıs 2026',
    sections: [
      LegalSection(
        body:
            '$_kDataController ("İdare") olarak, Şehir Tanıtım Mobil Uygulaması '
            'aracılığıyla işlediğimiz kişisel verilerinize ilişkin olarak 6698 '
            'sayılı Kişisel Verilerin Korunması Kanunu ("KVKK") kapsamında sizi '
            'bilgilendirmek isteriz.',
      ),
      LegalSection(
        heading: 'Veri Sorumlusu',
        body:
            'Kişisel verileriniz, veri sorumlusu sıfatıyla $_kDataController '
            'tarafından aşağıda açıklanan amaçlarla işlenmektedir.',
      ),
      LegalSection(
        heading: 'İşlenen Kişisel Veriler',
        body:
            '• Kimlik ve iletişim bilgileri (ad, soyad, telefon, e-posta) — yalnızca '
            'üyelik oluşturduğunuzda.\n'
            '• Konum bilgisi — yalnızca izin verdiğinizde, yakındaki içerik ve '
            'harita hizmetleri için.\n'
            '• Uygulama kullanım verileri (görüntülenen içerikler, etkileşimler) — '
            'hizmet kalitesini iyileştirmek için.',
      ),
      LegalSection(
        heading: 'İşleme Amaçları',
        body:
            '• Şehir tanıtım ve dijital rehberlik hizmetinin sunulması,\n'
            '• Konuma ve ilgi alanına göre içerik önerilmesi,\n'
            '• Bildirim hizmetlerinin yürütülmesi,\n'
            '• Hizmetin güvenliği ve sürekliliğinin sağlanması.',
      ),
      LegalSection(
        heading: 'Hukuki Sebep',
        body:
            'Kişisel verileriniz, KVKK m.5 kapsamında; hizmetin sunulması için '
            'gerekli olması ve/veya açık rızanıza dayanılarak işlenir. Temel '
            'tanıtım içerikleri üyelik gerektirmeden kullanılabilir.',
      ),
      LegalSection(
        heading: 'Aktarım',
        body:
            'Kişisel verileriniz, İdare onayı olmaksızın üçüncü kişilerle '
            'paylaşılmaz. Harita, bildirim gibi hizmetler için kullanılan üçüncü '
            'taraf servisler KVKK uyumlu şekilde yapılandırılır.',
      ),
      LegalSection(
        heading: 'Haklarınız (KVKK m.11)',
        body:
            'Kişisel verilerinizin işlenip işlenmediğini öğrenme, düzeltilmesini '
            'veya silinmesini isteme, işleme faaliyetine itiraz etme ve KVKK m.11 '
            'kapsamındaki diğer haklarınızı kullanma hakkına sahipsiniz. '
            'Uygulama içinden hesabınızı ve verilerinizi silme talebinde '
            'bulunabilirsiniz (Ayarlar → Hesabımı Sil).',
      ),
    ],
  ),
  LegalDocument(
    id: LegalDocIds.acikRiza,
    title: 'Açık Rıza Metni',
    summary: 'Üyelik kapsamında verilerin işlenmesine onay.',
    icon: Icons.fact_check_outlined,
    version: 'v1 (taslak)',
    lastUpdated: '29 Mayıs 2026',
    sections: [
      LegalSection(
        body:
            'KVKK Aydınlatma Metni\'ni okuduğumu; üyelik, kampanya ve kişiselleştirilmiş '
            'içerik hizmetleri kapsamında kimlik, iletişim ve uygulama kullanım '
            'verilerimin $_kDataController tarafından belirtilen amaçlarla '
            'işlenmesine açık rıza verdiğimi kabul ederim.',
      ),
      LegalSection(
        heading: 'Rızanın Geri Alınması',
        body:
            'Açık rızanızı dilediğiniz zaman uygulama içinden hesabınızı silerek '
            'veya destek kanallarına başvurarak geri alabilirsiniz. Rızanın geri '
            'alınması, üyelik gerektiren özelliklerin kullanımını sınırlayabilir.',
      ),
    ],
  ),
  LegalDocument(
    id: LegalDocIds.gizlilik,
    title: 'Gizlilik Politikası',
    summary: 'Verilerinizi nasıl koruyoruz.',
    icon: Icons.lock_outline_rounded,
    version: 'v1 (taslak)',
    lastUpdated: '29 Mayıs 2026',
    sections: [
      LegalSection(
        body:
            'Bu Gizlilik Politikası, Şehir Tanıtım Mobil Uygulaması\'nda '
            'verilerinizin nasıl toplandığını, kullanıldığını ve korunduğunu '
            'açıklar.',
      ),
      LegalSection(
        heading: 'Veri Güvenliği',
        body:
            '• Tüm veri iletimi güvenli protokoller (SSL/TLS) üzerinden yapılır.\n'
            '• Oturum ve kimlik bilgileri cihazda şifreli alanda (Keychain / '
            'Keystore) saklanır.\n'
            '• Yetkisiz erişime karşı teknik ve idari tedbirler uygulanır.',
      ),
      LegalSection(
        heading: 'Saklama ve Silme',
        body:
            'Kişisel veriler ilgili mevzuatta öngörülen süreler boyunca saklanır; '
            'süre dolduğunda veya talebiniz halinde silinir, yok edilir ya da '
            'anonim hale getirilir.',
      ),
      LegalSection(
        heading: 'Üçüncü Taraf Servisler',
        body:
            'Harita ve bildirim gibi hizmetler için kullanılan üçüncü taraf '
            'servisler yalnızca hizmetin gerektirdiği ölçüde veriye erişir ve '
            'KVKK uyumludur.',
      ),
    ],
  ),
  LegalDocument(
    id: LegalDocIds.kullanim,
    title: 'Kullanım Koşulları',
    summary: 'Uygulamayı kullanım kuralları.',
    icon: Icons.description_outlined,
    version: 'v1 (taslak)',
    lastUpdated: '29 Mayıs 2026',
    sections: [
      LegalSection(
        body:
            'Bu uygulamayı kullanarak aşağıdaki koşulları kabul etmiş olursunuz.',
      ),
      LegalSection(
        heading: 'Hizmetin Kapsamı',
        body:
            'Uygulama, Samsun\'un tarihi, kültürel ve turistik değerlerinin '
            'tanıtımı amacıyla bilgilendirme ve dijital rehberlik hizmeti sunar. '
            'İçerikler İdare tarafından güncellenir.',
      ),
      LegalSection(
        heading: 'Kullanıcı Sorumlulukları',
        body:
            '• Uygulamayı yürürlükteki mevzuata uygun kullanmak,\n'
            '• AR ve harita özelliklerini kullanırken çevre ve trafik güvenliğine '
            'dikkat etmek kullanıcının sorumluluğundadır.',
      ),
      LegalSection(
        heading: 'Fikri Mülkiyet',
        body:
            'Uygulamadaki içerik, görsel ve markalar $_kDataController\'ne aittir; '
            'izinsiz kullanılamaz.',
      ),
    ],
  ),
];

/// id ile belge bulur (yoksa null).
LegalDocument? legalDocumentById(String id) {
  for (final d in kLegalDocuments) {
    if (d.id == id) return d;
  }
  return null;
}
