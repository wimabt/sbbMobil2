## SAMSUN BÜYÜKŞEHİR BELEDİYESİ ŞEHİR TANITIM MOBİL UYGULAMASI

## TEKNİK ŞARTNAMESİ

## 1. AMAÇ VE KAPSAM

Bu teknik şartname; Samsun Büyükşehir Belediyesi tarafından kullanılmak üzere
geliştirilecek olan Şehir Tanıtım Mobil Uygulamasının teknik, fonksiyonel ve operasyonel

gereksinimlerini kapsar. Uygulama; şehrin tarihi, kültürel, turistik ve sosyal değerlerinin

tanıtılmasını, ziyaretçilere ve vatandaşlara dijital rehberlik hizmeti sunulmasını

amaçlamaktadır.

```
Bu şartname, daha önce geliştirilen kiosk uygulaması ve bu uygulamaya sonradan eklenen
```
fonksiyonlar referans alınarak hazırlanmış olup, mobil platformlara (iOS ve Android)

uyarlanmıştır.

## 2. TANIMLAR VE KISALTMALAR

**İdare:** Samsun Büyükşehir Belediyesi

**Yüklenici:** Bu teknik şartname kapsamında yazılım geliştirme hizmetini sağlayacak firma

**Uygulama:** Şehir Tanıtım Mobil Uygulaması

**Admin Panel:** İçerik ve sistem yönetiminin yapıldığı web tabanlı yönetim arayüzü

**KVKK:** 6698 sayılı Kişisel Verilerin Korunması Kanunu

## 3. MEVCUT SİSTEMLER VE REFERANSLAR

```
Yüklenici, İdare tarafından daha önce geliştirilmiş ve aktif veya pasif olarak kullanılmış
```
olan şehir tanıtım kiosk uygulamasını incelemek, analiz etmek ve bu sistemde yer alan tüm

fonksiyonları mobil uygulamaya uyarlamakla yükümlüdür.

```
Kiosk uygulamasında kullanılan;
```
- İçerik türleri,
- Kategori yapıları,
- Medya formatları,
- Lokasyon bazlı veri kurgusu,
- Kullanıcı etkileşim senaryoları

mobil uygulama geliştirme sürecinde referans alınacaktır. Mobil uygulama, kiosk sisteminde

edinilen kullanıcı deneyimi doğrultusunda geliştirilmeli; kullanıcıyı yönlendiren, sade ve

erişilebilir bir arayüz yapısına sahip olmalıdır.

```
Ayrıca, kiosk uygulaması için üretilmiş olan mevcut içeriklerin, ek bir işlem gerektirmeden
```
veya minimum düzenleme ile mobil uygulamada kullanılabilmesine imkân sağlayacak bir veri
yapısı oluşturulmalıdır.

```
İdare tarafından talep edilmesi halinde, kiosk uygulaması ile mobil uygulama arasında
```
içerik bütünlüğü ve sürekliliği sağlanacak entegrasyon senaryoları Yüklenici tarafından ücretsiz

olarak sağlanacaktır.

## 4. GENEL TEKNİK MİMARİ

```
4.1 Mimari Yaklaşım
```

4.1.1 Şehir tanıtım mobil uygulaması; ölçeklenebilir, sürdürülebilir ve modüler bir mimari
yaklaşım ile geliştirilecektir.
4.1.2 Sistem mimarisi; mobil uygulama katmanı, sunucu (backend) katmanı, veri katmanı
ve yönetim paneli katmanlarından oluşacaktır.
4.1.3 Tüm bileşenler, birbirinden bağımsız geliştirilebilir ve güncellenebilir şekilde
tasarlanacaktır.

**4.2 Mobil Uygulama Katmanı**
4.2.1 Mobil uygulama; Android, IOS ve gerektiğinde Harmony işletim sistemlerini
destekleyecek şekilde tek kod tabanı veya eşdeğer çapraz platform mimarisi ile
geliştirilecektir.
4.2.2 Uygulama; performans, kullanıcı deneyimi ve bakım kolaylığı açısından modern
mobil uygulama geliştirme prensiplerine uygun olacaktır.
4.2.3 Çapraz platform geliştirme teknolojileri (örneğin Flutter veya eşdeğeri) tercih
edilebilir.

**4.3 Veri ve Entegrasyon Katmanı**
4.3.1 Veri katmanı; güvenli, yedeklenebilir ve ölçeklenebilir şekilde yapılandırılacaktır.
4.3.2 Harita, konum, bildirim ve üçüncü taraf servis entegrasyonları bu katman üzerinden
sağlanacaktır.
4.3.3 Tüm veri alışverişleri güvenli protokoller üzerinden gerçekleştirilecektir.

**4.4 Yönetim Panelleri**
4.4.1 İçerik, lokasyon, kampanya, bildirim ve kullanıcı yönetimi için web tabanlı yönetim
panelleri geliştirilecektir.
4.4.2 Yönetim panelleri, rol bazlı yetkilendirme yapısına sahip olacaktır.
4.4.3 Yönetim panelleri üzerinden yapılan tüm işlemler kayıt altına alınacaktır.

**4.5 Güvenlik ve Sürdürülebilirlik**
4.5.1 Sistem genelinde güvenli yazılım geliştirme prensipleri uygulanacaktır.
4.5.2 Mimari yapı, ileride eklenecek yeni modüller ve servisler için genişletilebilir
olacaktır.
4.5.3 Teknoloji bağımlılığı yaratacak, kapalı veya taşınamaz çözümlerden kaçınılacaktır.

## 5. MOBİL UYGULAMA TEKNİK GEREKSİNİMLERİ

**5.1 Genel Gereksinimler**
5.1.1 Mobil uygulama, Samsun Büyükşehir Belediyesi şehir tanıtım faaliyetlerine hizmet
edecek şekilde kullanıcı dostu, hızlı ve kararlı bir yapıda geliştirilecektir.
5.1.2 Uygulama, iOS (minimum iOS 1 3 ) ve Android (minimum Android 10) işletim
sistemlerinde çalışmalı, çevrimdışı (offline) modda da kullanılabilir olmalıdır.
5.1.3 Uygulama, resmi kurum kullanımına uygun olarak reklam, yönlendirici üçüncü taraf
içerikler veya kullanıcı deneyimini bozacak unsurlar içermeyecektir.

**5.2 Kullanıcı Arayüzü ve Deneyimi (UI/UX)**
5.2.1 Kullanıcı arayüzü; sade, anlaşılır ve erişilebilir tasarım prensiplerine uygun olarak
geliştirilecektir.
5.2.2 Görsel tasarım, Samsun Büyükşehir Belediyesi kurumsal kimliği ile uyumlu
olacaktır.


5.2.3 Uygulama içerisindeki tüm yönlendirmeler, ilk kez kullanan kullanıcılar için dahi
kolay anlaşılır olacaktır.
5.2.4 Koyu (dark) ve açık (light) tema desteği sağlanacaktır.

**5.3 İçerik Yönetimi ve Güncellik**
5.3.1 Uygulama içerisinde yer alan tüm içerikler (metin, görsel, lokasyon, etkinlik vb.)
yönetim panelleri üzerinden güncellenebilir olacaktır.
5.3.2 İçerik güncellemeleri için uygulamanın yeniden mağazaya yüklenmesi
gerekmeyecektir.
5.3.3 Güncellenen içerikler, kullanıcılara en kısa sürede yansıtılacaktır.

**5.4 Güncellenebilirlik**
5.4.1 Mobil uygulama, teknolojik gelişmelere ve işletim sistemi güncellemelerine uyum
sağlayacak şekilde geliştirilecektir.
5.4.2 Hata düzeltmeleri ve performans iyileştirmeleri, uygulamanın sürekliliğini
bozmayacak şekilde yapılacaktır.
5.4.3 Güncellemeler, kullanıcı deneyimini olumsuz etkilemeyecek biçimde
planlanacaktır.
5.4.4 Uygulama mimarisi, ileride eklenecek yeni modüller ve özellikler için uygun
olacaktır.

**5.5 Güvenlik**
5.5.1 Uygulama, yetkisiz erişim ve veri ihlallerine karşı gerekli güvenlik önlemleri
alınarak geliştirilecektir.
5.5.2 Kullanıcı verileri güvenli şekilde saklanacak ve iletilecektir.
5.5.3 Uygulama, tersine mühendislik ve kötü amaçlı müdahalelere karşı mümkün olan
teknik tedbirleri içerecektir.

## 6. FONKSİYONEL ÖZELLİKLER

**6.1 Genel**
6.1.1 Mobil uygulama, Samsun Büyükşehir Belediyesi’nin şehir tanıtım, bilgilendirme ve
yönlendirme faaliyetlerini destekleyecek fonksiyonel özellikleri içerecektir.
6.1.2 Tüm fonksiyonlar kullanıcı dostu, erişilebilir ve sürdürülebilir olacak şekilde
tasarlanacaktır.

**6.2 Şehir Tanıtım İçerikleri**
6.2.1 Şehre ait tanıtım içerikleri metin, görsel ve multimedya formatlarında sunulacaktır.
6.2.2 Tanıtım içerikleri yönetim paneli üzerinden eklenebilir, düzenlenebilir ve
kaldırılabilir olacaktır.
6.2.3 İçerikler kategorilere ayrılarak kullanıcıların kolay erişimi sağlanacaktır.

**6.3 Kullanım Senaryoları ve Kullanıcı Bağlılığı Stratejileri
6.3.1 Genel**

- Uygulama, temel şehir tanıtım fonksiyonları açısından üyelik gerektirmeden
    kullanılabilir olacaktır.
- Üyelik gerektiren alanlarda kullanıcıdan açık rıza alınacak ve ilgili mevzuata
    uygun hareket edilecektir.
- Kullanıcı üye olma işlemi web tabanlı doğrulama yöntemi ile olacaktır.


- Mobil uygulama, yalnızca bilgilendirme amacıyla içerik sunan bir yapıdan öte,
    kullanıcıların aktif olarak etkileşimde bulunduğu ve tekrar kullanım alışkanlığı
    kazandığı bir sistem olarak tasarlanacaktır.
- Uygulama geliştirme sürecinde farklı kullanıcı tiplerine yönelik kullanım
    senaryoları (user flow) tanımlanacak ve tüm fonksiyonel yapı bu senaryoları
    destekleyecek şekilde kurgulanacaktır.
- Tanımlanan kullanıcı senaryoları, uygulama arayüzü, navigasyon yapısı ve
    fonksiyonel modüllerin tasarımında esas alınacaktır.

**6.3.2 Temel Kullanım Senaryoları**

- Uygulama, şehirde bulunan turistik, kültürel ve sosyal lokasyonların kullanıcı
    konumuna bağlı olarak listelenmesini ve harita üzerinde görüntülenmesini
    sağlayacaktır.
- Kullanıcıların seçilen lokasyonlara erişim sağlayabilmesi amacıyla harita
    tabanlı yönlendirme ve navigasyon desteği sunulacaktır.
- Belirlenen lokasyonlara ait içeriklere; QR kod okuma veya artırılmış gerçeklik
    (AR) modülü aracılığıyla erişim imkânı sağlanacaktır.
- Uygulama, kullanıcıların birden fazla lokasyonu içeren günlük gezi planı
    oluşturabilmesine imkân sağlayacak şekilde tasarlanacaktır.
- Uygulama, şehirde gerçekleştirilen etkinlik ve duyuruların listelenmesini ve
    detaylarının görüntülenmesini sağlayacaktır.
- Kullanıcılara, ilgi alanları ve tercihlerine bağlı olarak içerik ve etkinlik önerileri
    sunulmasına imkân tanınacaktır.
- Kullanıcıların güncel gelişmelerden haberdar edilmesi amacıyla bildirim
    altyapısı desteklenecektir.
- Uygulama, kampanya, bilgilendirme ve duyuru içeriklerine erişimi
    destekleyecektir.
- Uygulama, sosyal alanlar, kültürel mekânlar ve popüler lokasyonların
    keşfedilmesini destekleyecek içerik ve listeleme yapıları sunacaktır.
- Kullanıcılara, konum bazlı veya popülerlik kriterlerine göre öneri sunulmasına
    imkân tanınacaktır.
- QR kod ve artırılmış gerçeklik (AR) modülleri aracılığıyla içeriklere erişim
    sağlanacaktır.
- Uygulama, farklı kullanıcı gruplarına uygun içeriklerin filtrelenmesine imkân
    sağlayacaktır.
- Kullanıcıların birden fazla lokasyonu kapsayan planlama yapabilmesi
    desteklenecektir.
**6. 3 .3 Kullanıcı Akışları (User Flow) Tasarım İlkeleri**
- Kullanıcıların uygulama içerisindeki temel fonksiyonlara hızlı ve kolay
erişebilmesi sağlanacaktır.
- Ana fonksiyonlara (keşif, harita, etkinlikler, arama vb.) en fazla 2–3 adımda
erişim mümkün olacak şekilde navigasyon yapısı tasarlanacaktır.
- Kullanıcı arayüzü, sade, anlaşılır ve sezgisel olacak şekilde tasarlanacaktır.
- İlk kez uygulamayı kullanan kullanıcılar için yönlendirici ve bilgilendirici
onboarding (karşılama) ekranları sağlanacaktır.
**6. 3 .4 Kullanıcı Bağlılığı (Retention) Stratejileri**


- Uygulama, kullanıcıların tekrar kullanımını teşvik edecek mekanizmaları
    içerecek şekilde tasarlanacaktır.
- Bu kapsamda aşağıdaki fonksiyonlar desteklenecektir:
    ✓ Kullanıcı konumu, tercihleri ve kullanım geçmişine bağlı olarak içerik
       önerileri sunulması
    ✓ Güncel ve dinamik içerik akışı (etkinlikler, duyurular, yeni eklenen
       lokasyonlar vb.)
    ✓ Kullanıcıların içerikleri kaydedebilmesine ve daha sonra erişebilmesine
       imkân sağlayan mekanizmalar
    ✓ Bildirim altyapısı aracılığıyla kullanıcıların uygulamaya yeniden
       yönlendirilmesi
    ✓ QR kod ve artırılmış gerçeklik (AR) modülleri ile etkileşimli deneyimlerin
       sunulması
    ✓ Kullanıcıların uygulamayı düzenli olarak kullanmasını teşvik etmek
       amacıyla içeriklerin periyodik olarak güncellenmesi sağlanacaktır.
**6. 3 .5 Onboarding ve İlk Kullanım Deneyimi**
- Uygulamayı ilk kez kullanan kullanıcılar için kısa ve anlaşılır bir tanıtım süreci
(onboarding) sunulacaktır.
- Bu süreçte uygulamanın temel fonksiyonları kullanıcıya görsel ve metinsel
olarak tanıtılacaktır.
- Kullanıcıdan isteğe bağlı olarak ilgi alanı seçimi alınabilecek ve bu bilgiler
içerik öneri süreçlerinde kullanılabilecektir.
**6. 3 .6 Ölçümleme ve Sürekli İyileştirme**
- Uygulama içerisindeki kullanıcı davranışları analiz edilebilir şekilde kayıt altına
alınacaktır.
- Kullanıcıların uygulama içerisindeki etkileşimleri (ziyaret edilen içerikler,
kullanım sıklığı, terk edilen noktalar vb.) izlenebilir olacaktır.
- Elde edilen veriler doğrultusunda kullanıcı deneyimi ve uygulama performansı
iyileştirilecektir.
- Kullanıcı senaryolarının etkinliği düzenli olarak değerlendirilecek ve gerekli
güncellemeler yapılacaktır.

**6.4 Akıllı Öneri ve Keşif Sistemi
6.4.1 Genel**

- Mobil uygulama, kullanıcıların ilgi alanlarına, konumuna ve kullanım
    davranışlarına bağlı olarak içeriklerin dinamik şekilde sunulmasını sağlayan bir
    keşif ve öneri mekanizmasına sahip olacaktır.
- Sistem, kullanıcıların uygulama içerisinde hızlı ve kolay şekilde içerik
    keşfetmesini destekleyecek şekilde tasarlanacaktır.

**6.4.2 Keşif (Discovery) Fonksiyonları**

- Uygulama ana ekranında, kullanıcıya önerilen içeriklerin listelendiği dinamik
    bir keşif alanı bulunacaktır.
- Bu alanda aşağıdaki içerik türleri sunulabilecektir:
    ✓ Yakındaki lokasyonlar
    ✓ Popüler içerikler
    ✓ Yeni eklenen içerikler


```
✓ Öne çıkan etkinlikler
```
- İçerikler, yönetim paneli üzerinden belirlenen kriterlere göre sıralanabilir
    olacaktır.

**6.4.3 Konum Bazlı Öneriler**

- Uygulama, kullanıcının anlık konum bilgisine bağlı olarak yakınındaki
    lokasyonları listeleyebilecektir. (Near by)
- Kullanıcının belirli bir lokasyona yaklaşması durumunda, ilgili içeriklerin
    önerilmesine imkân tanınacaktır.
- Konum bazlı öneriler, kullanıcı deneyimini olumsuz etkilemeyecek şekilde
    optimize edilecektir.

**6.4.4 Kişiselleştirme**

- Sistem, kullanıcı tercihleri ve kullanım davranışlarına bağlı olarak içerik
    önerileri sunabilecek şekilde tasarlanacaktır.
- Kullanıcıdan alınan ilgi alanı bilgileri, öneri algoritmasında kullanılabilecektir.
- Kullanıcının daha önce görüntülediği veya etkileşimde bulunduğu içerikler
    dikkate alınarak öneriler geliştirilebilecektir.

**6.4.5 Filtreleme ve Sıralama**

- Kullanıcılar, içerikleri kategori, konum, popülerlik ve benzeri kriterlere göre
    filtreleyebilecektir.
- İçerik listeleri, farklı sıralama seçenekleri (yakınlık, popülerlik, tarih vb.) ile
    sunulabilecektir.

**6.4.6 Yönetim Paneli Entegrasyonu**

- Yönetim paneli üzerinden öne çıkarılacak içerikler tanımlanabilecektir.
- Belirli içeriklerin keşif alanında öncelikli olarak gösterilmesi sağlanabilecektir.
- İçeriklerin görünürlüğü ve sıralama kriterleri yönetim paneli üzerinden
    düzenlenebilecektir.

**6.4.7 Performans ve Optimizasyon**

- Öneri ve keşif sistemi, yüksek veri hacimlerinde dahi hızlı ve kesintisiz
    çalışacak şekilde optimize edilecektir.
- İçerik listeleri, kullanıcı deneyimini olumsuz etkilemeyecek şekilde hızlı
    yüklenmelidir.
- Gerekli durumlarda veri önbellekleme (cache) mekanizmaları kullanılacaktır.

**6.5 Favoriler, Rota ve Gezi Planlama Modülü
6.5.1 Favoriler (Kaydetme) Fonksiyonu**

- Kullanıcılar, uygulama içerisinde yer alan lokasyonları, etkinlikleri ve içerikleri
    favorilerine ekleyebilecektir.
- Favorilere eklenen içerikler, kullanıcıya özel bir liste altında
    görüntülenebilecektir, favorilerine ekledikleri içerikleri listeden
    kaldırabilecektir.
- Favori içeriklere hızlı erişim sağlanması amacıyla uygulama içerisinde ilgili bir
    ekran veya alan bulunacaktır.

**6.5.2 Gezi Planlama (Itinerary) Fonksiyonu**


- Uygulama, kullanıcıların birden fazla lokasyonu içeren gezi planı
    oluşturabilmesine imkân sağlayacaktır, oluşturulan planlara lokasyon
    ekleyebilecek, çıkarabilecek ve sıralama yapabilecektir.
- Planlanan lokasyonlar tarih ve saat bilgisi ile ilişkilendirilebilecektir.
- Kullanıcıların birden fazla plan oluşturabilmesi desteklenecektir.
- Oluşturulan planlar uygulama içerisinde saklanacak ve daha sonra erişilebilir
    olacaktır.
- Kullanıcıya, seçilen lokasyonlar arasında önerilen güzergâh sunulacaktır.
- Rota oluşturma işlemi sırasında kullanıcı konumu dikkate alınabilecektir.

**6.5.3 Lokasyon ve Harita Fonksiyonları**

- Şehir içerisindeki önemli noktalar (turistik alanlar, kültürel mekânlar, sosyal
    alanlar vb.) harita üzerinde gösterilecek ve ısı haritası ile desteklenecektir.
- Lokasyon bilgileri yönetim paneli üzerinden tanımlanacak ve
    güncellenebilecektir.
- Kullanıcılar lokasyon detaylarına, açıklama ve yönlendirme bilgilerine
    erişebilecektir.

**6.5.4 Etkinlik ve Duyuru Yönetimi**

- Şehirde düzenlenen etkinlikler ve belediyeye ait duyurular uygulama üzerinden
    yayınlanacaktır.
- Etkinlikler tarih, saat, konum ve açıklama bilgilerini içerecektir.
- Süresi dolan etkinlik ve duyurular otomatik olarak pasif duruma alınabilecektir.

**6.5.5 Bildirim Fonksiyonları**

- Kullanıcılara genel, hedefli ve lokasyon bazlı bildirimler gönderilebilecektir.
- Bildirim içerikleri yönetim paneli üzerinden oluşturulacak ve planlanacaktır.
- Bildirim gönderim geçmişi kayıt altına alınacaktır.

**6.6 Arama ve Filtreleme**
6.6.1 Uygulama içerisinde hızlı erişim için arama fonksiyonu bulunacaktır.
6.6.2 İçerikler kategori, konum ve benzeri kriterlere göre filtrelenebilecektir.
6.6.3 Harita görünümünde canlı arama ve anlık filtreleme işlemleri yapılabilecektir.

**6.7 Çoklu Dil Desteği**
6.7.1 Uygulama Türkçe başta olmak üzere birden fazla dil desteği sunacaktır.
6.7.2 Dil içerikleri yönetim paneli üzerinden ayrı ayrı yönetilebilir olacaktır.

**6.8 QR Kod ve Artırılmış Gerçeklik (AR) Modülü
6.8.1 Genel**

- Mobil uygulama içerisinde şehir tanıtım deneyimini zenginleştirmek amacıyla
    QR kod ve artırılmış gerçeklik (AR) teknolojilerini destekleyen bir modül
    bulunacaktır.
- Bu modül sayesinde kullanıcılar şehir içerisinde belirlenen noktalarda bulunan
    QR kodları okutarak veya mobil cihaz kamerasını kullanarak artırılmış gerçeklik
    içeriklerine erişebilecektir.


- AR modülü; şehirde bulunan tarihi yapılar, turistik alanlar, kültürel mekânlar ve
    belirlenen tanıtım noktaları hakkında kullanıcıya görsel ve etkileşimli bilgi
    sunmak amacıyla kullanılacaktır.
- Geliştirilecek AR altyapısı Android ve iOS işletim sistemlerinde çalışacak
    şekilde tasarlanacaktır.

```
6.8.2 QR Kod Fonksiyonları
```
- Mobil uygulama içerisinde QR kod okuma özelliği bulunacaktır.
- Kullanıcılar şehir genelinde belirlenen noktalara yerleştirilecek QR kodları
    mobil uygulama üzerinden okutarak ilgili içeriklere erişebilecektir.
- QR kod okutulduğunda uygulama içerisinde ilgili tanıtım içeriği, bilgi sayfası
    veya artırılmış gerçeklik deneyimi otomatik olarak açılacaktır.
- QR kodlar yönetim paneli üzerinden tanımlanabilecek ve ilgili içerikler ile
    ilişkilendirilebilecektir.

# 6.8.3 Artırılmış Gerçeklik (AR) Fonksiyonları – Detaylı Teknik Gereksinimler

**6.8.3.1 Konum Tabanlı AR Çalışma Mantığı**
Mobil uygulama, belirlenen noktalarda artırılmış gerçeklik içeriklerinin gösterilebilmesi için
cihazın **GPS/GNSS konumu, pusula (manyetometre), ivmeölçer, jiroskop ve kamera
verilerini birlikte** kullanacaktır. Kullanıcı mobil cihaz kamerasını ilgili tanıtım noktasına,
yapıya, esere veya lokasyona çevirdiğinde; sistem kullanıcının anlık konumu, cihazın
yönelimi (heading), eğim açısı (pitch), yatay dönüşü (yaw) ve kamera bakış doğrultusunu
hesaplayarak eşleşen AR içeriğini ekranda gösterecektir.

**6.8.3.2 İlgi Noktası (POI) Tabanlı AR Eşleştirme**
Her AR noktası yönetim panelinde en az aşağıdaki bilgilerle tanımlanabilir olacaktır:

- Lokasyon adı
- Enlem / boylam bilgisi
- Gerekirse yükseklik bilgisi
- Etkinleşme yarıçapı (ör. 10 m, 25 m, 50 m)
- Görünme açısı veya yön bilgisi
- İlişkili içerik tipi (bilgi kartı, 3B model, ses, video, animasyon vb.)
- İçeriğin gösterim önceliği
- Dil seçeneği
- Yayın durumu

Sistem, kullanıcının cihaz konumu ile tanımlı AR noktaları arasındaki mesafeyi hesaplayacak;
belirlenen yarıçap içine giren ve kamera bakış yönü ile uyumlu olan noktalar için ilgili AR
içeriğini tetikleyecektir.

**6.8.3.3 Kamera Yönü ile İçerik Gösterimi**
Uygulama, yalnızca kullanıcının ilgili lokasyona yaklaşmasını değil, aynı zamanda cihaz
kamerasının **ilgili hedefe çevrilmiş olmasını** da dikkate alacaktır. Bu kapsamda:

- Kullanıcının anlık konumu ile hedef nokta arasındaki doğrultu açısı hesaplanacaktır.
- Cihazın pusula ve sensör verilerinden elde edilen kamera yönü ile hedef doğrultu
    karşılaştırılacaktır.


- Belirlenen tolerans açısı içerisinde kalınması halinde ilgili AR içeriği görünür
    olacaktır.
- Kullanıcı cihazı hedef noktadan uzaklaştırdığında veya yön değiştirdiğinde AR içeriği
    gizlenebilecek, pasif hale alınabilecek veya ekranda yeniden konumlandırılabilecektir.

Örnek olarak, kullanıcı tarihi bir yapının önüne geldiğinde ve telefon kamerasını o yapıya
çevirdiğinde, sistem yapı ile eşleşen bilgi kartını, 3B görseli, sesli anlatımı veya animasyonu
kamera görüntüsü üzerine bindirerek gösterecektir.

**6.8.3.4 Geospatial / Markerless AR Altyapısı**
Markerless AR senaryosunda sistem, fiziksel işaretleyiciye ihtiyaç duymaksızın gerçek dünya
koordinatlarına bağlı içerik gösterebilecektir. Bu kapsamda kullanılacak altyapı; desteklenen
cihazlarda **ARCore, ARKit veya eşdeğer teknolojiler** üzerinden çalışabilecek yapıda
olacaktır.
Bu yapı sayesinde dijital içerikler:

- Dünya koordinatlarına bağlı,
- Kullanıcının hareketine göre yeniden hizalanabilen,
- Kamera perspektifine uygun şekilde ölçeklenebilen,
- Gerçek sahne ile tutarlı biçimde konumlandırılabilen
    bir şekilde sunulacaktır.

**6.8.3.5 Sensör Füzyonu ve Doğruluk Yönetimi**
Konum tabanlı AR deneyiminin kararlı çalışabilmesi için uygulama sensör verilerini tek
başına değil, **sensör füzyonu** yaklaşımı ile değerlendirecektir. GPS, pusula, ivmeölçer ve
jiroskop verileri birlikte işlenerek AR içeriğinin ekrandaki konumu mümkün olan en stabil
şekilde hesaplanacaktır.
Sistem, sensör sapmalarını azaltmak amacıyla aşağıdaki mekanizmaları desteklemelidir:

- Konum doğruluğu düşükse kullanıcıyı bilgilendirme
- Pusula kalibrasyonu gerektiğinde kullanıcı yönlendirmesi
- Ani yön değişimlerinde yumuşatma (smoothing)
- Titreşim ve sensör sapmalarına karşı filtreleme
- Düşük doğruluk durumunda içerik gösterimini sınırlandırma veya geciktirme

**6.8.3.6 Yakınlık ve Görüş Alanı Kuralları**
AR içeriğinin ekranda gösterilmesi için aşağıdaki koşullar parametrik olarak tanımlanabilir
olacaktır:

- Kullanıcının ilgili POI’ye maksimum yaklaşma mesafesi
- İçeriğin görünür olacağı minimum ve maksimum açı
- Aynı anda ekranda gösterilebilecek maksimum AR öğe sayısı
- Öncelikli içerik sıralaması
- Yakındaki birden fazla nokta için çakışma yönetimi

Yüklenici, çok sayıda yakın POI bulunması halinde kullanıcı deneyimini bozmayacak bir
görünürlük mantığı geliştirecektir. Gerekli durumlarda en yakın, en önemli veya yönetim
panelinde öncelik verilmiş içerik öne çıkarılacaktır.


**6.8.3.7 İçerik Türleri ve Gösterim Katmanları**
Konum tabanlı AR modülü aşağıdaki içerik türlerini destekleyecek şekilde tasarlanacaktır:

- Sabit bilgi kartları
- Başlık ve kısa açıklama katmanları
- 2B görseller
- 3B modeller
- Animasyonlu nesneler
- Sesli anlatım tetikleme
- Video açılış katmanı
- “Detay gör”, “rota oluştur”, “favoriye ekle” gibi etkileşimli butonlar

AR ekranında gösterilen dijital içerikler, kamera görüntüsünü tamamen kapatmayacak;
okunabilirlik ve kullanıcı güvenliği gözetilerek uygun konumda ve ölçekte gösterilecektir.

**6.8.3.8 Yönetim Panelinden AR Noktası Tanımlama**
Yönetim paneli üzerinden yetkili kullanıcılar yeni AR noktaları tanımlayabilecek, mevcut
noktaları güncelleyebilecek ve pasife alabilecektir. Panelde en az şu alanlar bulunacaktır:

- Harita üzerinden nokta seçimi
- Koordinat girişi
- Etkinlik yarıçapı tanımı
- Yön/açı bilgisi
- İlişkili medya ve içerik ataması
- Dil bazlı içerik seçimi
- Zamanlı yayınlama / yayından kaldırma
- Test modu / ön izleme desteği

**6.8.3.9 Performans ve Ön Bellekleme**
Kamera ilgili noktaya çevrildiğinde içeriğin gecikmesiz gösterilebilmesi amacıyla sistem,
kullanıcının bulunduğu bölgedeki muhtemel AR içeriklerini önceden sorgulayabilecek ve
gerekli medya/meta verileri önbelleğe alabilecektir.
Bu sayede:

- Kamera açıldığında bekleme süresi azaltılacak,
- Konuma yakın içerikler daha hızlı yüklenecek,
- Zayıf bağlantı koşullarında temel AR deneyimi sürdürülebilecektir.

**6.8.3.10 Hata ve Uyum Senaryoları**
Aşağıdaki durumlar için kontrollü davranış geliştirilecektir:

- Cihazda AR desteği bulunmaması
- Kamera izni verilmemesi
- Konum izni verilmemesi
- Pusula/sensör verisinin yetersiz olması
- İnternet bağlantısının olmaması
- Hedef noktanın doğruluk sınırları içinde tespit edilememesi

Bu durumlarda uygulama kullanıcıya anlaşılır uyarı verecek, desteklenmeyen fonksiyonları
güvenli şekilde devre dışı bırakacak ve mümkünse alternatif içerik gösterimi sunacaktır.


**6.8.4 Performans ve Sistem Gereksinimleri**

- AR modülü farklı cihaz performanslarına uyum sağlayacak şekilde optimize
    edilecektir.
- AR içerikleri mümkün olan durumlarda akıcı ve kesintisiz görüntü sağlayacak
    şekilde çalışacaktır.
- AR deneyiminin başlatılması ve içerik yükleme süreleri kullanıcı deneyimini
    olumsuz etkilemeyecek şekilde optimize edilecektir.
- AR modülü uzun süreli kullanımda mobil cihazın işlemci ve batarya
    kaynaklarını verimli kullanacak şekilde tasarlanacaktır.
- Uygulama tarafından oluşturulan ek batarya tüketiminin ortalama kullanım
    koşullarında %15’i aşmaması hedeflenecektir.

**6.8.5 Çevrimdışı Kullanım**

- AR deneyimlerinin mümkün olan kısmı internet bağlantısı olmadan da
    çalışabilecek şekilde tasarlanacaktır.
- Uygulama içerisinde daha önce indirilen veya önbelleğe alınan içeriklere
    çevrimdışı erişim sağlanabilecektir.
- İnternet bağlantısı gerektiren içerikler için kullanıcı bilgilendirilecektir.

**6.8.6 AR İçerik Üretimine İlişkin Hususlar**

- Bu teknik şartname kapsamında geliştirilecek AR modülü, artırılmış gerçeklik
    içeriklerinin görüntülenmesini sağlayan yazılım altyapısını kapsamaktadır.
- Artırılmış gerçeklik deneyimlerinde kullanılacak 3 boyutlu model, animasyon,
    video veya diğer dijital içeriklerin üretimi bu iş kapsamında değildir.
- İdare tarafından sağlanacak veya ilerleyen süreçlerde üretilecek AR içerikleri
    geliştirilecek sistem ile uyumlu şekilde entegre edilebilecektir.
- Yüklenici, AR içeriklerinin sisteme entegre edilmesine olanak sağlayacak teknik
    altyapıyı sağlayacaktır.

**6.9 AKILLI METİN TABANLI ASİSTAN (CHATBOT) MODÜLÜ
6.9.1 Genel**
6.9.1.1 Mobil uygulama içerisinde, kullanıcıların metin tabanlı olarak etkileşim
kurabileceği bir akıllı asistan (chatbot) modülü bulunacaktır.
6.9.1.2 Bu modül, kullanıcıların uygulama içerisinde yer alan içeriklere daha hızlı ve
kolay erişebilmesini sağlamak amacıyla geliştirilecektir.
6.9.1.3 Chatbot sistemi, kullanıcıdan alınan metin girdilerine uygun olarak sistemde
tanımlı içerikler üzerinden yanıt üretecektir.

**6.9.2 Veri Kaynağı ve Çalışma Prensibi**

6.9.2.1 Chatbot modülü, yalnızca uygulama veri tabanında yer alan içerikler (lokasyonlar,
etkinlikler, açıklamalar vb.) üzerinden yanıt üretecek şekilde tasarlanacaktır.
6.9.2.2 Sistem, harici genel amaçlı yapay zekâ servislerinden (örneğin açık uçlu AI
modelleri) doğrudan veri çekmeyecek şekilde kurgulanacaktır.
6.9.2.3 Kullanıcıya sunulan tüm yanıtlar, doğrulanabilir ve sistem içerisinde kayıtlı
içeriklere dayalı olacaktır.

**6.9.3 Sorgulama ve Yanıt Mekanizması**


```
6.9.3.1 Kullanıcılar, doğal dilde metin girerek şehirdeki lokasyonlar, etkinlikler ve
içerikler hakkında sorgulama yapabilecektir.
6.9.3.2 Sistem, kullanıcı sorgularını analiz ederek en uygun içerikleri listeleyebilecek veya
doğrudan ilgili içerik sayfalarına yönlendirme yapabilecektir.
6.9.3.3 Chatbot, aşağıdaki senaryoları destekleyecektir:
```
- Belirli bir kategoriye ait öneri sunma
- Konum bazlı içerik önerme
- Etkinlik sorgulama
- Lokasyon detay bilgisi sağlama
6.9.3.4 Yanıtlar, metin, liste veya yönlendirme bağlantıları şeklinde sunulabilecektir.

```
6.9.4 Yönetim Paneli Entegrasyonu
6.9.4.1 Chatbot modülünde kullanılacak içerikler, mevcut içerik yönetim sistemi ile
entegre çalışacaktır.
6.9.4.2 Yönetim paneli üzerinden içeriklerin chatbot tarafından kullanılabilirliği kontrol
edilebilecektir.
6.9.4.3 Gerekli durumlarda belirli içeriklerin chatbot yanıtlarında öncelikli olarak
gösterilmesi sağlanabilecektir.
```
```
6.9.5 Performans ve Optimizasyon
6.9.5.1 Chatbot modülü, kullanıcı sorgularına hızlı ve kesintisiz şekilde yanıt verecek
şekilde optimize edilecektir.
6.9.5.2 Sorgu işleme ve yanıt oluşturma süreçleri, kullanıcı deneyimini olumsuz
etkilemeyecek sürelerde tamamlanacaktır.
```
```
6.9.6 Güvenlik ve Veri Kontrolü
6.9.6.1 Chatbot sistemi, kullanıcıdan alınan verileri KVKK kapsamında değerlendirecek
ve gerekli güvenlik önlemlerini içerecektir.
6.9.6.2 Kullanıcıdan alınan metin verileri, yalnızca hizmet sunumu amacıyla işlenecektir.
6.9.6.3 Sistem, kullanıcıya hatalı veya doğrulanmamış bilgi sunmayacak şekilde
tasarlanacaktır.
```
```
6.9.7 Genişletilebilirlik
6.9.7.1 Chatbot modülü, ilerleyen aşamalarda gelişmiş yapay zekâ modelleri ile entegre
edilebilecek şekilde genişletilebilir bir mimaride geliştirilecektir.
6.9.7.2 Ancak temel sistem kapsamında, yanıt üretimi kurum içi veri kaynakları ile sınırlı
olacaktır.
```
## 7. PUSH BİLDİRİMLER

**7.1 Genel**

7.1.1 Mobil uygulama, kullanıcılarla anlık ve zamanında iletişim kurulabilmesi amacıyla
push bildirim altyapısını destekleyecektir.
7.1.2 Push bildirimler; bilgilendirme, yönlendirme, etkinlik duyuruları ve kampanya
bildirimleri amacıyla kullanılacaktır.
7.1.3 Bildirim altyapısı, Android ve iOS platformlarının güncel bildirim servisleri ile uyumlu
olacaktır.
**7.2 Bildirim Türleri**

7.2.1 Genel Bildirimler: Tüm kullanıcılara gönderilen bilgilendirme ve duyuru bildirimleridir.


7.2.2 Hedefli Bildirimler: Belirli kullanıcı gruplarına (dil, ilgi alanı, üyelik durumu vb.)
yönelik gönderilen bildirimlerdir.
7.2.3 Zamanlanmış Bildirimler: Belirli bir tarih ve saatte otomatik olarak gönderilecek
bildirimlerdir.
7.2.4 Lokasyon Bazlı Bildirimler: Kullanıcının belirlenen coğrafi alanlara yaklaşması veya
bu alanlara girmesi durumunda tetiklenen bildirimlerdir.

**7.3 Lokasyon Bazlı Bildirim Senaryoları**

7.3.1 Uygulama, önceden tanımlanmış lokasyonlar için bildirim senaryolarını
destekleyecektir.
7.3.2 Kullanıcı, belirli bir noktaya yaklaştığında veya belirlenen bir alan içerisine girdiğinde
otomatik bildirim alabilecektir.
7.3.3 Lokasyon bazlı bildirimler; turistik alanlar, etkinlik noktaları ve önemli şehir
lokasyonları için kullanılabilecektir.
7.3.4 Lokasyon bildirimleri, kullanıcı deneyimini olumsuz etkilemeyecek sıklıkta
planlanacaktır.
7.3.5 Aynı lokasyon bazlı bildirimlerin, belirli bir süre içerisinde aynı kullanıcıya tekrar
gönderilmesi engellenecektir.

**7.4 Kullanıcı Tercihleri**
7.4.1 Kullanıcılar, bildirim alım tercihlerine uygulama içerisinden erişebilecektir.
7.4.2 Kullanıcı, bildirim türlerini (genel, kampanya, etkinlik, lokasyon bazlı vb.) ayrı ayrı
açıp kapatabilecektir.
7.4.3 Kullanıcılar, diledikleri zaman bildirim izinlerini değiştirebilecektir.
7.4.4 Bildirim tercihleri kullanıcı bazlı olarak saklanacaktır.
7.4.5 Uygulama, koyu (dark) ve açık (light) tema seçeneklerini destekleyecek, tema tercihi
kullanıcı tarafından değiştirilebilecektir.

**7.5 Yönetim Paneli Üzerinden Bildirim Yönetimi**

7.5.1 Bildirim içerikleri yönetim paneli üzerinden oluşturulacak, düzenlenecek ve
silinebilecektir.
7.5.2 Bildirim gönderimleri manuel veya zamanlanmış olarak yapılabilecektir.
7.5.3 Bildirimlerin hangi kullanıcı gruplarına gönderileceği yönetim paneli üzerinden
tanımlanabilecektir.
7.5.4 Gönderilen bildirimlere ilişkin kayıtlar ve temel istatistikler görüntülenebilecektir.

**7.6 Performans ve Güvenlik**

7.6.1 Push bildirim sistemi, yüksek kullanıcı sayılarında dahi sorunsuz çalışacak şekilde
tasarlanacaktır.
7.6.2 Bildirim gönderim süreçlerinde kişisel verilerin güvenliği sağlanacaktır.
7.6.3 Yetkisiz bildirim gönderimini engelleyecek güvenlik önlemleri alınacaktır.

## 8. ADMİN PANEL GEREKSİNİMLERİ

**8.1 Genel**

8.1.1 Mobil uygulama içerisinde yer alan tüm içerik, fonksiyon ve sistem ayarlarının
yönetilebilmesi amacıyla web tabanlı bir yönetim (admin) paneli geliştirilecektir.
8.1.2 Yönetim paneli, yetkili personel tarafından tarayıcı üzerinden erişilebilir olacaktır.


8.1.3 Yönetim paneli arayüzü, sade, anlaşılır ve kullanıcı dostu olacak şekilde tasarlanacaktır.

**8.2 Kullanıcı ve Yetki Yönetimi**

8.2.1 Yönetim paneli, rol bazlı yetkilendirme altyapısına sahip olacaktır.
8.2.2 Farklı kullanıcı rolleri (örneğin; sistem yöneticisi, içerik editörü, kampanya yöneticisi
vb.) tanımlanabilecektir.
8.2.3 Her rol için erişilebilecek ekranlar ve yapılabilecek işlemler ayrı ayrı belirlenebilecektir.
8.2.4 Yetkisiz kullanıcıların sistem fonksiyonlarına erişimi engellenecektir.

**8.3 İçerik Yönetimi**
8.3.1 Şehir tanıtım içerikleri, etkinlikler, duyurular ve bilgilendirme metinleri yönetim paneli
üzerinden yönetilebilecektir.
8.3.2 İçerik ekleme, düzenleme, silme ve pasife alma işlemleri yapılabilecektir.
8.3.3 İçerikler, kategori ve dil bazlı olarak yönetilebilecektir.
8.3.4 İçerik değişiklikleri mobil uygulamaya eş zamanlı veya kısa süre içerisinde
yansıtılacaktır.

**8.4 Lokasyon Yönetimi**

8.4.1 Harita üzerinde gösterilecek lokasyonlar yönetim paneli üzerinden tanımlanacaktır.
8.4.2 Lokasyonlara açıklama, görsel, kategori ve ek bilgiler eklenebilecektir.
8.4.3 Lokasyon bazlı bildirim senaryoları yönetim paneli üzerinden yapılandırılabilecektir.

**8.5 Bildirim Yönetimi**

8.5.1 Push bildirim içerikleri yönetim paneli üzerinden oluşturulacaktır.
8.5.2 Bildirimler manuel veya zamanlanmış olarak gönderilebilecektir.
8.5.3 Bildirim gönderimleri hedef kitle bazlı olarak yapılabilecektir.
8.5.4 Gönderilen bildirimlere ilişkin kayıtlar saklanacaktır.

**8.6 Çoklu Dil ve İçerik Yönetimi**

8.6.1 Yönetim paneli, uygulamanın desteklediği tüm diller için içerik yönetimini
destekleyecektir.
8.6.2 Her dil için içerikler ayrı ayrı girilebilecek ve güncellenebilecektir.

**8.7 Kayıt, Loglama ve İzlenebilirlik**

8.7.1 Yönetim paneli üzerinden yapılan tüm işlemler kayıt altına alınacaktır.
8.7.2 Kullanıcı bazlı işlem geçmişi izlenebilir olacaktır.
8.7.3 Gerekli durumlarda log kayıtları İdare ile paylaşılabilecektir.

**8.8 Güvenlik**

8.8.1 Yönetim paneline erişimler güvenli iletişim protokolleri üzerinden sağlanacaktır.
8.8.2 Parola politikaları ve oturum yönetimi güvenli olacak şekilde yapılandırılacaktır.
8.8.3 Yetkisiz erişim girişimleri kayıt altına alınacaktır.

**8.9 Performans ve Sürdürülebilirlik**

8.9.1 Yönetim paneli, eş zamanlı kullanıcı erişimlerinde dahi kararlı çalışacaktır.
8.9.2 Sistem mimarisi, ileride eklenecek yeni modüller için genişletilebilir olacaktır.


8.9.3 Yönetim paneli, mobil uygulama güncellemelerinden bağımsız olarak geliştirilebilir ve
güncellenebilir olacaktır.

## 9. API VE ENTEGRASYONLAR

**9.1 Genel**
9.1.1 Mobil uygulama ve yönetim panelleri, sunucu tarafı servisleri ile güvenli ve kontrollü
bir şekilde haberleşecektir.
9.1.2 Tüm veri alışverişleri, standartlara uygun API (Uygulama Programlama Arayüzü)
yapıları üzerinden gerçekleştirilecektir.
9.1.3 API mimarisi; ölçeklenebilir, sürdürülebilir ve geliştirilebilir olacak şekilde
tasarlanacaktır.

**9.2 API Mimari Yapısı**

9.2.1 Sunucu tarafı servisler, RESTful veya eşdeğeri servis mimarisi kullanılarak
geliştirilecektir.
9.2.2 API’ler, mobil uygulama ve yönetim panellerinin tüm fonksiyonlarını destekleyecek
kapsamda olacaktır.
9.2.3 API uç noktaları (endpoint), versiyonlanabilir ve geriye dönük uyumluluğu
destekleyecek şekilde tasarlanacaktır.

**9.3 Güvenlik ve Yetkilendirme**
9.3.1 API erişimleri, yetkilendirme ve kimlik doğrulama mekanizmaları ile korunacaktır.
9.3.2 Yetkisiz erişimleri önlemek amacıyla token tabanlı veya eşdeğer güvenli erişim
yöntemleri kullanılacaktır.
9.3.3 API çağrıları sırasında iletilen veriler şifreli iletişim protokolleri üzerinden taşınacaktır.
9.3.4 Gerekli durumlarda IP kısıtlaması ve erişim loglaması uygulanabilecektir.

**9.4 Yönetim Paneli Entegrasyonları**

9.4.1 Yönetim paneli, tüm API servislerini kullanarak mobil uygulama ile senkronize
çalışacaktır.
9.4.2 Yönetim paneli üzerinden yapılan içerik ve ayar değişiklikleri API aracılığıyla mobil
uygulamaya iletilecektir.
9.4.3 Yönetim paneli ile mobil uygulama arasında tutarlı veri yapısı sağlanacaktır.

**9.5 Üçüncü Taraf Servis Entegrasyonları**

9.5.1 Harita ve konum servisleri, bildirim servisleri ve benzeri üçüncü taraf servislerle
entegrasyon sağlanabilecektir.
9.5.2 Kullanılacak üçüncü taraf servisler, güvenilirlik ve süreklilik kriterleri gözetilerek
seçilecektir.
9.5.3 Üçüncü taraf servis entegrasyonlarında kişisel veri paylaşımı KVKK hükümlerine
uygun olacaktır.

**9.6 Bildirim Servisleri Entegrasyonu**

9.6.1 Push bildirim gönderimleri, ilgili mobil platformların güncel bildirim servisleri
üzerinden gerçekleştirilecektir.


9.6.2 Bildirim servisleri, API aracılığıyla yönetim paneli ile entegre çalışacaktır.
9.6.3 Bildirim gönderim durumları ve hata bilgileri sistem üzerinden izlenebilecektir.

**9.7 Loglama ve İzleme**

9.7.1 API çağrıları, sistem güvenliği ve performans takibi amacıyla kayıt altına alınacaktır.
9.7.2 Log kayıtları, gerektiğinde denetim ve hata analizleri için kullanılacaktır.
9.7.3 Kritik API hataları için izleme ve uyarı mekanizmaları oluşturulacaktır.

**9.8 Dokümantasyon**

9.8.1 Geliştirilen tüm API’ler için güncel ve anlaşılır teknik dokümantasyon hazırlanacaktır.
9.8.2 API dokümantasyonu, uç noktalar, veri formatları ve örnek kullanımları içerecektir.
9.8.3 Dokümantasyon, İdare ile paylaşılacaktır.

## 10. GÜVENLİK VE KVKK

**10.1 Genel Güvenlik Yaklaşımı**

10.1.1 Mobil uygulama, yönetim panelleri ve sunucu altyapısı; bilgi güvenliği, veri gizliliği ve
hizmet sürekliliği esas alınarak geliştirilecektir.
10.1.2 Güvenlik önlemleri, sistem mimarisinin tüm katmanlarını (mobil uygulama, API, admin
panel, veri tabanı) kapsayacaktır.
10.1.3 Güvenli yazılım geliştirme yaşam döngüsü (Secure SDLC) prensipleri uygulanacaktır.

**10.2 Erişim ve Yetkilendirme Güvenliği**
10.2.1 Sistem bileşenlerine erişimler, kimlik doğrulama ve yetkilendirme mekanizmaları ile
sınırlandırılacaktır.
10.2.2 Yönetim paneli erişimleri rol bazlı yetkilendirme ile kontrol edilecektir.
10.2.3 Yetkisiz erişim girişimleri kayıt altına alınacak ve gerektiğinde raporlanacaktır.
10.2.4 Oturum yönetimi güvenli şekilde yapılandırılacaktır.

**10.3 Veri Güvenliği**

10.3.1 Kişisel ve sistem verileri yetkisiz erişimlere karşı korunacaktır.
10.3.2 Veri iletimi sırasında güvenli iletişim protokolleri (SSL/TLS veya eşdeğeri)
kullanılacaktır.
10.3.3 Hassas veriler mümkün olan durumlarda şifrelenmiş olarak saklanacaktır.
10.3.4 Veri bütünlüğünü bozacak işlemlere karşı gerekli teknik tedbirler alınacaktır.

**10.4 Mobil Uygulama Güvenliği**

10.4.1 Mobil uygulama, tersine mühendislik ve kötü amaçlı müdahalelere karşı teknik
önlemler içerecektir.
10.4.2 Uygulama, yetkisiz veri erişimi veya veri sızıntısına yol açabilecek zafiyetler
barındırmayacaktır.
10.4.3 Uygulama güncellemeleri, güvenlik açıklarını giderecek şekilde planlanacaktır.

**10.5 API ve Sunucu Güvenliği**

10.5.1 API erişimleri güvenli yetkilendirme mekanizmaları ile korunacaktır.
10.5.2 API çağrıları izlenecek ve anormal kullanım durumları tespit edilebilecektir.
10.5.3 Sunucu altyapısında gerekli güvenlik yapılandırmaları yapılacaktır.


**10.6 KVKK Uyumuna İlişkin Teknik Tedbirler**

10.6.1 Kişisel veriler, 6698 sayılı Kişisel Verilerin Korunması Kanunu’na uygun şekilde
işlenecektir.
10.6.2 Üyelik gerektiren alanlarda kullanıcıdan açık rıza alınmadan kişisel veri
işlenmeyecektir.
10.6.3 Kişisel verilerin hangi amaçlarla işlendiği kullanıcıya açık ve anlaşılır şekilde
bildirilecektir.
10.6.4 Kişisel verilere yalnızca yetkili personel erişebilecektir.

**10.7 Veri Saklama, Silme ve Anonimleştirme**

10.7.1 Kişisel veriler, ilgili mevzuatta belirtilen süreler boyunca saklanacaktır.
10.7.2 Saklama süresi dolan veya işleme amacı ortadan kalkan veriler silinecek, yok edilecek
veya anonim hale getirilecektir.
10.7.3 Veri silme ve anonimleştirme işlemleri kayıt altına alınacaktır.

**10.8 Denetim ve Sorumluluk**

10.8.1 İdare, güvenlik ve KVKK kapsamında gerekli gördüğü denetimleri yapma veya
yaptırma hakkına sahiptir.
10.8.2 Güvenlik ihlalleri ve KVKK’ya aykırı durumlardan doğabilecek idari ve hukuki
sorumluluklar Yükleniciye aittir.
10.8.3 Güvenlik zafiyetleri tespit edildiğinde Yüklenici tarafından gerekli düzeltmeler
gecikmeksizin yapılacaktır.

## 11. TEST VE KALİTE GÜVENCESİ

**11.1 Genel**

**11.1.1** Yüklenici, geliştirilen mobil uygulama ve yönetim panellerinin; fonksiyonel,
performans, güvenlik ve uyumluluk açısından bu teknik şartnamede belirtilen tüm
gereksinimleri sağladığını garanti etmekle yükümlüdür.

**11.1.2** Test ve kalite güvence süreçleri, yazılım geliştirme yaşam döngüsünün (SDLC) tüm

```
aşamalarını kapsayacak şekilde planlanmalı ve uygulanmalıdır.
```
**11.2 Test Türleri**

**11.2.1** Fonksiyonel Testler: Uygulamanın tüm modüllerinin, kullanıcı senaryolarına ve iş

kurallarına uygun olarak çalıştığı doğrulanır.
**11.2.2** Uyumluluk Testleri: Android ve iOS işletim sistemlerinin farklı sürümleri ile eski ve

```
yeni nesil cihazlarda uygulamanın sorunsuz çalıştığı test edilir.
```
**11.2.3** Performans Testleri: Yoğun kullanıcı, yüksek veri ve eş zamanlı işlem senaryolarında

```
sistemin yanıt süresi, stabilitesi ve kaynak kullanımı ölçülür.
```
**11.2.4** Güvenlik Testleri: Yetkisiz erişim, veri sızıntısı ve zafiyetlere karşı gerekli güvenlik

```
testleri gerçekleştirilir.
```
**11.3 Kullanıcı Kabul Testleri (UAT)
11.3.1** Geliştirme ve test süreçleri tamamlanan uygulama, İdare’nin onayına sunulur.

**11.3.2** İdare tarafından tespit edilen hata ve eksiklikler, Yüklenici tarafından ücretsiz olarak

```
giderilir.
```

**11.3.3** Kullanıcı kabul testleri başarıyla tamamlanmadan uygulama yayına alınamaz.

**11.4 Test Dokümantasyonu ve Raporlama**

**11.4.1** Yapılan tüm testler kayıt altına alınır ve test raporları İdare’ye sunulur.

**11.4.2** Kritik, orta ve düşük seviyeli hatalar sınıflandırılarak raporlanır ve çözüm süreleri

```
belirtilir.
```
## 12. UYGULAMA MAĞAZALARI VE YAYINLAMA SÜREÇLERİ

**12.1 Genel**

12.1.1 Mobil uygulama, Android ve iOS platformlarında çalışacak şekilde geliştirilerek

```
Google Play Store ve Apple App Store’da yayımlanacaktır.
```
12.1.2 Yayınlama süreçleri, ilgili uygulama mağazalarının güncel politika ve teknik

```
gereksinimlerine uygun olarak yürütülecektir.
```
12.1.3 Google Play Store ve Apple App Store geliştirici hesapları İdare tarafından temin
edilecek olup, uygulamanın yayımlanması ve güncellenmesi için gerekli yetkiler
Yükleniciye verilecektir.

12.1.4 Uygulama mağazası hesaplarının tüm hak ve yetkileri İdare’ye ait olacaktır.

12.1.5 Uygulamanın ilk yayını ve sonraki tüm güncellemeleri Yüklenici tarafından

```
gerçekleştirilecektir.
```
12.1.6 Güncellemeler, uygulama mağazalarının onay süreçleri dikkate alınarak

planlanacaktır.
12.1.7 Yayınlanan sürümlerde ortaya çıkabilecek kritik hatalar için acil güncelleme (hotfix)

```
süreçleri işletilecektir.
```
**12.2 Mağaza İçerikleri**

12.2.1 Uygulama açıklamaları, görseller, tanıtım videoları ve ekran görüntüleri Samsun

```
Büyükşehir Belediyesi kurumsal kimliğine uygun olarak hazırlanacaktır.
```
12.2.2 Uygulama mağazası içerikleri İdare onayı alınmadan yayımlanamaz.

**12.3 Versiyonlama ve Takip**

12.3.1 Uygulama sürümleri, numaralandırma ve değişiklik kayıtları (changelog) ile takip

```
edilecektir.
```
12.3.2 Her yeni sürümde yapılan değişiklikler detaylı olarak dokümante edilecektir.

**12.4 Dokümantasyon ve Eğitim Materyalleri**

12.4.1 Mobil uygulamanın Google Play Store ve Apple App Store platformlarında
yayımlanması sürecinin yürütülmesinden Yüklenici sorumludur.

12.4.2 Uygulamanın uygulama mağazalarına yüklenmesi, gerekli teknik kontrollerin yapılması

```
ve mağaza onay süreçlerinin takibi Yüklenici tarafından gerçekleştirilecektir.
```
12.4.3 Yüklenici, uygulamanın ve yönetim panellerinin kullanımı ile ilgili gerekli teknik

```
dokümantasyonları hazırlayarak İdare’ye teslim edecektir.
```
## 13. BAKIM, DESTEK VE HİZMET SEVİYESİ (SLA)

**13.1 Genel**


13.1.1 Yüklenici, mobil uygulama ve yönetim panellerinin yayına alınmasından sonra

```
belirlenen süre boyunca bakım, destek ve hizmet seviyesi (SLA) hizmetlerini sunmakla
yükümlüdür.
```
13.1.2 Bakım ve destek hizmetleri; uygulamanın kesintisiz, güvenli ve güncel şekilde

```
çalışmasını sağlamayı amaçlar.
```
13.1.3 Bu kapsamda sunulacak hizmetler, Samsun Büyükşehir Belediyesi’nin kurumsal
ihtiyaçları ve kamu hizmet sürekliliği dikkate alınarak planlanacaktır.

**13.2 Bakım Hizmetleri**

13.2.1 Periyodik Bakım: Uygulama ve altyapı bileşenleri düzenli olarak kontrol edilir, gerekli

```
optimizasyonlar yapılır.
```
13.2.2 Uyumluluk Bakımı: Android ve iOS işletim sistemlerinde meydana gelen sürüm

```
güncellemelerine uyum sağlanır.
```
13.2.3 Güvenlik Bakımı: Tespit edilen güvenlik açıkları giderilir, gerekli yamalar uygulanır.
13.2.4 Performans İyileştirmeleri: Kullanım yoğunluğuna bağlı olarak performans artırıcı

```
düzenlemeler yapılır.
```
13.3 **Destek Hizmetleri**

13.3.1 Yüklenici, İdare tarafından bildirilen hata ve talepler için destek hizmeti sağlar.

13.3.2 Destek talepleri; e-posta, destek sistemi veya İdare tarafından belirlenecek diğer

iletişim kanalları üzerinden alınır.
13.3.3 Destek hizmetleri mesai saatleri içerisinde sağlanır; kritik durumlarda acil müdahale

```
süreci işletilir.
```
**13.4 Hizmet Seviyesi (SLA)**

**13.4.1 Hatalar öncelik seviyelerine göre sınıflandırılır:**

- Kritik Hata: Uygulamanın tamamen çalışamaz durumda olması.
- Orta Seviye Hata: Temel fonksiyonların kısıtlı çalışması.
- Düşük Seviye Hata: Kullanımı doğrudan engellemeyen görsel veya küçük fonksiyonel
    hatalar.

**13.4.2 Müdahale ve Çözüm Süreleri:**

- Kritik Hatalar: En geç 4 saat içinde müdahale, 24 saat içinde çözüm.
- Orta Seviye Hatalar: En geç 1 iş günü içinde müdahale, 3 iş günü içinde çözüm.
- Düşük Seviye Hatalar: En geç 3 iş günü içinde müdahale, planlanan sürümde çözüm.

**13.5 Güncelleme ve Sürdürme**

13.5.1 Bakım süresi boyunca gerekli hata düzeltmeleri ve küçük iyileştirmeler ücretsiz olarak
yapılacaktır.

13.5.2 Yeni özellik geliştirmeleri, İdare onayı ve ek planlama kapsamında değerlendirilir.

13.5.3 Uygulama mağazası politikalarında meydana gelen değişikliklere uyum sağlanacaktır.

**13.6 Raporlama ve İletişim**


13.6.1 Bakım ve destek faaliyetleri düzenli olarak raporlanır ve İdare’ye sunulur.

13.6.2 Gerçekleştirilen işlemler, müdahale süreleri ve çözümler raporlarda açıkça belirtilir.

13.6.3 İdare ile Yüklenici arasında düzenli iletişim ve koordinasyon sağlanır.

## 14. GİZLİLİK, VERİ GÜVENLİĞİ VE KVKK UYUMU

**14 .1 Genel**
14.1.1 Bu teknik şartname kapsamında geliştirilecek mobil uygulama ve yönetim panelleri,

```
6698 sayılı Kişisel Verilerin Korunması Kanunu (KVKK) ve ilgili tüm mevzuata uygun
olarak geliştirilecektir.
```
14.1.2 Yüklenici, uygulama kapsamında elde edilen tüm verilerin gizliliğini ve güvenliğini

```
sağlamakla yükümlüdür.
```
**14 .2 Kişisel Verilerin İşlenmesi**

14.2.1 Uygulama, yalnızca hizmetin sunulması için gerekli olan kişisel verileri işleyecek
şekilde tasarlanacaktır.

14.2.2 Kampanya, puan kazanımı ve benzeri özellikler kapsamında üyelik gerektiren

```
durumlarda, kullanıcıdan açık rıza alınacaktır.
```
14.2.3 Açık rıza metinleri ve aydınlatma metinleri, İdare onayı ile uygulama içerisinde

```
sunulacaktır.
```
**14 .3 Veri Güvenliği**
14.3.1 Kişisel veriler, yetkisiz erişimlere karşı gerekli teknik ve idari tedbirler alınarak

```
korunacaktır.
```
14.3.2 Veri iletiminde güvenli iletişim protokolleri (SSL/TLS) kullanılacaktır.

14.3.3 Yetkilendirme ve erişim kontrolleri rol bazlı olarak uygulanacaktır.

**14 .4 Veri Saklama ve Silme**

14.4.1 Kişisel veriler, ilgili mevzuatta belirtilen süreler boyunca saklanacaktır.

14.4.2 Hizmet amacının ortadan kalkması veya kullanıcı talebi halinde kişisel veriler silinecek,
yok edilecek veya anonim hale getirilecektir.

14.4.3 Veri silme ve anonimleştirme süreçleri kayıt altına alınacaktır.

**14 .5 Üçüncü Taraflar ve Entegrasyonlar**

14.5.1 Uygulama kapsamında üçüncü taraf servisler kullanılması durumunda, bu servislerin

```
KVKK uyumluluğu sağlanacaktır.
```
14.5.2 Kişisel veriler, İdare onayı olmaksızın üçüncü kişilerle paylaşılamaz.

**14 .6 Denetim ve Sorumluluk**

14.6.1 İdare, KVKK kapsamında gerekli gördüğü denetimleri yapma veya yaptırma hakkına

```
sahiptir.
```
14.6.2 KVKK’ya aykırı uygulamalardan doğabilecek idari ve hukuki yaptırımlardan Yüklenici

```
sorumludur.
```
## 15. TEST, PERFORMANS VE KABUL KRİTERLERİ


**15.1 Performans Testleri**

15.1.1 Geliştirilecek mobil uygulamanın performansı, farklı kullanım senaryoları altında test
edilecektir.
15.1.2 Sistem, **en az 1.000 eşzamanlı kullanıcıyı destekleyecek şekilde** tasarlanmalı ve test
edilmelidir.
15.1.3 QR kod kullanım senaryosu kapsamında gerçekleştirilecek performans testlerinde, 500
kullanıcının aynı anda QR kod okutması durumunda sistemin ortalama yanıt süresi 2
saniyeyi aşmamalıdır.
15.1.4 Performans testleri sonucunda elde edilen ölçümler raporlanarak İdare’ye sunulacaktır.

**15.2 Ağ Performansı ve İçerik Yükleme Testleri**
15.2.1 Artırılmış gerçeklik (AR) içeriklerinin farklı internet hızlarında çalışabilirliği test
edilecektir.
15.2.2 Yapılacak testlerde **3G seviyesinde yaklaşık 5 Mbps bağlantı hızında** , AR
içeriklerinin yüklenme süresi **8 saniyeyi aşmamalıdır.**
15.2.3 Test sonuçları raporlanarak İdare’ye sunulacaktır.

**15.3 Enerji Tüketimi Testleri**
15.3.1 Mobil uygulama içerisinde yer alan AR/VR modülünün mobil cihaz kaynaklarını
verimli kullanması sağlanacaktır.
15.3.2 AR/VR modülünün **30 dakika süreyle aktif kullanımı sırasında mobil cihaz
batarya tüketiminin ortalama %15’i aşmaması hedeflenecektir.**
15.3.3 Bu testler farklı mobil cihaz modelleri üzerinde gerçekleştirilerek sonuçları
raporlanacaktır.

**15.4 Kullanıcı Kabul ve Sistem Kabul Testleri**
15.4.1 Sistem teslimi öncesinde uygulama için **Beta test, Kullanıcı Kabul Testi (User
Acceptance Test – UAT) ve Sistem Kabul Testi (System Acceptance Test – SAT)**
süreçleri gerçekleştirilecektir.
15.4.2 Bu testler kapsamında;

- Uygulama fonksiyonlarının doğruluğu
- Performans kriterleri
- Kullanıcı deneyimi
- Hata ve iyileştirme kayıtları
değerlendirilecektir.
15.4.3 Test süreçlerinde elde edilen kullanıcı geri bildirimleri ve tespit edilen hata kayıtları
dokümante edilerek İdare’ye rapor halinde sunulacaktır.
15.4.4 Test süreçlerinin tamamlanmasının ardından gerekli iyileştirmeler yapılacak ve sistem
nihai kabul sürecine hazır hale getirilecektir.


