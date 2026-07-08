// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Samsun Şehir Rehberi';

  @override
  String get navHome => 'Ana Sayfa';

  @override
  String get navMap => 'Harita';

  @override
  String get navPlaces => 'Yerler';

  @override
  String get navAnnouncements => 'Duyurular';

  @override
  String get navProfile => 'Profil';

  @override
  String get navCulture => 'Kültür';

  @override
  String get quickCampaigns => 'Kampanyalar';

  @override
  String get quickRoutes => 'Rotalar';

  @override
  String get quickFood => 'Yemekler';

  @override
  String get quickEvents => 'Etkinlikler';

  @override
  String get btnGetDirections => 'Yol Tarifi';

  @override
  String get btnShowOnMap => 'Haritada Göster';

  @override
  String get btnShare => 'Paylaş';

  @override
  String get btnSave => 'Kaydet';

  @override
  String get btnCancel => 'İptal';

  @override
  String get btnClose => 'Kapat';

  @override
  String get btnRetry => 'Tekrar Dene';

  @override
  String get btnViewAll => 'Tümünü Gör';

  @override
  String get btnApply => 'Uygula';

  @override
  String get btnClearFilters => 'Filtreleri Temizle';

  @override
  String get btnLogout => 'Çıkış Yap';

  @override
  String get btnLogin => 'Giriş Yap';

  @override
  String get lblSearch => 'Ara';

  @override
  String get lblSearchPlaceholder => 'Ara...';

  @override
  String get lblSearchPlaces => 'Yer ara...';

  @override
  String get lblSearchEvents => 'Etkinlik ara...';

  @override
  String get lblDistance => 'Mesafe';

  @override
  String lblDistanceKm(String distance) {
    return '$distance km';
  }

  @override
  String get lblAll => 'Tümü';

  @override
  String get lblFilter => 'Filtrele';

  @override
  String get lblSort => 'Sırala';

  @override
  String get lblDate => 'Tarih';

  @override
  String get lblTime => 'Saat';

  @override
  String get lblPrice => 'Fiyat';

  @override
  String get lblFree => 'Ücretsiz';

  @override
  String get lblPaid => 'Ücretli';

  @override
  String get lblCategory => 'Kategori';

  @override
  String get lblLanguage => 'Dil';

  @override
  String get lblSettings => 'Ayarlar';

  @override
  String get lblTheme => 'Tema';

  @override
  String get lblLightMode => 'Aydınlık Mod';

  @override
  String get lblDarkMode => 'Karanlık Mod';

  @override
  String get lblSystemDefault => 'Sistem Varsayılanı';

  @override
  String get lblNotifications => 'Bildirim Ayarları';

  @override
  String get lblPrivacy => 'Gizlilik';

  @override
  String get lblHelp => 'Yardım ve Destek';

  @override
  String get lblPoints => 'Puan';

  @override
  String get lblLevel => 'Seviye';

  @override
  String get lblVisits => 'Ziyaret';

  @override
  String get lblRoutesDone => 'Rota';

  @override
  String lblMemberSince(String date) {
    return 'Üyelik: $date';
  }

  @override
  String get sectionFeaturedPlaces => 'Öne Çıkan Mekanlar';

  @override
  String get sectionNearbyPlaces => 'Yakındaki Yerler';

  @override
  String get sectionUpcomingEvents => 'Yaklaşan Etkinlikler';

  @override
  String get sectionAnnouncements => 'Duyurular';

  @override
  String get sectionTravelRoutes => 'Gezi Rotaları';

  @override
  String get sectionRecipes => 'Tarifler';

  @override
  String get sectionLocalDelicacies => 'Yöresel Lezzetler';

  @override
  String get sectionActiveCampaigns => 'Aktif Kampanyalar';

  @override
  String get sectionAchievements => 'Rozetler';

  @override
  String get sectionCompletedRoutes => 'Tamamlanan Rotalar';

  @override
  String get titleEvents => 'Etkinlikler';

  @override
  String get titlePlaces => 'Yerler';

  @override
  String get titleAnnouncements => 'Duyurular';

  @override
  String get titleProfile => 'Profilim';

  @override
  String get titleMyQrCode => 'QR Kodum';

  @override
  String get titleCampaigns => 'Kampanyalar';

  @override
  String get titleRoutes => 'Gezi Rotaları';

  @override
  String get titleCulture => 'Kültür & Etkinlikler';

  @override
  String get titleRecipes => 'Tarifler';

  @override
  String get titleMap => 'Harita';

  @override
  String get heroWelcome => 'Samsun\'a Hoşgeldiniz';

  @override
  String get heroSubtitle => 'Karadeniz\'in incisi Samsun\'u keşfedin';

  @override
  String get errGenericTitle => 'Hata';

  @override
  String get errGenericMessage => 'Bir hata oluştu. Lütfen tekrar deneyin.';

  @override
  String get errNetworkTitle => 'Bağlantı Hatası';

  @override
  String get errNetworkMessage => 'İnternet bağlantınızı kontrol edin ve tekrar deneyin.';

  @override
  String get errNoResults => 'Sonuç bulunamadı';

  @override
  String get errNoEvents => 'Etkinlik bulunamadı';

  @override
  String get errNoPlaces => 'Yer bulunamadı';

  @override
  String get errLocationDisabled => 'Konum servisleri kapalı';

  @override
  String get errLocationPermissionDenied => 'Konum izni reddedildi';

  @override
  String get loadingMessage => 'Yükleniyor...';

  @override
  String get successTitle => 'Başarılı';

  @override
  String get confirmDeleteTitle => 'Silmek istediğinize emin misiniz?';

  @override
  String get confirmDeleteMessage => 'Bu işlem geri alınamaz.';

  @override
  String placesCount(int count) {
    return '$count yer';
  }

  @override
  String eventsCount(int count) {
    return '$count etkinlik';
  }

  @override
  String dateRange(String start, String end) {
    return '$start - $end';
  }

  @override
  String get btnGoBack => 'Geri Dön';

  @override
  String get btnStartRoute => 'Rotayı Başlat';

  @override
  String get btnTriedRecipe => 'Tarifi Denedim';

  @override
  String get lblAbout => 'Hakkında';

  @override
  String get lblNotes => 'Notlar';

  @override
  String get lblTags => 'Etiketler';

  @override
  String get lblContact => 'İletişim';

  @override
  String get lblOpeningHours => 'Çalışma Saatleri';

  @override
  String get lblPhotos => 'Fotoğraflar';

  @override
  String get lblVideo => 'Video';

  @override
  String get lblPhotosAndVideo => 'Fotoğraflar ve Video';

  @override
  String lblReviews(int count) {
    return '$count değerlendirme';
  }

  @override
  String get lblDistanceLabel => 'Mesafe';

  @override
  String get errPlaceNotFound => 'Mekan bulunamadı';

  @override
  String get errRouteNotFound => 'Rota bulunamadı';

  @override
  String get errRouteLoadFailed => 'Rota yüklenemedi';

  @override
  String get errRoutesLoadFailed => 'Rotalar yüklenemedi';

  @override
  String get errAnnouncementNotFound => 'Duyuru bulunamadı';

  @override
  String get errPageNotFound => 'Sayfa Bulunamadı';

  @override
  String get titleRouteAbout => 'Rota Hakkında';

  @override
  String get titleRouteFeatures => 'Rota Özellikleri';

  @override
  String get titleRouteStops => 'Rota Durakları';

  @override
  String get titleRecipeAbout => 'Tarif Hakkında';

  @override
  String get titleRecipeDetail => 'Tarif Detayı';

  @override
  String get titleDigitalId => 'Dijital Kimlik';

  @override
  String get titleQrCode => 'QR Kodum';

  @override
  String get titleLocalDelicacies => 'Yöresel Lezzetler';

  @override
  String get titlePopularPlaces => 'Popüler Mekanlar';

  @override
  String get titleCompletedRoutes => 'Tamamlanan Rotalar';

  @override
  String get lblPhotoSpots => 'Fotoğraf Noktaları';

  @override
  String get lblRestAreas => 'Mola Alanları';

  @override
  String get lblUnnamedStop => 'İsimsiz Durak';

  @override
  String get lblTotalDistance => 'Toplam Mesafe';

  @override
  String get lblEarnedPoints => 'Kazanılan Puan';

  @override
  String get lblSampleData => '* Örnek veri - Gerçek veriler API\'den gelecek';

  @override
  String get btnRegister => 'Kayıt Ol';

  @override
  String get msgLoginSuccess => 'Giriş Başarılı';

  @override
  String get msgInsufficientPoints => 'Yetersiz Puan';

  @override
  String get badgeFirstStep => 'İlk Adım';

  @override
  String get badgeNatureFriend => 'Doğa Dostu';

  @override
  String get badgeCultureAmbassador => 'Kültür Elçisi';

  @override
  String get badgeCompleteMuseums => 'Müzeleri tamamla';

  @override
  String get badgeSuperCitizen => 'Süper Vatandaş';

  @override
  String get lblParkWalk => 'Park Yürüyüşü';

  @override
  String get filterToday => 'Bugün';

  @override
  String get filterTomorrow => 'Yarın';

  @override
  String get filterThisWeekend => 'Bu Hafta Sonu';

  @override
  String get filterCustomDate => 'Tarih Seç';

  @override
  String get filterDateRange => 'Tarih Aralığı';

  @override
  String get filterPriceRange => 'Fiyat Aralığı';

  @override
  String get filterFreeOnly => 'Sadece Ücretsiz';

  @override
  String get filterPaidOnly => 'Sadece Ücretli';

  @override
  String get filterTitle => 'Filtreler';

  @override
  String get filterReset => 'Sıfırla';

  @override
  String get lblEnableLocationServices => 'Mesafeleri görmek için konum servislerini açın';

  @override
  String get lblGrantLocationPermission => 'Mesafeleri görmek için konum izni verin';

  @override
  String get btnOpenSettings => 'Ayarları Aç';

  @override
  String get btnGrantPermission => 'İzin Ver';

  @override
  String get subtitleDiscoverEvents => 'Yaklaşan etkinlikleri keşfet';
}
