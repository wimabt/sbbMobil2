const fs = require("fs");
const path = require("path");
const docx = require("C:/Users/hsene/AppData/Roaming/npm/node_modules/docx");
const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  Header, Footer, AlignmentType, LevelFormat, TabStopType, TabStopPosition,
  TableOfContents, HeadingLevel, BorderStyle, WidthType, ShadingType,
  VerticalAlign, PageNumber, PageBreak,
} = docx;

// ── Renkler ──
const BRAND = "1F6E43";       // marka yeşili (koyu)
const BRAND_LIGHT = "E3F0E8"; // açık yeşil zemin
const GREY = "555555";
const HEAD_FILL = "1F6E43";

// ── Yardımcılar ──
const H1 = (t) => new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun(t)] });
const H2 = (t) => new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun(t)] });
const P = (t, opts = {}) => new Paragraph({
  spacing: { after: 120, line: 276 },
  children: [new TextRun({ text: t, ...opts })],
});
const lead = (label, text) => new Paragraph({
  spacing: { after: 120, line: 276 },
  children: [new TextRun({ text: label + " ", bold: true, color: BRAND }), new TextRun(text)],
});
const bullet = (t, boldLead) => new Paragraph({
  numbering: { reference: "bullets", level: 0 },
  spacing: { after: 60, line: 268 },
  children: boldLead
    ? [new TextRun({ text: boldLead, bold: true }), new TextRun(t)]
    : [new TextRun(t)],
});

// ── Tablo yardımcıları ──
const cellBorder = { style: BorderStyle.SINGLE, size: 1, color: "CCCCCC" };
const borders = { top: cellBorder, bottom: cellBorder, left: cellBorder, right: cellBorder };
function headCell(text, w) {
  return new TableCell({
    borders, width: { size: w, type: WidthType.DXA },
    shading: { fill: HEAD_FILL, type: ShadingType.CLEAR },
    margins: { top: 80, bottom: 80, left: 120, right: 120 },
    verticalAlign: VerticalAlign.CENTER,
    children: [new Paragraph({ children: [new TextRun({ text, bold: true, color: "FFFFFF" })] })],
  });
}
function cell(text, w, opts = {}) {
  return new TableCell({
    borders, width: { size: w, type: WidthType.DXA },
    shading: opts.fill ? { fill: opts.fill, type: ShadingType.CLEAR } : undefined,
    margins: { top: 70, bottom: 70, left: 120, right: 120 },
    verticalAlign: VerticalAlign.CENTER,
    children: [new Paragraph({ children: [new TextRun({ text, bold: !!opts.bold, color: opts.color })] })],
  });
}
function table(cols, rows) {
  const total = cols.reduce((a, c) => a + c.w, 0);
  return new Table({
    width: { size: total, type: WidthType.DXA },
    columnWidths: cols.map((c) => c.w),
    rows: [
      new TableRow({ tableHeader: true, children: cols.map((c) => headCell(c.t, c.w)) }),
      ...rows.map((r, i) => new TableRow({
        children: r.map((val, j) => cell(val, cols[j].w, {
          fill: i % 2 ? "F4F8F5" : "FFFFFF",
          bold: j === 0,
        })),
      })),
    ],
  });
}
function spacer(after = 120) { return new Paragraph({ spacing: { after }, children: [] }); }

// ════════════════════════════════════════════════════════════════════
// KAPAK
// ════════════════════════════════════════════════════════════════════
const cover = [
  new Paragraph({ spacing: { before: 1800, after: 0 }, alignment: AlignmentType.CENTER,
    children: [new TextRun({ text: "SAMSUN BÜYÜKŞEHİR BELEDİYESİ", bold: true, size: 30, color: BRAND })] }),
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 600 },
    children: [new TextRun({ text: "Şehir Tanıtım Mobil Uygulaması", size: 26, color: GREY })] }),
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 400, after: 100 },
    border: { top: { style: BorderStyle.SINGLE, size: 12, color: BRAND, space: 8 },
              bottom: { style: BorderStyle.SINGLE, size: 12, color: BRAND, space: 8 } },
    children: [new TextRun({ text: "DURUM VE ÖZELLİK RAPORU", bold: true, size: 44 })] }),
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 800 },
    children: [new TextRun({ text: "Uygulamanın mevcut durumu, sunduğu özellikler ve kullanım biçimi", italics: true, size: 24, color: GREY })] }),
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 1600 },
    children: [new TextRun({ text: "Haziran 2026", size: 22, color: GREY })] }),
  new Paragraph({ alignment: AlignmentType.CENTER,
    children: [new TextRun({ text: "Sürüm 1.0", size: 22, color: GREY })] }),
  new Paragraph({ children: [new PageBreak()] }),
];

// ════════════════════════════════════════════════════════════════════
// İÇİNDEKİLER
// ════════════════════════════════════════════════════════════════════
const toc = [
  new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun("İçindekiler")] }),
  new TableOfContents("İçindekiler", { hyperlink: true, headingStyleRange: "1-2" }),
  new Paragraph({ children: [new PageBreak()] }),
];

// ════════════════════════════════════════════════════════════════════
// İÇERİK
// ════════════════════════════════════════════════════════════════════
const body = [];

// 1. YÖNETİCİ ÖZETİ
body.push(H1("1. Yönetici Özeti"));
body.push(P("Samsun Şehir Tanıtım Mobil Uygulaması; şehrin tarihi, kültürel, turistik ve sosyal değerlerini hem Samsunlulara hem de şehri ziyaret edenlere dijital bir rehber olarak sunmak amacıyla geliştirilmiştir. Uygulama tek bir yazılım tabanıyla hem Android hem de iOS cihazlarda çalışacak şekilde tasarlanmıştır."));
body.push(P("Uygulama bugün itibarıyla kullanıma hazır olgunluktadır. Gezilecek yerler, önerilen rotalar, etkinlikler, gastronomi, şehir rehberi içerikleri, interaktif harita, artırılmış gerçeklik (AR) deneyimleri, QR kod okuma, akıllı sohbet asistanı, favoriler, gezi planı ve bildirimler gibi başlıca modüllerin tamamı çalışır durumdadır."));
body.push(P("Son dönemde uygulamaya, kullanıcının ilgi alanlarına ve davranışlarına göre içerik öneren akıllı kişiselleştirme altyapısı eklenmiştir. Böylece her kullanıcı, ana sayfada kendi ilgisine uygun yerlerle karşılaşmaktadır. Bu özellik, kullanıcı giriş yapmış olsa da olmasa da çalışır."));
body.push(P("Uygulamaya tüm içeriği ve işlevleri sağlayan sunucu altyapısı (backend) da kurulu ve çalışır durumdadır. Bu rapor mobil uygulamaya odaklanmakla birlikte, sunucu tarafının genel yapısı 7. bölümde özetlenmiştir."));
body.push(lead("Kısaca:", "Uygulama, vatandaşa ve ziyaretçiye “cebinde bir Samsun rehberi” sunar; içerikler belediyenin yönetim panelinden güncellenir; kişisel veriler KVKK’ya uygun şekilde korunur."));
body.push(spacer());

// 2. UYGULAMA HAKKINDA
body.push(H1("2. Uygulama Hakkında"));
body.push(H2("2.1 Amaç"));
body.push(P("Uygulamanın temel amacı, Samsun’un sahip olduğu değerleri dijital ortamda erişilebilir kılmak ve ziyaretçilere gezileri boyunca yol gösteren akıllı bir rehber sağlamaktır. Şehri keşfetmeyi kolaylaştırmanın yanı sıra, belediye ile vatandaş arasında güncel ve etkileşimli bir iletişim kanalı oluşturur."));
body.push(H2("2.2 Hedef Kitle"));
body.push(bullet("şehri gezen yerli ve yabancı turistler,", "Ziyaretçiler: "));
body.push(bullet("şehrindeki etkinlik, mekan ve hizmetleri takip etmek isteyenler,", "Samsunlular: "));
body.push(bullet("içerikleri yöneten ve güncel tutan birimler.", "Belediye personeli: "));
body.push(H2("2.3 Çalıştığı Platformlar"));
body.push(P("Uygulama Android ve iOS telefon ve tabletlerde çalışır. İnternet bağlantısı zayıf olduğunda dahi, daha önce görüntülenen içerikler çevrimdışı olarak gösterilebilir."));
body.push(spacer());

// 3. KULLANIM
body.push(H1("3. Uygulama Nasıl Kullanılır?"));
body.push(P("Kullanıcı uygulamayı ilk açtığında, kısa ve görsel bir tanıtım (onboarding) ekranıyla karşılanır. Bu tanıtım, uygulamanın temel yeteneklerini birkaç adımda anlatır ve son adımda kullanıcıya ilgi alanlarını sorar (tarih, kültür, doğa, gastronomi, etkinlikler, rotalar vb.)."));
body.push(lead("Önemli:", "Bu ilgi alanı seçimi zorunlu değildir, ancak seçildiğinde uygulama içeriği kullanıcının zevkine göre şekillenir. Üyelik (giriş) de zorunlu değildir; uygulamanın neredeyse tüm özellikleri giriş yapılmadan da kullanılabilir."));
body.push(H2("3.1 İki Kullanım Senaryosu"));
body.push(bullet("Tercihler cihaz üzerinde saklanır, kişisel bir hesaba bağlanmaz. Kullanıcı yine de kişiselleştirilmiş öneriler alır.", "Giriş yapmadan: "));
body.push(bullet("Tercihler kullanıcının hesabına kaydedilir; böylece kullanıcı farklı bir cihazdan giriş yaptığında aynı deneyimi sürdürür.", "Giriş yaparak: "));
body.push(H2("3.2 Tipik Bir Kullanıcı Yolculuğu"));
body.push(new Paragraph({ numbering: { reference: "numbers", level: 0 }, spacing: { after: 60 }, children: [new TextRun("Uygulama açılır, ana sayfada şehre dair öne çıkan içerikler ve kişiye özel öneriler görüntülenir.")] }));
body.push(new Paragraph({ numbering: { reference: "numbers", level: 0 }, spacing: { after: 60 }, children: [new TextRun("Kullanıcı kategorilere göz atar, bir mekanı veya rotayı seçer, detaylarını inceler.")] }));
body.push(new Paragraph({ numbering: { reference: "numbers", level: 0 }, spacing: { after: 60 }, children: [new TextRun("Haritadan yol tarifi alır veya yakınındaki noktaları görür.")] }));
body.push(new Paragraph({ numbering: { reference: "numbers", level: 0 }, spacing: { after: 60 }, children: [new TextRun("Beğendiği yerleri favorilere ekler, bir gezi planı oluşturur.")] }));
body.push(new Paragraph({ numbering: { reference: "numbers", level: 0 }, spacing: { after: 120 }, children: [new TextRun("İhtiyaç duyduğunda akıllı asistana yazarak hızlıca bilgi alır.")] }));
body.push(spacer());

// 4. ÖZELLİKLER
body.push(new Paragraph({ heading: HeadingLevel.HEADING_1, pageBreakBefore: true, children: [new TextRun("4. Özellikler")] }));
body.push(P("Aşağıda uygulamanın sunduğu başlıca modüller, herkesin anlayabileceği bir dille özetlenmiştir."));

body.push(H2("4.1 Ana Sayfa ve Keşif"));
body.push(P("Ana sayfa, uygulamanın vitrinidir. Kullanıcıyı karşılayan tanıtım bölümü, hızlı erişim kategorileri ve çeşitli içerik şeritlerinden oluşur:"));
body.push(bullet("kullanıcının ilgi alanlarına göre seçilmiş mekanlar.", "Sizin İçin: "));
body.push(bullet("konuma yakın olan gezilecek noktalar.", "Yakındakiler: "));
body.push(bullet("şehirde en çok ilgi gören yerler (kullanıcının ilgisine göre öne çıkarılır).", "Popüler: "));
body.push(bullet("sisteme son eklenen içerikler.", "Yeni Eklenenler: "));
body.push(bullet("belediyenin vurgulamak istediği özel mekanlar.", "Öne Çıkanlar: "));
body.push(P("Ana sayfada ayrıca kategori kartları (Sağlık Turizmi, Samsun’u Keşfet, Gastronomi, Tarihi Yerler ve Müzeler, Doğa ve Parklar, Plajlar), keşif rotaları, şehir rehberi blog yazıları ve güncel duyurular yer alır."));

body.push(H2("4.2 İçerik Modülleri"));
body.push(lead("Gezilecek Yerler:", "Mekanların görseli, açıklaması, konumu, çalışma saatleri ve iletişim bilgileriyle birlikte listelenmesi; kategoriye göre filtrelenmesi."));
body.push(lead("Rotalar:", "Önceden hazırlanmış gezi rotaları; rota üzerindeki durakları sırayla takip etme ve tamamlama imkanı."));
body.push(lead("Etkinlikler:", "Şehirdeki kültür-sanat ve sosyal etkinliklerin tarih ve konum bilgisiyle takibi."));
body.push(lead("Gastronomi ve Tarifler:", "Yöresel lezzetler, restoranlar ve yemek tarifleri."));
body.push(lead("Şehir Rehberi (Blog):", "Şehri tanıtan yazılı içerikler ve okuma önerileri."));
body.push(lead("Duyurular:", "Belediyeden gelen güncel bilgilendirmeler."));

body.push(H2("4.3 Akıllı Öneri ve Kişiselleştirme"));
body.push(P("Uygulama, kullanıcıyı tanıdıkça daha isabetli öneriler sunar. Kişiselleştirme iki kaynaktan beslenir:"));
body.push(bullet("kullanıcının uygulamaya başlarken seçtiği ilgi alanları.", "Açık tercihler: "));
body.push(bullet("kullanıcının ziyaret ettiği, favorilediği yerler ve tamamladığı rotalar.", "Davranışlar: "));
body.push(P("Bu iki kaynak birleştirilerek kullanıcının ilgi profili oluşturulur ve ana sayfadaki “Sizin İçin” bölümü ile “Popüler” listesi buna göre düzenlenir. Örneğin tarihe ilgi duyan bir kullanıcıya tarihi yerler ve müzeler; doğayı sevene parklar ve plajlar öne çıkarılır. Bu özellik giriş yapılmasa bile çalışır ve kullanıcının davranış verileri gizlilik gereği yalnızca kendi cihazında tutulur."));

body.push(H2("4.4 Harita, Konum ve Yol Tarifi"));
body.push(bullet("İnteraktif harita üzerinde tüm noktaların gösterimi."));
body.push(bullet("Seçilen mekana adım adım yol tarifi."));
body.push(bullet("Kullanıcının konumuna yakın noktaların otomatik önerilmesi."));
body.push(bullet("Yoğunluk haritası ile şehirdeki ilgi yoğunluğunun görselleştirilmesi."));
body.push(bullet("Belirli bölgelere yaklaşıldığında otomatik bilgilendirme (konum tabanlı bildirim)."));

body.push(H2("4.5 Artırılmış Gerçeklik (AR) ve QR Kod"));
body.push(P("Uygulama, şehri daha etkileşimli keşfetmek için modern teknolojiler içerir:"));
body.push(bullet("Kullanıcı telefon kamerasını çevresine doğrulttuğunda, yakındaki ilgi noktaları yön ve mesafe bilgisiyle ekranda gösterilir.", "Artırılmış Gerçeklik: "));
body.push(bullet("Mekanlardaki QR kodlar okutularak ilgili içeriğe veya AR deneyimine anında ulaşılır.", "QR Kod: "));

body.push(H2("4.6 Akıllı Asistan (Sohbet)"));
body.push(P("Uygulama içindeki metin tabanlı asistan, kullanıcının doğal dilde yazdığı sorulara yanıt verir; mekan, etkinlik, rota ve yol tarifi gibi konularda hızlı yardım sağlar. Asistan yalnızca uygulamanın kendi veritabanındaki doğrulanmış içerikleri kullanır; dışarıdan, denetimsiz bir yapay zeka kaynağına bağlı değildir. Böylece verilen bilgiler güvenilir ve belediye onaylıdır."));

body.push(H2("4.7 Favoriler ve Gezi Planı"));
body.push(bullet("Beğenilen mekan, rota ve içeriklerin kaydedilmesi.", "Favoriler: "));
body.push(bullet("Kullanıcının kendi gezisini günlere/duraklara göre planlaması ve harita üzerinde görmesi.", "Gezi Planı: "));

body.push(H2("4.8 Bildirimler ve Etkileşim"));
body.push(P("Belediye, yeni etkinlik, duyuru veya kampanyaları anlık bildirimlerle kullanıcılara iletebilir. Kullanıcı hangi tür bildirimleri almak istediğini kendisi seçebilir."));

body.push(H2("4.9 Puan, Ödül ve Kampanya Sistemi"));
body.push(P("Uygulama, kullanıcı bağlılığını artırmak için bir puan ve kampanya altyapısı içerir: kullanıcı mekan ziyaretleri ve etkinliklerle puan kazanabilir, kampanyalara katılabilir. Bu modül isteğe bağlı olarak açılıp kapatılabilecek şekilde tasarlanmıştır; böylece belediye dilediği zaman devreye alabilir."));

body.push(H2("4.10 Üyelik, Profil ve Ayarlar"));
body.push(bullet("Telefon/e-posta ile kayıt ve doğrulama kodu (OTP) ile güvenli giriş."));
body.push(bullet("Profil yönetimi ve kişisel tercihler."));
body.push(bullet("Hesap silme talebi (KVKK gereği) dahil kullanıcı hakları."));

body.push(H2("4.11 Çoklu Dil ve Görünüm"));
body.push(bullet("Türkçe ve İngilizce dil desteği; dil tek dokunuşla değiştirilebilir."));
body.push(bullet("Açık ve koyu (gece) tema seçeneği."));

// 5. YÖNETİM PANELİ
body.push(new Paragraph({ heading: HeadingLevel.HEADING_1, pageBreakBefore: true, children: [new TextRun("5. İçerik Yönetimi (Yönetim Paneli)")] }));
body.push(P("Uygulamadaki tüm içerikler (mekanlar, rotalar, etkinlikler, duyurular, blog yazıları, kampanyalar, AR noktaları vb.) belediyenin yönetim paneli üzerinden eklenir, düzenlenir ve yayından kaldırılır. Bu sayede içerikler her zaman güncel tutulabilir ve uygulamaya yeni bir sürüm yüklemeye gerek kalmadan anında yansır."));
body.push(P("İçerikler Türkçe ve İngilizce olarak ayrı ayrı yönetilebilir, kategorilere ayrılabilir ve görsellerle zenginleştirilebilir."));

// 6. GÜVENLİK VE KVKK
body.push(H1("6. Güvenlik ve Kişisel Verilerin Korunması (KVKK)"));
body.push(P("Uygulama, kişisel verilerin korunması mevzuatına (KVKK) uygun olarak tasarlanmıştır:"));
body.push(bullet("Kullanıcıdan yalnızca gerekli izinler, gerekçesi açıklanarak istenir."));
body.push(bullet("Kişiselleştirmeye esas davranış verileri varsayılan olarak kullanıcının kendi cihazında tutulur."));
body.push(bullet("Kullanıcı dilediğinde hesabının silinmesini talep edebilir."));
body.push(bullet("Veri iletişimi güvenli bağlantı üzerinden yapılır; uygulama güvenliğini artıran ek koruma katmanları mevcuttur."));

// 7. SUNUCU VE ALTYAPI (BACKEND)
body.push(new Paragraph({ heading: HeadingLevel.HEADING_1, pageBreakBefore: true, children: [new TextRun("7. Sunucu ve Altyapı (Backend)")] }));
body.push(P("Mobil uygulama, arka planda kendi sunucu altyapısıyla (backend) çalışır. Kullanıcının gördüğü tüm içerikler, üyelik işlemleri, öneriler ve bildirimler bu sunucu tarafından yönetilir. Bu bölüm, teknik detaya boğmadan sunucu tarafının ne yaptığını ve neye dayandığını özetler."));

body.push(H2("7.1 Sunucu Ne İşe Yarar?"));
body.push(P("Backend, mobil uygulamanın “beyni ve hafızası” gibi düşünülebilir. Başlıca görevleri:"));
body.push(bullet("İçerikleri saklamak ve mobil uygulamaya sunmak (mekanlar, rotalar, etkinlikler, blog, duyurular, AR noktaları)."));
body.push(bullet("Üyelik, güvenli giriş (doğrulama kodu/OTP) ve kullanıcı profillerini yönetmek."));
body.push(bullet("Kişiselleştirilmiş öneri listelerini hazırlamak."));
body.push(bullet("Puan, kampanya ve dijital cüzdan işlemlerini yürütmek."));
body.push(bullet("Konuma yakın noktalar, yoğunluk haritası ve bölgesel bildirimleri hesaplamak."));
body.push(bullet("Anlık bildirimleri kullanıcılara iletmek ve kullanım istatistiklerini toplamak."));

body.push(H2("7.2 Sunucunun Sağladığı Servisler"));
body.push(P("Sunucu, mobil uygulamadaki her modülün ihtiyaç duyduğu hizmeti ayrı ayrı sağlar:"));
body.push(table(
  [{ t: "Servis grubu", w: 3200 }, { t: "Ne yapar", w: 6160 }],
  [
    ["İçerik servisleri", "Mekan, rota, etkinlik, blog ve duyuru içeriklerini sunar"],
    ["Üyelik ve güvenlik", "Kayıt, doğrulama kodu ile giriş, oturum ve yetki yönetimi"],
    ["Keşif ve öneri", "Kişiye özel ve popüler içerik listelerini hazırlar"],
    ["Favoriler ve gezi planı", "Kullanıcıya özel kayıtları saklar ve cihazlar arası eşitler"],
    ["Puan ve cüzdan", "Puan kazanma, kampanya ve harcama işlemlerini yürütür"],
    ["Konum servisleri", "Yakın noktalar, yoğunluk haritası ve bölgesel bildirim"],
    ["QR ve AR", "QR kodların çözümlenmesi ve AR noktalarının sağlanması"],
    ["İstatistik", "Kullanım verilerinin toplanması ve raporlanması"],
  ]
));

body.push(H2("7.3 Altyapı Bileşenleri"));
body.push(P("Sunucu, modern ve yaygın kullanılan, kanıtlanmış teknolojiler üzerine kuruludur:"));
body.push(table(
  [{ t: "Bileşen", w: 3200 }, { t: "Görevi", w: 6160 }],
  [
    ["Uygulama sunucusu (Node.js)", "Mobil uygulamanın isteklerini karşılayan ana servis"],
    ["Veritabanı (PostgreSQL)", "Tüm içerik ve kullanıcı verilerinin güvenli saklandığı yer"],
    ["Önbellek (Redis)", "Sık kullanılan verileri hızlandırır, sistemi yük altında korur"],
    ["Görsel/dosya deposu", "Fotoğraf ve medya dosyalarının saklandığı depolama"],
    ["Güvenlik katmanı (nginx)", "Gelen trafiği yönetir ve güvenli bağlantı sağlar"],
    ["Zamanlanmış görevler", "Arka planda otomatik işler (örn. bildirim, bakım)"],
  ]
));

body.push(H2("7.4 Kapasite ve Güvenilirlik"));
body.push(bullet("Sistem, çok sayıda eşzamanlı kullanıcıyı karşılayacak şekilde tasarlanmıştır."));
body.push(bullet("Tüm veri iletişimi güvenli (şifreli) bağlantı üzerinden yapılır."));
body.push(bullet("Yetkilendirme rol bazlıdır; her personel yalnızca kendi yetkisindeki işlemleri yapabilir."));
body.push(bullet("Aşırı istek ve kötüye kullanıma karşı koruma (hız sınırlama) mevcuttur."));

body.push(H2("7.5 Mobil ile Sunucu İlişkisi"));
body.push(P("Mobil uygulama ile sunucu sürekli haberleşir; ancak uygulama, internet bağlantısı geçici olarak kesildiğinde de daha önce indirdiği içerikleri çevrimdışı gösterebilecek şekilde tasarlanmıştır. İçerik güncellemeleri sunucu tarafında yapıldığı anda, mobil tarafa yeni sürüm yüklemeye gerek kalmadan yansır."));
body.push(spacer());

// 8. MEVCUT DURUM
body.push(new Paragraph({ heading: HeadingLevel.HEADING_1, pageBreakBefore: true, children: [new TextRun("8. Mevcut Durum ve Olgunluk")] }));
body.push(P("Aşağıdaki tablo, başlıca modüllerin güncel durumunu özetler."));
body.push(table(
  [{ t: "Modül", w: 4200 }, { t: "Durum", w: 2200 }, { t: "Not", w: 2960 }],
  [
    ["Tanıtım ekranı ve ilgi alanı seçimi", "Hazır", "İlk açılışta gösterilir"],
    ["Ana sayfa ve keşif", "Hazır", "Kişiye özel şeritler dahil"],
    ["Gezilecek yerler ve kategoriler", "Hazır", "—"],
    ["Rotalar ve gezi planı", "Hazır", "—"],
    ["Etkinlikler ve duyurular", "Hazır", "—"],
    ["Gastronomi, tarifler, blog", "Hazır", "—"],
    ["Akıllı kişiselleştirme", "Hazır", "Cihaz üzerinde çalışır"],
    ["Harita, yol tarifi, konum", "Hazır", "—"],
    ["Artırılmış gerçeklik ve QR", "Hazır", "—"],
    ["Akıllı asistan (sohbet)", "Hazır", "Sadece kurum içeriği"],
    ["Favoriler ve bildirimler", "Hazır", "—"],
    ["Puan, ödül ve kampanya", "Hazır (opsiyonel)", "İstenince devreye alınır"],
    ["Üyelik ve profil", "Hazır", "—"],
    ["Çoklu dil (TR/EN)", "Büyük ölçüde hazır", "Çeviri tamamlanması sürüyor"],
    ["Sunucu altyapısı (backend)", "Hazır", "İçerik, üyelik, öneri, bildirim"],
    ["Yönetim paneli", "Hazır", "İçerik ekleme/düzenleme"],
    ["Sunucu tabanlı kişiselleştirme", "Planlı", "Bir sonraki aşama"],
  ]
));
body.push(spacer());

// 9. SONRAKİ ADIMLAR
body.push(H1("9. Sonraki Adımlar"));
body.push(P("Uygulama yayına hazır olmakla birlikte, deneyimi sürekli iyileştirmek için planlanan başlıca adımlar şunlardır:"));
body.push(bullet("Kişiselleştirmenin sunucu tarafında da güçlendirilmesi (öneri kalitesinin artırılması).", "Akıllı öneri 2. aşama: "));
body.push(bullet("İngilizce başta olmak üzere tüm içerik ve arayüz çevirilerinin tamamlanması.", "Dil tamamlama: "));
body.push(bullet("Kullanım istatistiklerinin izlenerek içerik ve önerilerin veriye dayalı geliştirilmesi.", "Ölçümleme: "));
body.push(spacer());

// 10. KAPANIŞ
body.push(H1("10. Kapanış"));
body.push(P("Samsun Şehir Tanıtım Mobil Uygulaması, şehrin değerlerini modern ve etkileşimli bir biçimde tanıtan, vatandaş ve ziyaretçiye akıllı bir rehber sunan kapsamlı bir dijital platformdur. Mevcut haliyle temel ve ileri tüm modülleri çalışır durumda olup, içerik yönetimi tamamen belediyenin kontrolündedir. Planlanan iyileştirmelerle birlikte uygulama, kullanıcı deneyimini sürekli geliştirecek esnek bir yapıya sahiptir."));

// ════════════════════════════════════════════════════════════════════
// BELGE
// ════════════════════════════════════════════════════════════════════
const doc = new Document({
  creator: "Samsun Büyükşehir Belediyesi",
  title: "Şehir Tanıtım Mobil Uygulaması - Durum ve Özellik Raporu",
  styles: {
    default: { document: { run: { font: "Calibri", size: 22, color: "222222" } } },
    paragraphStyles: [
      { id: "Heading1", name: "Heading 1", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 30, bold: true, color: BRAND, font: "Calibri" },
        paragraph: { spacing: { before: 320, after: 160 }, outlineLevel: 0,
          border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: BRAND, space: 4 } } } },
      { id: "Heading2", name: "Heading 2", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 25, bold: true, color: "2E7D52", font: "Calibri" },
        paragraph: { spacing: { before: 220, after: 100 }, outlineLevel: 1 } },
    ],
  },
  numbering: {
    config: [
      { reference: "bullets", levels: [{ level: 0, format: LevelFormat.BULLET, text: "•", alignment: AlignmentType.LEFT,
        style: { run: { color: BRAND }, paragraph: { indent: { left: 540, hanging: 260 } } } }] },
      { reference: "numbers", levels: [{ level: 0, format: LevelFormat.DECIMAL, text: "%1.", alignment: AlignmentType.LEFT,
        style: { paragraph: { indent: { left: 540, hanging: 260 } } } }] },
    ],
  },
  sections: [{
    properties: { page: {
      size: { width: 12240, height: 15840 },
      margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 },
    } },
    headers: { default: new Header({ children: [new Paragraph({
      alignment: AlignmentType.RIGHT, spacing: { after: 0 },
      border: { bottom: { style: BorderStyle.SINGLE, size: 4, color: "CCCCCC", space: 4 } },
      children: [new TextRun({ text: "Şehir Tanıtım Mobil Uygulaması — Durum Raporu", size: 16, color: GREY })],
    })] }) },
    footers: { default: new Footer({ children: [new Paragraph({
      alignment: AlignmentType.CENTER,
      children: [new TextRun({ text: "Sayfa ", size: 16, color: GREY }),
        new TextRun({ children: [PageNumber.CURRENT], size: 16, color: GREY }),
        new TextRun({ text: " / ", size: 16, color: GREY }),
        new TextRun({ children: [PageNumber.TOTAL_PAGES], size: 16, color: GREY })],
    })] }) },
    children: [...cover, ...toc, ...body],
  }],
});

const out = path.join(__dirname, "..", "Samsun_Uygulama_Durum_Raporu.docx");
Packer.toBuffer(doc).then((buf) => { fs.writeFileSync(out, buf); console.log("OK:", out); });
