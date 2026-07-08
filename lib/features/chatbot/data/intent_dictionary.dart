import 'package:flutter/foundation.dart';

/// Niyet (intent) tanımı — `intent_matcher` tarafından skorlanacak.
///
/// **Eşleştirme kuralları:**
/// - `keywords`: tam kelime eşleşmesi (token == keyword) → ağırlık 3.0
/// - `stems`: kök eşleşmesi (token.startsWith(stem) ve uzunluk >= 4) → ağırlık 2.0
/// - `phrases`: ardışık iki kelime eşleşmesi → ağırlık 2.5
/// - `mustContain` (opsiyonel): kelime grubu çakışırsa kesin bu intent'e öncelik
///
/// Tüm kelimeler ASCII'ye normalize edilmiş + lowercase olmalı:
/// `'şehir'` → `'sehir'`, `'İstanbul'` → `'istanbul'`.
@immutable
class IntentDefinition {
  const IntentDefinition({
    required this.name,
    required this.priority,
    this.keywords = const [],
    this.stems = const [],
    this.phrases = const [],
    this.mustContain = const [],
  });

  final String name;
  final int priority;
  final List<String> keywords;
  final List<String> stems;
  final List<String> phrases;
  final List<String> mustContain;
}

/// Kategori slot değerleri.
const List<String> kCategorySlots = [
  'historical',
  'cultural',
  'nature',
  'food',
  'art',
  'shopping',
  'nightlife',
  'religious',
];

/// Zaman slot değerleri.
const List<String> kTimeSlots = [
  'today',
  'tomorrow',
  'this_weekend',
  'this_week',
  'this_month',
];

/// Mesafe slot eşikleri (km).
const Map<String, double> kDistanceSlots = {
  'very_near': 1.0,
  'near': 2.5,
  'medium': 5.0,
  'far': 10.0,
};

// ─── INTENT DICTIONARY ────────────────────────────────────────────────────────

/// 15 intent. Yeni intent eklemek için sadece bu map'e ekleyin.
const Map<String, IntentDefinition> kIntentDictionary = {
  // ═══════════════════════════════════════════════════════════════════════════
  // CORE (4)
  // ═══════════════════════════════════════════════════════════════════════════

  'greet': IntentDefinition(
    name: 'greet',
    priority: 100,
    keywords: [
      'selam', 'merhaba', 'merhabalar', 'mrb', 'hey', 'naber', 'nbr',
      'günaydın', 'gunaydin', 'aksamlar', 'akşamlar', 'tunaydin',
      'tünaydın', 'selamun', 'aleykum', 'aleyküm', 'hi', 'hello', 'heyy',
      'selammm', 'slm',
    ],
    // 'iyi' tek başına keyword DEĞİL (feedback ile çakışıyordu + "iyi yerler
    // öner" gibi sorguları yanlış selamlamaya çekiyordu). Sadece kalıp olarak.
    phrases: [
      'nasil sin', 'iyi misin', 'nabiyon', 'naber dostum',
      'iyi gunler', 'iyi günler', 'iyi aksam', 'iyi akşam',
      'iyi gece', 'iyi sabah', 'gunaydin',
    ],
    stems: ['selam', 'merhab', 'gunayd', 'günayd'],
  ),

  'help': IntentDefinition(
    name: 'help',
    priority: 95,
    keywords: [
      'yardım', 'yardim', 'help', 'rehber', 'kullanım', 'kullanim',
      'yetenek', 'beceri', 'özellik', 'ozellik', 'komutlar', 'menü', 'menu',
    ],
    phrases: [
      'ne yap', 'neler yap', 'nasil kullan', 'nasil çalış', 'nasıl çalış',
      'ne yapabilir', 'neler bilir', 'ne sorabilir', 'nasıl sor',
    ],
    stems: ['yardim', 'yardım', 'yetenek', 'kullan'],
  ),

  'feedback': IntentDefinition(
    name: 'feedback',
    priority: 90,
    // Genel olumlu kelimeler ('iyi', 'çok', 'güzel') buradan ÇIKARILDI —
    // "çok güzel bir yer öner" gibi sorguları feedback'e çekiyordu. Bunlar
    // artık yalnız kalıp halinde ("çok güzel", "çok teşekkür") feedback sayılır.
    keywords: [
      'teşekkür', 'tesekkur', 'teşekkürler', 'tesekkurler', 'sağol', 'sagol',
      'sağ', 'sag', 'mersi', 'eyvallah', 'tamam', 'tmm', 'harika', 'mükemmel',
      'mukemmel', 'süper', 'super', 'helal', 'thanks', 'thx',
    ],
    phrases: [
      'teşekkür ederim', 'tesekkur ederim', 'sağ ol', 'sag ol',
      'çok güzel', 'cok guzel', 'çok iyi', 'cok iyi', 'çok teşekkür',
      'cok tesekkur', 'eline sağlık', 'eline saglik', 'çok yardımcı',
      'cok yardimci', 'thank you',
    ],
    stems: ['teşekk', 'tesekk', 'mükemm', 'mukemm'],
  ),

  // Fallback dictionary'de boş — matcher hiçbir intent eşleşmezse fallback'e düşürür.
  'fallback': IntentDefinition(
    name: 'fallback',
    priority: 0,
  ),

  // ═══════════════════════════════════════════════════════════════════════════
  // DISCOVERY (5)
  // ═══════════════════════════════════════════════════════════════════════════

  'nearby_query': IntentDefinition(
    name: 'nearby_query',
    priority: 80,
    keywords: [
      'yakın', 'yakin', 'yakındaki', 'yakindaki', 'yakındakiler', 'yakindakiler',
      'yakınımda', 'yakinimda', 'yakınımdaki', 'yakinimdaki', 'yakınındaki',
      'yakinindaki', 'yakınlardaki', 'yakinlardaki',
      'etraf', 'etrafta', 'etrafımda', 'etrafimda', 'etraftaki', 'etraftakiler',
      'çevre', 'cevre', 'çevremde', 'cevremde', 'çevremdeki', 'cevremdeki',
      'çevredeki', 'cevredeki', 'civar', 'civarda', 'civarımda', 'civarimda',
      'buralarda', 'buradaki', 'burada',
    ],
    phrases: [
      'yakın yer', 'yakindaki yer', 'etrafimda ne', 'cevremde ne',
      'yakinda ne', 'yakındaki yerler', 'buralarda ne var', 'yakınımda ne',
    ],
    stems: ['yakin', 'yakın', 'etraf', 'cevre', 'çevre', 'civar'],
  ),

  'category_query': IntentDefinition(
    name: 'category_query',
    priority: 75,
    keywords: [
      // Genel öneri
      'öner', 'oner', 'tavsiye', 'tavsiyen', 'görmeli', 'gormeli', 'gezilecek',
      'görülecek', 'gorulecek', 'ziyaret',
      // Popüler / öne çıkan / yeni — featured filter
      'popüler', 'populer', 'popularler', 'meşhur', 'meshur', 'ünlü', 'unlu',
      'öne', 'one', 'çıkan', 'cikan', 'öneçıkan', 'oneckan', 'önecıkan',
      'yeni', 'yeniler', 'son', 'eklenen', 'eklenenler', 'best', 'top',
      // Kategori sinonimleri
      'tarihi', 'tarih', 'tarihsel', 'antik', 'eski', 'eserler',
      'müze', 'muze', 'müzeler', 'muzeler',
      'kültür', 'kultur', 'kültürel', 'kulturel', 'sanat', 'galeri',
      'doğa', 'doga', 'park', 'sahil', 'plaj', 'orman', 'göl', 'gol', 'manzara',
      'alışveriş', 'alisveris', 'çarşı', 'carsi', 'pazar', 'mağaza', 'magaza',
      'gece', 'eglence', 'eğlence',
      'cami', 'kilise', 'türbe', 'turbe', 'dini', 'ibadet',
    ],
    phrases: [
      'yer öner', 'yer oner', 'mekan öner', 'mekan oner', 'bana öner',
      'ne gezilir', 'nereye gid', 'gezilecek yer', 'görülecek yer',
      'tarihi yer', 'doga yer', 'doğa yer', 'müze öner', 'muze oner',
    ],
    stems: [
      'öner', 'oner', 'tavsi', 'gezil', 'görül', 'gorul', 'tarihi', 'müze',
      'muze', 'kültür', 'kultur', 'doğa', 'doga', 'park', 'sahil', 'alışver',
      'alisver', 'sanat', 'cami', 'kilise',
    ],
  ),

  'event_query': IntentDefinition(
    name: 'event_query',
    priority: 78,
    keywords: [
      'etkinlik', 'etkinlikler', 'event', 'aktivite', 'organizasyon',
      'festival', 'konser', 'gösteri', 'gosteri', 'tiyatro', 'sergi',
      'fuar', 'şenlik', 'senlik', 'kutlama', 'açılış', 'acilis',
    ],
    phrases: [
      'ne etkinlik', 'hangi etkinlik', 'bugün etkinlik', 'bugun etkinlik',
      'hafta sonu etkinlik', 'bu hafta etkinlik', 'yakın etkinlik',
      'konser var', 'festival var', 'ne var', 'neler oluyor',
    ],
    stems: ['etkin', 'festiv', 'konser', 'göster', 'goster', 'sergi', 'fuar'],
  ),

  'route_query': IntentDefinition(
    name: 'route_query',
    priority: 70,
    keywords: [
      'rota', 'rotalar', 'güzergah', 'guzergah', 'tur', 'turlar', 'parkur',
      'gezi', 'tarihi tur',
    ],
    phrases: [
      'rota öner', 'rota oner', 'hazır rota', 'hazir rota', 'gezi rotası',
      'gezi rotasi', 'tur öner', 'tur oner', 'parkur öner',
    ],
    stems: ['rota', 'güzerg', 'guzerg', 'parkur'],
  ),

  'announcement_query': IntentDefinition(
    name: 'announcement_query',
    priority: 65,
    keywords: [
      'duyuru', 'duyurular', 'haber', 'haberler', 'bildirim', 'açıklama',
      'aciklama', 'gelişme', 'gelisme', 'son dakika',
    ],
    phrases: [
      'son duyuru', 'yeni duyuru', 'belediye duyuru', 'samsun duyuru',
      'hangi haber', 'ne haber', 'son haberler',
    ],
    stems: ['duyur', 'haber', 'gelişm', 'gelism'],
  ),

  // ═══════════════════════════════════════════════════════════════════════════
  // DETAIL (3)
  // ═══════════════════════════════════════════════════════════════════════════

  'place_detail': IntentDefinition(
    name: 'place_detail',
    priority: 82, // category_query'den (75) yüksek — "X nedir?" desenleri öncelikli
    keywords: [
      'nedir', 'nereye', 'neresi', 'hakkında', 'hakkinda', 'bilgi', 'detay',
      'açıkla', 'acikla', 'anlat',
    ],
    phrases: [
      'ne hakkında', 'hakkında bilgi', 'hakkinda bilgi', 'bilgi ver',
      'detay ver', 'detayını', 'detayini', 'anlatır mısın', 'anlatir misin',
      'nedir bu', 'neresi burası', 'neresi burasi',
    ],
    stems: ['hakkin', 'hakkın', 'açıkl', 'acikl', 'detay', 'anlat'],
  ),

  'directions': IntentDefinition(
    name: 'directions',
    priority: 72,
    keywords: [
      'nasıl', 'nasil', 'giderim', 'gidilir', 'ulaşırım', 'ulasirim',
      'gitmek', 'yol', 'yön', 'yon', 'tarif', 'navigasyon', 'rota',
    ],
    phrases: [
      'nasıl gid', 'nasil gid', 'nasıl ulas', 'nasıl ulaş', 'yol tarif',
      'rota oluş', 'yön tarif', 'yon tarif', 'beni götür', 'beni gotur',
    ],
    stems: ['gider', 'gidil', 'ulaşır', 'ulasir', 'tarif'],
  ),

  'samsun_info': IntentDefinition(
    name: 'samsun_info',
    priority: 55,
    // 'tarih' keyword'ü ÇIKARILDI — "Samsun'da tarihi yerler öner" gibi
    // sorgular category_query yerine samsun_info'ya kayıyordu. Şehrin genel
    // tanıtımı için 'samsun' + tanıtım kalıpları yeterli. Ayrıca matcher,
    // somut bir konu (kategori/etkinlik/yemek vb.) varsa samsun_info'yu geri
    // plana atar (bkz. IntentMatcher samsun-tercihi).
    keywords: [
      'samsun', 'şehir', 'sehir', 'kuruluş', 'kurulus', 'tanıtım',
      'tanitim',
    ],
    phrases: [
      'samsun nasıl', 'samsun nedir', 'samsun nerede', 'samsun hakkında',
      'samsun hakkinda', 'samsun tarihi', 'samsun ne ile ünlü',
      'samsunun tarihi', 'şehir hakkında', 'sehir hakkinda',
      'samsun ne demek', 'samsunu tanıt', 'samsunu tanit',
    ],
    stems: ['samsun', 'kuruluş', 'kurulus'],
    mustContain: ['samsun'],
  ),

  // ═══════════════════════════════════════════════════════════════════════════
  // PERSONAL (3)
  // ═══════════════════════════════════════════════════════════════════════════

  'favorites_query': IntentDefinition(
    name: 'favorites_query',
    priority: 68,
    keywords: [
      'favori', 'favoriler', 'favorilerim', 'beğen', 'begen', 'beğendi',
      'kayıt', 'kayit', 'kaydedilen',
    ],
    phrases: [
      'favori listem', 'favorilerimi göster', 'favorilerimi goster',
      'kayıtlı yer', 'kayitli yer', 'beğendiğim', 'begendigim',
    ],
    stems: ['favori', 'beğen', 'begen', 'kayit', 'kayıt'],
  ),

  'itinerary_help': IntentDefinition(
    name: 'itinerary_help',
    priority: 66,
    keywords: [
      'plan', 'planlar', 'planım', 'planim', 'gezi planı', 'itinerary',
      'program', 'günlük', 'gunluk', 'program',
    ],
    phrases: [
      'gezi planı', 'gezi plani', 'plan yap', 'plan oluştur', 'plan olustur',
      'gezi programı', 'gezi programi', 'günlük plan', 'gunluk plan',
      'plan öner', 'plan oner',
    ],
    stems: ['plan', 'program'],
  ),

  'recipe_query': IntentDefinition(
    name: 'recipe_query',
    priority: 76,
    keywords: [
      'tarif', 'tarifler', 'yemek', 'yemekler', 'lezzet', 'lezzetler',
      'restoran', 'restorant', 'lokanta', 'aşçı', 'asci', 'mutfak', 'pide',
      'kebap', 'mantı', 'manti', 'döner', 'doner', 'simit', 'köfte', 'kofte',
      'meyhane', 'kafe', 'cafe',
    ],
    phrases: [
      'ne yenir', 'nerede yiy', 'yöresel yemek', 'yoresel yemek',
      'samsun yemek', 'samsun mutfak', 'tarif öner', 'tarif oner',
      'yemek nerede', 'aç', 'açım', 'acim', 'yöresel tarif',
    ],
    stems: ['tarif', 'yemek', 'lezzet', 'restora', 'lokant', 'mutfak'],
  ),

  // ═══════════════════════════════════════════════════════════════════════════
  // CONVERSATION & SMALLTALK (2)
  // ═══════════════════════════════════════════════════════════════════════════

  // Onay / devam: bot bir soru sorduğunda ("Daha fazlasını ister misin?")
  // kullanıcının "evet / olur / devam" yanıtını anlasın.
  'affirm': IntentDefinition(
    name: 'affirm',
    priority: 58,
    keywords: [
      'evet', 'evt', 'eveet', 'olur', 'tabii', 'tabi', 'elbette', 'olsun',
      'isterim', 'devam', 'başla', 'basla', 'hadi', 'yes', 'yep', 'tamamdir',
      'tabiki', 'kesinlikle', 'aynen',
    ],
    phrases: [
      'olur tabii', 'devam et', 'daha fazla', 'başka göster', 'baska goster',
      'evet lütfen', 'evet lutfen', 'olur olur', 'tabii ki', 'neden olmasın',
      'neden olmasin', 'go on',
    ],
    stems: ['devam', 'ister'],
  ),

  // Ret / kapanış: "hayır / yeter / boşver / kapat".
  'decline': IntentDefinition(
    name: 'decline',
    priority: 57,
    keywords: [
      'hayır', 'hayir', 'yok', 'istemem', 'gerek', 'vazgeç', 'vazgec',
      'boşver', 'bosver', 'iptal', 'kapat', 'yeter', 'dur', 'no', 'hayirr',
    ],
    phrases: [
      'gerek yok', 'istemiyorum', 'boş ver', 'bos ver', 'yeterli', 'yeter artık',
      'yeter artik', 'kapatabilirsin', 'sağ ol yeter', 'sag ol yeter',
      'no thanks',
    ],
    stems: ['istem', 'vazge'],
  ),

  // Kimlik & smalltalk: "kimsin / adın ne / robot musun / espri yap".
  'identity': IntentDefinition(
    name: 'identity',
    priority: 63,
    keywords: [
      'kimsin', 'adin', 'adın', 'ismin', 'nesin', 'robot', 'bot', 'yapay',
      'zeka', 'espri', 'şaka', 'saka', 'fıkra', 'fikra',
    ],
    phrases: [
      'kim sin', 'adin ne', 'adın ne', 'sen kimsin', 'robot musun',
      'insan misin', 'yapay zeka', 'nasil calisiyorsun', 'nasıl çalışıyorsun',
      'seni kim yapti', 'seni kim yaptı', 'espri yap', 'saka yap', 'şaka yap',
      'fıkra anlat', 'fikra anlat', 'ismin ne', 'sen nesin', 'kimsin sen',
    ],
    stems: ['espri'],
  ),

  // ═══════════════════════════════════════════════════════════════════════════
  // PRACTICAL INFO (2) — statik, idare onaylı "hazır cevap" handler'ları
  // ═══════════════════════════════════════════════════════════════════════════

  // Ulaşım: otobüs / tramvay / toplu taşıma / bilet.
  'transport': IntentDefinition(
    name: 'transport',
    priority: 64,
    keywords: [
      'otobüs', 'otobus', 'ulaşım', 'ulasim', 'tramvay', 'dolmuş', 'dolmus',
      'metro', 'minibüs', 'minibus', 'taksi', 'samkart', 'sefer', 'durak',
      'tasima', 'taşıma',
    ],
    phrases: [
      'toplu taşıma', 'toplu tasima', 'otobüs saatleri', 'otobus saatleri',
      'sefer saatleri', 'nasıl ulaşırım', 'nasil ulasirim', 'ulaşım nasıl',
      'ulasim nasil', 'tramvay saatleri', 'otobus hatti', 'otobüs hattı',
    ],
    stems: ['otobüs', 'otobus', 'ulaşım', 'ulasim', 'tramvay', 'dolmus'],
  ),

  // Acil durum & pratik numaralar.
  'emergency': IntentDefinition(
    name: 'emergency',
    priority: 67,
    keywords: [
      'acil', '112', '155', '110', '156', '177', 'hastane', 'polis',
      'itfaiye', 'ambulans', 'eczane', 'jandarma', 'numara', 'numaralar',
    ],
    phrases: [
      'acil durum', 'nöbetçi eczane', 'nobetci eczane', 'acil numara',
      'acil numaralar', 'polis çağır', 'polis cagir', 'en yakın hastane',
      'en yakin hastane', 'acil servis',
    ],
    stems: ['hastane', 'eczane', 'itfaiye', 'ambulan', 'jandarma'],
  ),
};

// ─── ENTITY DICTIONARIES ──────────────────────────────────────────────────────

/// Kategori kelime eşleştirme — slot extraction için.
///
/// Mesajda "tarihi" geçerse → `category: historical`.
const Map<String, List<String>> kCategoryKeywords = {
  'historical': [
    'tarihi', 'tarih', 'tarihsel', 'antik', 'eski', 'eserler', 'kalıntı',
    'kalinti', 'höyük', 'hoyuk', 'kale', 'saat kulesi',
  ],
  'cultural': [
    'kültür', 'kultur', 'kültürel', 'kulturel', 'müze', 'muze', 'sanat',
    'galeri', 'kütüphane', 'kutuphane',
  ],
  'nature': [
    'doğa', 'doga', 'park', 'sahil', 'plaj', 'orman', 'göl', 'gol', 'manzara',
    'şelale', 'selale', 'yayla', 'yeşil', 'yesil', 'bahçe', 'bahce',
  ],
  'food': [
    'yemek', 'yemekler', 'restoran', 'lokanta', 'tarif', 'lezzet', 'mutfak',
    'pide', 'kebap', 'simit', 'köfte', 'kofte', 'meyhane', 'kafe', 'aç',
    'acım', 'acim', 'açım',
  ],
  'art': [
    'sanat', 'galeri', 'sergi', 'heykel', 'resim', 'el sanatı', 'el sanati',
  ],
  'shopping': [
    'alışveriş', 'alisveris', 'çarşı', 'carsi', 'pazar', 'mağaza', 'magaza',
    'avm', 'butik', 'hediyelik',
  ],
  'nightlife': [
    'gece', 'eğlence', 'eglence', 'bar', 'pub', 'kulüp', 'kulup', 'meyhane',
  ],
  'religious': [
    'cami', 'kilise', 'türbe', 'turbe', 'dini', 'ibadet', 'mescid',
  ],
};

/// Zaman ifadesi tespiti — etkinlik filtreleme için.
const Map<String, List<String>> kTimeKeywords = {
  'today': ['bugün', 'bugun', 'şimdi', 'simdi', 'bu akşam', 'bu aksam'],
  'tomorrow': ['yarın', 'yarin'],
  'this_weekend': [
    'hafta sonu', 'haftasonu', 'cumartesi', 'pazar', 'cmt', 'pzr',
  ],
  'this_week': ['bu hafta', 'haftaiçi', 'haftaici'],
  'this_month': ['bu ay', 'ay içinde', 'ay icinde'],
};

/// "Featured / popüler / öne çıkan" tespiti — özel boolean slot.
const List<String> kFeaturedKeywords = [
  'popüler', 'populer', 'meşhur', 'meshur', 'ünlü', 'unlu',
  'öne çıkan', 'one cikan', 'önecikan', 'onecikan',
  'yeni eklenen', 'yeni',
  'best', 'top', 'gözde', 'gozde',
];

/// Mesafe ifadesi tespiti.
const Map<String, List<String>> kDistanceKeywords = {
  'very_near': ['çok yakın', 'cok yakin', 'hemen', 'yanı başı', 'yani basi'],
  'near': ['yakın', 'yakin', 'etrafta', 'civarda'],
  'medium': ['orta', 'biraz uzak', 'uzakça', 'uzakca'],
  'far': ['uzak', 'şehir dışı', 'sehir disi'],
};

// ─── STOPWORDS ────────────────────────────────────────────────────────────────

/// Türkçe yaygın bağlaç + soru ekleri — skor karıştırmasın diye filtre.
///
/// Not: "ne", "nerede", "nasıl" stopword DEĞİL — bunlar intent ipucu taşıyor.
const Set<String> kStopwords = {
  'bir', 'bu', 'şu', 'su', 'o', 'ben', 'sen', 'biz', 'siz', 'onlar',
  've', 'ile', 'ya', 'veya', 'ama', 'fakat', 'çünkü', 'cunku', 'gibi',
  'için', 'icin', 'kadar', 'göre', 'gore', 'değil', 'degil', 'de', 'da',
  'ki', 'mi', 'mı', 'mu', 'mü', 'mi?', 'misin', 'musun',
  // NOT: 'olur' ve 'yok' artık stopword DEĞİL — sırasıyla affirm/decline
  // intent'lerinin keyword'leri (kullanıcı "olur" / "yok" diye yanıt verebilir).
  'oldu', 'olabilir', 'var',
  'bana', 'bence', 'sence', 'lütfen', 'lutfen',
};
