import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// Application title
  ///
  /// In tr, this message translates to:
  /// **'Samsun Şehir Rehberi'**
  String get appTitle;

  /// Bottom navigation: Home
  ///
  /// In tr, this message translates to:
  /// **'Ana Sayfa'**
  String get navHome;

  /// Bottom navigation: Map
  ///
  /// In tr, this message translates to:
  /// **'Harita'**
  String get navMap;

  /// Bottom navigation: Places
  ///
  /// In tr, this message translates to:
  /// **'Yerler'**
  String get navPlaces;

  /// Bottom navigation: Announcements
  ///
  /// In tr, this message translates to:
  /// **'Duyurular'**
  String get navAnnouncements;

  /// Bottom navigation: Profile
  ///
  /// In tr, this message translates to:
  /// **'Profil'**
  String get navProfile;

  /// Bottom navigation: Culture
  ///
  /// In tr, this message translates to:
  /// **'Kültür'**
  String get navCulture;

  /// Quick access: Campaigns
  ///
  /// In tr, this message translates to:
  /// **'Kampanyalar'**
  String get quickCampaigns;

  /// Quick access: Routes
  ///
  /// In tr, this message translates to:
  /// **'Rotalar'**
  String get quickRoutes;

  /// Quick access: Food/Recipes
  ///
  /// In tr, this message translates to:
  /// **'Yemekler'**
  String get quickFood;

  /// Quick access: Events
  ///
  /// In tr, this message translates to:
  /// **'Etkinlikler'**
  String get quickEvents;

  /// Quick access: AR scanner
  ///
  /// In tr, this message translates to:
  /// **'AR Tarayıcı'**
  String get quickArScanner;

  /// Button: Get directions to a place
  ///
  /// In tr, this message translates to:
  /// **'Yol Tarifi'**
  String get btnGetDirections;

  /// Button: Show location on map
  ///
  /// In tr, this message translates to:
  /// **'Haritada Göster'**
  String get btnShowOnMap;

  /// Button: Share content
  ///
  /// In tr, this message translates to:
  /// **'Paylaş'**
  String get btnShare;

  /// Button: Save
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get btnSave;

  /// Button: Cancel action
  ///
  /// In tr, this message translates to:
  /// **'İptal'**
  String get btnCancel;

  /// Button: Close modal or dialog
  ///
  /// In tr, this message translates to:
  /// **'Kapat'**
  String get btnClose;

  /// Button: Retry failed action
  ///
  /// In tr, this message translates to:
  /// **'Tekrar Dene'**
  String get btnRetry;

  /// Button: View all items
  ///
  /// In tr, this message translates to:
  /// **'Tümünü Gör'**
  String get btnViewAll;

  /// Button: Apply filters or settings
  ///
  /// In tr, this message translates to:
  /// **'Uygula'**
  String get btnApply;

  /// Button: Clear all filters
  ///
  /// In tr, this message translates to:
  /// **'Filtreleri Temizle'**
  String get btnClearFilters;

  /// Button: Log out
  ///
  /// In tr, this message translates to:
  /// **'Çıkış Yap'**
  String get btnLogout;

  /// Button: Log in
  ///
  /// In tr, this message translates to:
  /// **'Giriş Yap'**
  String get btnLogin;

  /// Label: Search
  ///
  /// In tr, this message translates to:
  /// **'Ara'**
  String get lblSearch;

  /// Placeholder: Search input field
  ///
  /// In tr, this message translates to:
  /// **'Ara...'**
  String get lblSearchPlaceholder;

  /// Placeholder: Search places
  ///
  /// In tr, this message translates to:
  /// **'Yer ara...'**
  String get lblSearchPlaces;

  /// Placeholder: Search events
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik ara...'**
  String get lblSearchEvents;

  /// Placeholder: Search announcements
  ///
  /// In tr, this message translates to:
  /// **'Duyurularda ara...'**
  String get lblSearchAnnouncements;

  /// Placeholder: Search routes
  ///
  /// In tr, this message translates to:
  /// **'Rota ara...'**
  String get lblSearchRoutes;

  /// Placeholder: Search recipes or restaurants
  ///
  /// In tr, this message translates to:
  /// **'Tarif veya restoran ara...'**
  String get lblSearchRecipes;

  /// Label: Distance
  ///
  /// In tr, this message translates to:
  /// **'Mesafe'**
  String get lblDistance;

  /// Distance in kilometers
  ///
  /// In tr, this message translates to:
  /// **'{distance} km'**
  String lblDistanceKm(String distance);

  /// Label: All categories
  ///
  /// In tr, this message translates to:
  /// **'Tümü'**
  String get lblAll;

  /// Label: Filter
  ///
  /// In tr, this message translates to:
  /// **'Filtrele'**
  String get lblFilter;

  /// Label: Sort
  ///
  /// In tr, this message translates to:
  /// **'Sırala'**
  String get lblSort;

  /// Label: Date
  ///
  /// In tr, this message translates to:
  /// **'Tarih'**
  String get lblDate;

  /// Label: Time
  ///
  /// In tr, this message translates to:
  /// **'Saat'**
  String get lblTime;

  /// Label: Price
  ///
  /// In tr, this message translates to:
  /// **'Fiyat'**
  String get lblPrice;

  /// Label: Free event
  ///
  /// In tr, this message translates to:
  /// **'Ücretsiz'**
  String get lblFree;

  /// Label: Paid event
  ///
  /// In tr, this message translates to:
  /// **'Ücretli'**
  String get lblPaid;

  /// Label: Category
  ///
  /// In tr, this message translates to:
  /// **'Kategori'**
  String get lblCategory;

  /// Label: Language setting
  ///
  /// In tr, this message translates to:
  /// **'Dil'**
  String get lblLanguage;

  /// Label: Settings
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar'**
  String get lblSettings;

  /// Label: Theme setting
  ///
  /// In tr, this message translates to:
  /// **'Tema'**
  String get lblTheme;

  /// Label: Light theme mode
  ///
  /// In tr, this message translates to:
  /// **'Aydınlık Mod'**
  String get lblLightMode;

  /// Label: Dark theme mode
  ///
  /// In tr, this message translates to:
  /// **'Karanlık Mod'**
  String get lblDarkMode;

  /// Label: System default setting
  ///
  /// In tr, this message translates to:
  /// **'Sistem Varsayılanı'**
  String get lblSystemDefault;

  /// Label: Notification settings
  ///
  /// In tr, this message translates to:
  /// **'Bildirim Ayarları'**
  String get lblNotifications;

  /// Label: Privacy settings
  ///
  /// In tr, this message translates to:
  /// **'Gizlilik'**
  String get lblPrivacy;

  /// Label: Help and support
  ///
  /// In tr, this message translates to:
  /// **'Yardım ve Destek'**
  String get lblHelp;

  /// Label: Points
  ///
  /// In tr, this message translates to:
  /// **'Puan'**
  String get lblPoints;

  /// Label: Level
  ///
  /// In tr, this message translates to:
  /// **'Seviye'**
  String get lblLevel;

  /// Label: Visits count
  ///
  /// In tr, this message translates to:
  /// **'Ziyaret'**
  String get lblVisits;

  /// Label: Completed routes
  ///
  /// In tr, this message translates to:
  /// **'Rota'**
  String get lblRoutesDone;

  /// Label: Member since date
  ///
  /// In tr, this message translates to:
  /// **'Üyelik: {date}'**
  String lblMemberSince(String date);

  /// Section title: Featured places
  ///
  /// In tr, this message translates to:
  /// **'Öne Çıkan Mekanlar'**
  String get sectionFeaturedPlaces;

  /// Section title: Discovery routes on home (below featured places)
  ///
  /// In tr, this message translates to:
  /// **'Keşif Rotaları'**
  String get sectionDiscoveryRoutes;

  /// Section title: City guide and blog articles on home
  ///
  /// In tr, this message translates to:
  /// **'Şehir Rehberi & Blog'**
  String get sectionCityGuideBlog;

  /// Blog list screen app bar title
  ///
  /// In tr, this message translates to:
  /// **'Şehir Rehberi & Blog'**
  String get titleBlog;

  /// Blog list search field hint
  ///
  /// In tr, this message translates to:
  /// **'Yazılarda ara...'**
  String get blogSearchHint;

  /// Blog empty/error state message
  ///
  /// In tr, this message translates to:
  /// **'Henüz yazı yok.'**
  String get blogEmpty;

  /// Estimated reading time label
  ///
  /// In tr, this message translates to:
  /// **'{min} dk okuma'**
  String blogReadMinutes(int min);

  /// Section title: Nearby places
  ///
  /// In tr, this message translates to:
  /// **'Yakındaki Yerler'**
  String get sectionNearbyPlaces;

  /// Section title: Quick access shortcuts
  ///
  /// In tr, this message translates to:
  /// **'Hızlı Erişim'**
  String get sectionQuickAccess;

  /// Section title: Home content categories
  ///
  /// In tr, this message translates to:
  /// **'Kategoriler'**
  String get sectionCategories;

  /// Category: Health tourism
  ///
  /// In tr, this message translates to:
  /// **'Sağlık Turizmi'**
  String get categoryHealthTourism;

  /// Category: Discover Samsun
  ///
  /// In tr, this message translates to:
  /// **'Samsun\'u Keşfet'**
  String get categoryDiscoverSamsun;

  /// Category: Gastronomy
  ///
  /// In tr, this message translates to:
  /// **'Gastronomi'**
  String get categoryGastronomy;

  /// Category: Historical places and museums
  ///
  /// In tr, this message translates to:
  /// **'Tarihi Yer ve Müzeler'**
  String get categoryHistoricalMuseums;

  /// Home category: Nature and parks
  ///
  /// In tr, this message translates to:
  /// **'Doğa ve Parklar'**
  String get categoryNatureParks;

  /// Home category: Beaches
  ///
  /// In tr, this message translates to:
  /// **'Plajlar'**
  String get categoryBeaches;

  /// Places screen: health tourism category chip/badge label
  ///
  /// In tr, this message translates to:
  /// **'Sağlık Turizmi'**
  String get placesCategoryHealthTourismLabel;

  /// Places screen: Discover Samsun category chip/badge label
  ///
  /// In tr, this message translates to:
  /// **'Samsun\'u Keşfet'**
  String get placesCategoryDiscoverSamsunLabel;

  /// Places screen: Gastronomy category chip/badge label
  ///
  /// In tr, this message translates to:
  /// **'Gastronomi'**
  String get placesCategoryGastronomyLabel;

  /// Places screen: Historical sites & museums chip/badge label
  ///
  /// In tr, this message translates to:
  /// **'Tarihi Yer ve Müzeler'**
  String get placesCategoryHistoricalMuseumsLabel;

  /// Places screen: Nature & parks chip/badge label
  ///
  /// In tr, this message translates to:
  /// **'Doğa ve Parklar'**
  String get placesCategoryNatureParksLabel;

  /// Places screen: Beaches chip/badge label
  ///
  /// In tr, this message translates to:
  /// **'Plajlar'**
  String get placesCategoryBeachesLabel;

  /// Section title: Upcoming events
  ///
  /// In tr, this message translates to:
  /// **'Yaklaşan Etkinlikler'**
  String get sectionUpcomingEvents;

  /// Section title: Announcements
  ///
  /// In tr, this message translates to:
  /// **'Duyurular'**
  String get sectionAnnouncements;

  /// Section title: Travel routes
  ///
  /// In tr, this message translates to:
  /// **'Gezi Rotaları'**
  String get sectionTravelRoutes;

  /// Section title: Recipes
  ///
  /// In tr, this message translates to:
  /// **'Tarifler'**
  String get sectionRecipes;

  /// Section title: Local delicacies
  ///
  /// In tr, this message translates to:
  /// **'Yöresel Lezzetler'**
  String get sectionLocalDelicacies;

  /// Section title: Active campaigns
  ///
  /// In tr, this message translates to:
  /// **'Aktif Kampanyalar'**
  String get sectionActiveCampaigns;

  /// Section title: Achievements/Badges
  ///
  /// In tr, this message translates to:
  /// **'Rozetler'**
  String get sectionAchievements;

  /// Section title: Completed routes
  ///
  /// In tr, this message translates to:
  /// **'Tamamlanan Rotalar'**
  String get sectionCompletedRoutes;

  /// Screen title: Events
  ///
  /// In tr, this message translates to:
  /// **'Etkinlikler'**
  String get titleEvents;

  /// Screen title: Places
  ///
  /// In tr, this message translates to:
  /// **'Yerler'**
  String get titlePlaces;

  /// Screen title: Announcements
  ///
  /// In tr, this message translates to:
  /// **'Duyurular'**
  String get titleAnnouncements;

  /// Screen title: Notifications
  ///
  /// In tr, this message translates to:
  /// **'Bildirimler'**
  String get titleNotifications;

  /// Empty state on notifications screen
  ///
  /// In tr, this message translates to:
  /// **'Henüz bildirim yok'**
  String get lblNoNotifications;

  /// Empty state description on notifications screen
  ///
  /// In tr, this message translates to:
  /// **'Yeni duyurular bildirim olarak gönderildiğinde burada görünür.'**
  String get lblNoNotificationsDesc;

  /// Screen title: Profile
  ///
  /// In tr, this message translates to:
  /// **'Profilim'**
  String get titleProfile;

  /// Screen title: My QR Code
  ///
  /// In tr, this message translates to:
  /// **'QR Kodum'**
  String get titleMyQrCode;

  /// Screen title: Campaigns
  ///
  /// In tr, this message translates to:
  /// **'Kampanyalar'**
  String get titleCampaigns;

  /// Screen title: Routes
  ///
  /// In tr, this message translates to:
  /// **'Gezi Rotaları'**
  String get titleRoutes;

  /// Screen title: Culture & Events
  ///
  /// In tr, this message translates to:
  /// **'Kültür & Etkinlikler'**
  String get titleCulture;

  /// Screen title: Recipes
  ///
  /// In tr, this message translates to:
  /// **'Tarifler'**
  String get titleRecipes;

  /// Screen title: Map
  ///
  /// In tr, this message translates to:
  /// **'Harita'**
  String get titleMap;

  /// Hero section: Welcome message
  ///
  /// In tr, this message translates to:
  /// **'Samsun\'a Hoşgeldiniz'**
  String get heroWelcome;

  /// Hero section: Subtitle
  ///
  /// In tr, this message translates to:
  /// **'Karadeniz\'in incisi Samsun\'u keşfedin'**
  String get heroSubtitle;

  /// Hero search bar placeholder
  ///
  /// In tr, this message translates to:
  /// **'Nereye gitmek istersiniz?'**
  String get heroSearchHint;

  /// Hero search submit button
  ///
  /// In tr, this message translates to:
  /// **'Ara'**
  String get heroSearchAction;

  /// Error dialog: Generic title
  ///
  /// In tr, this message translates to:
  /// **'Hata'**
  String get errGenericTitle;

  /// Error dialog: Generic message
  ///
  /// In tr, this message translates to:
  /// **'Bir hata oluştu. Lütfen tekrar deneyin.'**
  String get errGenericMessage;

  /// Error dialog: Network error title
  ///
  /// In tr, this message translates to:
  /// **'Bağlantı Hatası'**
  String get errNetworkTitle;

  /// Error dialog: Network error message
  ///
  /// In tr, this message translates to:
  /// **'İnternet bağlantınızı kontrol edin ve tekrar deneyin.'**
  String get errNetworkMessage;

  /// Empty state: No search results
  ///
  /// In tr, this message translates to:
  /// **'Sonuç bulunamadı'**
  String get errNoResults;

  /// Empty state: No events
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik bulunamadı'**
  String get errNoEvents;

  /// Empty state: No places
  ///
  /// In tr, this message translates to:
  /// **'Yer bulunamadı'**
  String get errNoPlaces;

  /// Error: Location services disabled
  ///
  /// In tr, this message translates to:
  /// **'Konum servisleri kapalı'**
  String get errLocationDisabled;

  /// Error: Location permission denied
  ///
  /// In tr, this message translates to:
  /// **'Konum izni reddedildi'**
  String get errLocationPermissionDenied;

  /// Loading state message
  ///
  /// In tr, this message translates to:
  /// **'Yükleniyor...'**
  String get loadingMessage;

  /// Success dialog: Title
  ///
  /// In tr, this message translates to:
  /// **'Başarılı'**
  String get successTitle;

  /// Confirm dialog: Delete title
  ///
  /// In tr, this message translates to:
  /// **'Silmek istediğinize emin misiniz?'**
  String get confirmDeleteTitle;

  /// Confirm dialog: Delete message
  ///
  /// In tr, this message translates to:
  /// **'Bu işlem geri alınamaz.'**
  String get confirmDeleteMessage;

  /// Places count label
  ///
  /// In tr, this message translates to:
  /// **'{count} yer'**
  String placesCount(int count);

  /// Events count label
  ///
  /// In tr, this message translates to:
  /// **'{count} etkinlik'**
  String eventsCount(int count);

  /// Date range display
  ///
  /// In tr, this message translates to:
  /// **'{start} - {end}'**
  String dateRange(String start, String end);

  /// Button: Go back navigation
  ///
  /// In tr, this message translates to:
  /// **'Geri Dön'**
  String get btnGoBack;

  /// Button: Start the route
  ///
  /// In tr, this message translates to:
  /// **'Rotayı Başlat'**
  String get btnStartRoute;

  /// Button: I tried this recipe
  ///
  /// In tr, this message translates to:
  /// **'Tarifi Denedim'**
  String get btnTriedRecipe;

  /// Section: About
  ///
  /// In tr, this message translates to:
  /// **'Hakkında'**
  String get lblAbout;

  /// Section: Notes
  ///
  /// In tr, this message translates to:
  /// **'Notlar'**
  String get lblNotes;

  /// Section: Tags
  ///
  /// In tr, this message translates to:
  /// **'Etiketler'**
  String get lblTags;

  /// Section: Contact
  ///
  /// In tr, this message translates to:
  /// **'İletişim'**
  String get lblContact;

  /// Section: Opening hours
  ///
  /// In tr, this message translates to:
  /// **'Çalışma Saatleri'**
  String get lblOpeningHours;

  /// Section: Photos
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraflar'**
  String get lblPhotos;

  /// Section: Video
  ///
  /// In tr, this message translates to:
  /// **'Video'**
  String get lblVideo;

  /// Section: Photos and Video
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraflar ve Video'**
  String get lblPhotosAndVideo;

  /// Review count label
  ///
  /// In tr, this message translates to:
  /// **'{count} değerlendirme'**
  String lblReviews(int count);

  /// Label: Distance
  ///
  /// In tr, this message translates to:
  /// **'Mesafe'**
  String get lblDistanceLabel;

  /// Error: Place not found
  ///
  /// In tr, this message translates to:
  /// **'Mekan bulunamadı'**
  String get errPlaceNotFound;

  /// Error: Route not found
  ///
  /// In tr, this message translates to:
  /// **'Rota bulunamadı'**
  String get errRouteNotFound;

  /// Error: Route load failed
  ///
  /// In tr, this message translates to:
  /// **'Rota yüklenemedi'**
  String get errRouteLoadFailed;

  /// Error: Routes load failed
  ///
  /// In tr, this message translates to:
  /// **'Rotalar yüklenemedi'**
  String get errRoutesLoadFailed;

  /// Error: Announcement not found
  ///
  /// In tr, this message translates to:
  /// **'Duyuru bulunamadı'**
  String get errAnnouncementNotFound;

  /// Error: Page not found
  ///
  /// In tr, this message translates to:
  /// **'Sayfa Bulunamadı'**
  String get errPageNotFound;

  /// Title: About route
  ///
  /// In tr, this message translates to:
  /// **'Rota Hakkında'**
  String get titleRouteAbout;

  /// Title: Route features
  ///
  /// In tr, this message translates to:
  /// **'Rota Özellikleri'**
  String get titleRouteFeatures;

  /// Title: Route stops
  ///
  /// In tr, this message translates to:
  /// **'Rota Durakları'**
  String get titleRouteStops;

  /// Title: About recipe
  ///
  /// In tr, this message translates to:
  /// **'Tarif Hakkında'**
  String get titleRecipeAbout;

  /// Title: Recipe detail
  ///
  /// In tr, this message translates to:
  /// **'Tarif Detayı'**
  String get titleRecipeDetail;

  /// Title: Digital ID
  ///
  /// In tr, this message translates to:
  /// **'Dijital Kimlik'**
  String get titleDigitalId;

  /// Title: My QR Code
  ///
  /// In tr, this message translates to:
  /// **'QR Kodum'**
  String get titleQrCode;

  /// Title: Local Delicacies
  ///
  /// In tr, this message translates to:
  /// **'Yöresel Lezzetler'**
  String get titleLocalDelicacies;

  /// Title: Popular Places
  ///
  /// In tr, this message translates to:
  /// **'Popüler Mekanlar'**
  String get titlePopularPlaces;

  /// Title: Completed Routes
  ///
  /// In tr, this message translates to:
  /// **'Tamamlanan Rotalar'**
  String get titleCompletedRoutes;

  /// Label: Photo spots
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf Noktaları'**
  String get lblPhotoSpots;

  /// Label: Rest areas
  ///
  /// In tr, this message translates to:
  /// **'Mola Alanları'**
  String get lblRestAreas;

  /// Label: Unnamed stop
  ///
  /// In tr, this message translates to:
  /// **'İsimsiz Durak'**
  String get lblUnnamedStop;

  /// Label: Total distance
  ///
  /// In tr, this message translates to:
  /// **'Toplam Mesafe'**
  String get lblTotalDistance;

  /// Label: Earned points
  ///
  /// In tr, this message translates to:
  /// **'Kazanılan Puan'**
  String get lblEarnedPoints;

  /// Label: Sample data note
  ///
  /// In tr, this message translates to:
  /// **'* Örnek veri - Gerçek veriler API\'den gelecek'**
  String get lblSampleData;

  /// Button: Register
  ///
  /// In tr, this message translates to:
  /// **'Kayıt Ol'**
  String get btnRegister;

  /// Message: Login successful
  ///
  /// In tr, this message translates to:
  /// **'Giriş Başarılı'**
  String get msgLoginSuccess;

  /// Message: Insufficient points
  ///
  /// In tr, this message translates to:
  /// **'Yetersiz Puan'**
  String get msgInsufficientPoints;

  /// Dialog title: phone not registered on login
  ///
  /// In tr, this message translates to:
  /// **'Bu numara kayıtlı değil'**
  String get authPhoneNotRegisteredTitle;

  /// Dialog body: suggest registration
  ///
  /// In tr, this message translates to:
  /// **'Bu telefon numarası ile kayıtlı bir hesap yok. Devam etmek için kayıt olun.'**
  String get authPhoneNotRegisteredBody;

  /// Inline hint under login form when number unknown
  ///
  /// In tr, this message translates to:
  /// **'Bu numara sistemde kayıtlı değil.'**
  String get authPhoneNotRegisteredShort;

  /// Badge: First step
  ///
  /// In tr, this message translates to:
  /// **'İlk Adım'**
  String get badgeFirstStep;

  /// Badge: Nature friend
  ///
  /// In tr, this message translates to:
  /// **'Doğa Dostu'**
  String get badgeNatureFriend;

  /// Badge: Culture ambassador
  ///
  /// In tr, this message translates to:
  /// **'Kültür Elçisi'**
  String get badgeCultureAmbassador;

  /// Badge desc: Complete museums
  ///
  /// In tr, this message translates to:
  /// **'Müzeleri tamamla'**
  String get badgeCompleteMuseums;

  /// Badge: Super citizen
  ///
  /// In tr, this message translates to:
  /// **'Süper Vatandaş'**
  String get badgeSuperCitizen;

  /// Label: Park walk route
  ///
  /// In tr, this message translates to:
  /// **'Park Yürüyüşü'**
  String get lblParkWalk;

  /// Filter: Today
  ///
  /// In tr, this message translates to:
  /// **'Bugün'**
  String get filterToday;

  /// Filter: Tomorrow
  ///
  /// In tr, this message translates to:
  /// **'Yarın'**
  String get filterTomorrow;

  /// Filter: This weekend
  ///
  /// In tr, this message translates to:
  /// **'Bu Hafta Sonu'**
  String get filterThisWeekend;

  /// Filter: Select custom date
  ///
  /// In tr, this message translates to:
  /// **'Tarih Seç'**
  String get filterCustomDate;

  /// Filter: Date range
  ///
  /// In tr, this message translates to:
  /// **'Tarih Aralığı'**
  String get filterDateRange;

  /// Filter: Price range
  ///
  /// In tr, this message translates to:
  /// **'Fiyat Aralığı'**
  String get filterPriceRange;

  /// Filter: Free only
  ///
  /// In tr, this message translates to:
  /// **'Sadece Ücretsiz'**
  String get filterFreeOnly;

  /// Filter: Paid only
  ///
  /// In tr, this message translates to:
  /// **'Sadece Ücretli'**
  String get filterPaidOnly;

  /// Filter: Title
  ///
  /// In tr, this message translates to:
  /// **'Filtreler'**
  String get filterTitle;

  /// Filter: Reset
  ///
  /// In tr, this message translates to:
  /// **'Sıfırla'**
  String get filterReset;

  /// Label: Enable location services
  ///
  /// In tr, this message translates to:
  /// **'Mesafeleri görmek için konum servislerini açın'**
  String get lblEnableLocationServices;

  /// Label: Grant location permission
  ///
  /// In tr, this message translates to:
  /// **'Mesafeleri görmek için konum izni verin'**
  String get lblGrantLocationPermission;

  /// Button: Open settings
  ///
  /// In tr, this message translates to:
  /// **'Ayarları Aç'**
  String get btnOpenSettings;

  /// Button: Grant permission
  ///
  /// In tr, this message translates to:
  /// **'İzin Ver'**
  String get btnGrantPermission;

  /// Subtitle: Discover upcoming events
  ///
  /// In tr, this message translates to:
  /// **'Yaklaşan etkinlikleri keşfet'**
  String get subtitleDiscoverEvents;

  /// Guest: sign in to see and earn points
  ///
  /// In tr, this message translates to:
  /// **'Puan bilgilerini görmek ve kazanmak için giriş yapın'**
  String get msgPointsGuestLoginGeneric;

  /// Guest: sign in to earn N points
  ///
  /// In tr, this message translates to:
  /// **'+{points} puan kazanmak için giriş yapın'**
  String msgPointsGuestLoginWithValue(int points);

  /// No description provided for @settingsFavorites.
  ///
  /// In tr, this message translates to:
  /// **'Favorilerim'**
  String get settingsFavorites;

  /// No description provided for @settingsItineraries.
  ///
  /// In tr, this message translates to:
  /// **'Gezi Planlarım'**
  String get settingsItineraries;

  /// No description provided for @profileMyContent.
  ///
  /// In tr, this message translates to:
  /// **'İçeriklerim'**
  String get profileMyContent;

  /// No description provided for @settingsLegal.
  ///
  /// In tr, this message translates to:
  /// **'Yasal'**
  String get settingsLegal;

  /// No description provided for @settingsLegalSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Aydınlatma metni, gizlilik ve koşullar'**
  String get settingsLegalSubtitle;

  /// No description provided for @settingsAnalyticsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Anonim Kullanım İstatistikleri'**
  String get settingsAnalyticsTitle;

  /// No description provided for @settingsAnalyticsSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Uygulamanın hangi özelliklerinin daha çok kullanıldığını anlamamıza yardım eder. Kişisel veri toplanmaz.'**
  String get settingsAnalyticsSubtitle;

  /// No description provided for @languageSheetTitle.
  ///
  /// In tr, this message translates to:
  /// **'Dil / Language'**
  String get languageSheetTitle;

  /// No description provided for @notifSheetTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bildirim Ayarları'**
  String get notifSheetTitle;

  /// No description provided for @notifGeneralTitle.
  ///
  /// In tr, this message translates to:
  /// **'Genel Bildirimler'**
  String get notifGeneralTitle;

  /// No description provided for @notifGeneralSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Tüm push bildirimlerini açar/kapatır'**
  String get notifGeneralSubtitle;

  /// No description provided for @notifCampaignsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kampanya Bildirimleri'**
  String get notifCampaignsTitle;

  /// No description provided for @notifCampaignsSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Yeni kampanya ve fırsat duyuruları'**
  String get notifCampaignsSubtitle;

  /// No description provided for @notifEventsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik Bildirimleri'**
  String get notifEventsTitle;

  /// No description provided for @notifEventsSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Yaklaşan etkinlikler ve organizasyonlar'**
  String get notifEventsSubtitle;

  /// No description provided for @notifNearbyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yakınımdaki Yerler'**
  String get notifNearbyTitle;

  /// No description provided for @notifNearbySubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Önemli bölgelere yaklaştığınızda bildirim'**
  String get notifNearbySubtitle;

  /// No description provided for @geofenceActiveInfo.
  ///
  /// In tr, this message translates to:
  /// **'Kavak, Atakum gibi bölgelere girdiğinizde otomatik bildirim alacaksınız. Aynı bölge için 24 saat içinde tekrar bildirim gelmez.'**
  String get geofenceActiveInfo;

  /// No description provided for @geofenceCheckNow.
  ///
  /// In tr, this message translates to:
  /// **'Şimdi kontrol et'**
  String get geofenceCheckNow;

  /// No description provided for @lblLastCheck.
  ///
  /// In tr, this message translates to:
  /// **'Son Kontrol'**
  String get lblLastCheck;

  /// No description provided for @geoLocationServicesOff.
  ///
  /// In tr, this message translates to:
  /// **'Konum servisleri kapalı'**
  String get geoLocationServicesOff;

  /// No description provided for @geoPermissionDenied.
  ///
  /// In tr, this message translates to:
  /// **'Konum izni reddedildi'**
  String get geoPermissionDenied;

  /// No description provided for @geoPermissionDeniedForever.
  ///
  /// In tr, this message translates to:
  /// **'Konum izni kalıcı olarak reddedildi'**
  String get geoPermissionDeniedForever;

  /// No description provided for @geoLocationNotYet.
  ///
  /// In tr, this message translates to:
  /// **'Konum henüz alınamadı, tekrar denenecek'**
  String get geoLocationNotYet;

  /// No description provided for @geoServiceDisabled.
  ///
  /// In tr, this message translates to:
  /// **'Servis devre dışı'**
  String get geoServiceDisabled;

  /// No description provided for @geoInsideZone.
  ///
  /// In tr, this message translates to:
  /// **'{name} içindesiniz'**
  String geoInsideZone(String name);

  /// No description provided for @geoNoZone.
  ///
  /// In tr, this message translates to:
  /// **'Hiçbir bölge içinde değilsiniz'**
  String get geoNoZone;

  /// No description provided for @geoLocationFailedWith.
  ///
  /// In tr, this message translates to:
  /// **'Konum alınamadı: {error}'**
  String geoLocationFailedWith(String error);

  /// No description provided for @lblFollowedDistrict.
  ///
  /// In tr, this message translates to:
  /// **'Takip Edilen İlçe'**
  String get lblFollowedDistrict;

  /// No description provided for @dlgLocationPermissionTitle.
  ///
  /// In tr, this message translates to:
  /// **'Konum İzni Gerekli'**
  String get dlgLocationPermissionTitle;

  /// No description provided for @dlgLocationPermissionBody.
  ///
  /// In tr, this message translates to:
  /// **'Yakınlarınızdaki turistik yerler hakkında bildirim alabilmek için konum bilgisine erişim izni vermeniz gerekiyor.\n\nLütfen uygulama ayarlarından konum iznini etkinleştirin.'**
  String get dlgLocationPermissionBody;

  /// No description provided for @dlgNotifPermissionTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bildirim İzni Gerekli'**
  String get dlgNotifPermissionTitle;

  /// No description provided for @dlgNotifPermissionBody.
  ///
  /// In tr, this message translates to:
  /// **'Bildirimleri açabilmek için sistem ayarlarından bu uygulamaya bildirim izni vermeniz gerekiyor.\n\nLütfen uygulama ayarlarından bildirimlere izin verin.'**
  String get dlgNotifPermissionBody;

  /// No description provided for @btnOk.
  ///
  /// In tr, this message translates to:
  /// **'Tamam'**
  String get btnOk;

  /// No description provided for @btnGoToSettings.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlara Git'**
  String get btnGoToSettings;

  /// No description provided for @btnGiveUp.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get btnGiveUp;

  /// No description provided for @btnContinue.
  ///
  /// In tr, this message translates to:
  /// **'Devam Et'**
  String get btnContinue;

  /// No description provided for @btnDeleteAccount.
  ///
  /// In tr, this message translates to:
  /// **'Hesabımı Sil'**
  String get btnDeleteAccount;

  /// No description provided for @deleteAccountWarnTitle.
  ///
  /// In tr, this message translates to:
  /// **'Hesabını silmek üzeresin'**
  String get deleteAccountWarnTitle;

  /// No description provided for @deleteAccountIfYouDelete.
  ///
  /// In tr, this message translates to:
  /// **'Hesabını silersen:'**
  String get deleteAccountIfYouDelete;

  /// No description provided for @deleteAccountBulletProfile.
  ///
  /// In tr, this message translates to:
  /// **'Profil bilgilerin silinir'**
  String get deleteAccountBulletProfile;

  /// No description provided for @deleteAccountBulletFavorites.
  ///
  /// In tr, this message translates to:
  /// **'Favorilerin ve gezi planların kaybolur'**
  String get deleteAccountBulletFavorites;

  /// No description provided for @deleteAccountBulletHistory.
  ///
  /// In tr, this message translates to:
  /// **'Ziyaret geçmişin anonimleştirilir'**
  String get deleteAccountBulletHistory;

  /// No description provided for @deleteAccountBulletNotifications.
  ///
  /// In tr, this message translates to:
  /// **'Bildirim aboneliklerin kaldırılır'**
  String get deleteAccountBulletNotifications;

  /// No description provided for @deleteAccountReSignupNote.
  ///
  /// In tr, this message translates to:
  /// **'Aynı telefon numarasıyla yeniden üye olabilirsin, ancak silinen veriler geri getirilemez.'**
  String get deleteAccountReSignupNote;

  /// No description provided for @lblReasonOptional.
  ///
  /// In tr, this message translates to:
  /// **'Sebep (opsiyonel)'**
  String get lblReasonOptional;

  /// No description provided for @deleteAccountFinalTitle.
  ///
  /// In tr, this message translates to:
  /// **'Son Onay'**
  String get deleteAccountFinalTitle;

  /// No description provided for @deleteAccountConfirmWord.
  ///
  /// In tr, this message translates to:
  /// **'HESABIMI SİL'**
  String get deleteAccountConfirmWord;

  /// No description provided for @deleteAccountConfirmPrompt.
  ///
  /// In tr, this message translates to:
  /// **'Bu işlem GERİ ALINAMAZ. Onaylamak için aşağıdaki kutuya \"{word}\" yaz:'**
  String deleteAccountConfirmPrompt(String word);

  /// No description provided for @deleteAccountDoneTitle.
  ///
  /// In tr, this message translates to:
  /// **'Hesabın silindi'**
  String get deleteAccountDoneTitle;

  /// No description provided for @deleteAccountDaysRemaining.
  ///
  /// In tr, this message translates to:
  /// **'Hesabın {days} gün içinde kalıcı olarak silinecek. Bu süre içinde aynı numarayla tekrar giriş yaparsan hesabını geri alabilirsin.'**
  String deleteAccountDaysRemaining(int days);

  /// No description provided for @deleteAccountMarkedGeneric.
  ///
  /// In tr, this message translates to:
  /// **'Hesabın silinmek üzere işaretlendi. Görüşmek üzere.'**
  String get deleteAccountMarkedGeneric;

  /// No description provided for @deleteAccountFailed.
  ///
  /// In tr, this message translates to:
  /// **'Hesabın şu an silinemedi. Bağlantını kontrol edip tekrar dene.'**
  String get deleteAccountFailed;

  /// No description provided for @deleteReasonNotUsing.
  ///
  /// In tr, this message translates to:
  /// **'Artık kullanmıyorum'**
  String get deleteReasonNotUsing;

  /// No description provided for @deleteReasonMissingFeatures.
  ///
  /// In tr, this message translates to:
  /// **'Beklediğim özellikleri bulamadım'**
  String get deleteReasonMissingFeatures;

  /// No description provided for @deleteReasonPrivacy.
  ///
  /// In tr, this message translates to:
  /// **'Gizlilik / veri kaygısı'**
  String get deleteReasonPrivacy;

  /// No description provided for @deleteReasonTooManyNotifs.
  ///
  /// In tr, this message translates to:
  /// **'Bildirim çok geliyor'**
  String get deleteReasonTooManyNotifs;

  /// No description provided for @deleteReasonSwitchedApp.
  ///
  /// In tr, this message translates to:
  /// **'Başka bir uygulamaya geçtim'**
  String get deleteReasonSwitchedApp;

  /// No description provided for @deleteReasonPreferNotSay.
  ///
  /// In tr, this message translates to:
  /// **'Belirtmek istemiyorum'**
  String get deleteReasonPreferNotSay;

  /// No description provided for @btnExplore.
  ///
  /// In tr, this message translates to:
  /// **'Keşfet'**
  String get btnExplore;

  /// No description provided for @btnLater.
  ///
  /// In tr, this message translates to:
  /// **'Sonra'**
  String get btnLater;

  /// No description provided for @geofenceToggleTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yakınımdaki Yerler'**
  String get geofenceToggleTitle;

  /// No description provided for @geofenceToggleSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Bölgelere girdiğinizde bildirim alın'**
  String get geofenceToggleSubtitle;

  /// No description provided for @notifPushTitle.
  ///
  /// In tr, this message translates to:
  /// **'Push Bildirimleri'**
  String get notifPushTitle;

  /// No description provided for @notifPushSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Duyuru ve kampanya bildirimleri'**
  String get notifPushSubtitle;

  /// No description provided for @notifSubtitlePushAndNearby.
  ///
  /// In tr, this message translates to:
  /// **'Push ve yakınındaki yerler açık'**
  String get notifSubtitlePushAndNearby;

  /// No description provided for @notifSubtitlePushOnly.
  ///
  /// In tr, this message translates to:
  /// **'Push bildirimleri açık'**
  String get notifSubtitlePushOnly;

  /// No description provided for @notifSubtitleNearbyOnly.
  ///
  /// In tr, this message translates to:
  /// **'Yakınımdaki yerler açık'**
  String get notifSubtitleNearbyOnly;

  /// No description provided for @notifSubtitleOff.
  ///
  /// In tr, this message translates to:
  /// **'Bildirimler kapalı'**
  String get notifSubtitleOff;

  /// Tooltip: mute push notifications from announcements screen
  ///
  /// In tr, this message translates to:
  /// **'Bildirimleri sessize al'**
  String get announcementsMuteTooltip;

  /// Tooltip: unmute push notifications from announcements screen
  ///
  /// In tr, this message translates to:
  /// **'Bildirimleri aç'**
  String get announcementsUnmuteTooltip;

  /// Snackbar shown after muting notifications
  ///
  /// In tr, this message translates to:
  /// **'Bildirimler sessize alındı. Önemli duyuruları kaçırabilirsiniz.'**
  String get announcementsMutedSnack;

  /// Snackbar shown after unmuting notifications
  ///
  /// In tr, this message translates to:
  /// **'Bildirimler açıldı'**
  String get announcementsUnmutedSnack;

  /// Generic undo action label (e.g. in snackbars)
  ///
  /// In tr, this message translates to:
  /// **'Geri Al'**
  String get btnUndo;

  /// No description provided for @profileRegisteredUser.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlı Kullanıcı'**
  String get profileRegisteredUser;

  /// No description provided for @staffLoginPrompt.
  ///
  /// In tr, this message translates to:
  /// **'Kasa işlemleri için personel girişi.'**
  String get staffLoginPrompt;

  /// No description provided for @staffLoginTitle.
  ///
  /// In tr, this message translates to:
  /// **'Personel Girişi'**
  String get staffLoginTitle;

  /// No description provided for @staffPanelTitle.
  ///
  /// In tr, this message translates to:
  /// **'Personel Paneli'**
  String get staffPanelTitle;

  /// No description provided for @posCashier.
  ///
  /// In tr, this message translates to:
  /// **'Kasa'**
  String get posCashier;

  /// No description provided for @staffSwitchFacility.
  ///
  /// In tr, this message translates to:
  /// **'Tesis değiştir'**
  String get staffSwitchFacility;

  /// No description provided for @staffEnterCode.
  ///
  /// In tr, this message translates to:
  /// **'Kod Gir'**
  String get staffEnterCode;

  /// No description provided for @staffEnterCodeHint.
  ///
  /// In tr, this message translates to:
  /// **'Müşterinin ekranındaki 6 haneli kodu girin'**
  String get staffEnterCodeHint;

  /// No description provided for @btnVerify.
  ///
  /// In tr, this message translates to:
  /// **'Doğrula'**
  String get btnVerify;

  /// No description provided for @staffEditTotal.
  ///
  /// In tr, this message translates to:
  /// **'Toplam Tutarı Düzenle'**
  String get staffEditTotal;

  /// No description provided for @staffTotalPoints.
  ///
  /// In tr, this message translates to:
  /// **'Toplam Puan'**
  String get staffTotalPoints;

  /// No description provided for @staffProfileTitle.
  ///
  /// In tr, this message translates to:
  /// **'Personel Profili'**
  String get staffProfileTitle;

  /// No description provided for @staffLogout.
  ///
  /// In tr, this message translates to:
  /// **'Çıkış'**
  String get staffLogout;

  /// No description provided for @staffTotalTransactions.
  ///
  /// In tr, this message translates to:
  /// **'Toplam İşlem'**
  String get staffTotalTransactions;

  /// No description provided for @staffProcessedPoints.
  ///
  /// In tr, this message translates to:
  /// **'İşlenen Puan'**
  String get staffProcessedPoints;

  /// No description provided for @staffPaymentApproval.
  ///
  /// In tr, this message translates to:
  /// **'Ödeme Onayı'**
  String get staffPaymentApproval;

  /// No description provided for @posPriceTimesQty.
  ///
  /// In tr, this message translates to:
  /// **'{price} puan × {qty}'**
  String posPriceTimesQty(int price, int qty);

  /// No description provided for @staffExtraFee.
  ///
  /// In tr, this message translates to:
  /// **'Ek ücret'**
  String get staffExtraFee;

  /// No description provided for @staffManualAmount.
  ///
  /// In tr, this message translates to:
  /// **'Manuel Tutar'**
  String get staffManualAmount;

  /// No description provided for @staffTransactions.
  ///
  /// In tr, this message translates to:
  /// **'İşlemler'**
  String get staffTransactions;

  /// No description provided for @staffScan.
  ///
  /// In tr, this message translates to:
  /// **'Tara'**
  String get staffScan;

  /// No description provided for @staffSelectFacility.
  ///
  /// In tr, this message translates to:
  /// **'Tesis seçin'**
  String get staffSelectFacility;

  /// No description provided for @arViewDetail.
  ///
  /// In tr, this message translates to:
  /// **'Detay gör'**
  String get arViewDetail;

  /// No description provided for @arAddToPlan.
  ///
  /// In tr, this message translates to:
  /// **'Plana ekle'**
  String get arAddToPlan;

  /// No description provided for @arHttpsRequired.
  ///
  /// In tr, this message translates to:
  /// **'AR için HTTPS gerekli'**
  String get arHttpsRequired;

  /// No description provided for @arCardViewCamera.
  ///
  /// In tr, this message translates to:
  /// **'Kart Görünümü (Kamera)'**
  String get arCardViewCamera;

  /// No description provided for @arRadarView.
  ///
  /// In tr, this message translates to:
  /// **'Radar Görünümü'**
  String get arRadarView;

  /// No description provided for @arBackToRadar.
  ///
  /// In tr, this message translates to:
  /// **'Radar görünümüne dön'**
  String get arBackToRadar;

  /// No description provided for @arContinueCardView.
  ///
  /// In tr, this message translates to:
  /// **'Kart Görünümü ile Devam Et'**
  String get arContinueCardView;

  /// No description provided for @arSceneTitle.
  ///
  /// In tr, this message translates to:
  /// **'AR Sahnesi'**
  String get arSceneTitle;

  /// No description provided for @arAligned.
  ///
  /// In tr, this message translates to:
  /// **'Hizalı'**
  String get arAligned;

  /// No description provided for @arActiveCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} aktif'**
  String arActiveCount(int count);

  /// No description provided for @arPreviewModeBanner.
  ///
  /// In tr, this message translates to:
  /// **'Önizleme modu — yayında olmayan noktalar gösteriliyor.'**
  String get arPreviewModeBanner;

  /// No description provided for @arCompassCalibrationBanner.
  ///
  /// In tr, this message translates to:
  /// **'Pusula kalibre değil. Telefonu sekiz şeklinde hareket ettirin.'**
  String get arCompassCalibrationBanner;

  /// No description provided for @arGpsAccuracyBanner.
  ///
  /// In tr, this message translates to:
  /// **'GPS doğruluğu düşük ({accuracy} m).'**
  String arGpsAccuracyBanner(String accuracy);

  /// No description provided for @arCloseModel.
  ///
  /// In tr, this message translates to:
  /// **'Modeli kapat'**
  String get arCloseModel;

  /// No description provided for @arModelLoading.
  ///
  /// In tr, this message translates to:
  /// **'Model yükleniyor…'**
  String get arModelLoading;

  /// No description provided for @arCameraInitFailed.
  ///
  /// In tr, this message translates to:
  /// **'Kamera başlatılamadı. Cihaz desteğini ve izinleri kontrol edin.'**
  String get arCameraInitFailed;

  /// No description provided for @loginScreenTitle.
  ///
  /// In tr, this message translates to:
  /// **'Hesabınıza Giriş Yapın'**
  String get loginScreenTitle;

  /// No description provided for @loginScreenSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Tüm özelliklere erişmek için giriş yapın'**
  String get loginScreenSubtitle;

  /// No description provided for @qrWaitingConnection.
  ///
  /// In tr, this message translates to:
  /// **'İnternet bağlantısı bekleniyor...'**
  String get qrWaitingConnection;

  /// No description provided for @qrPaymentComplete.
  ///
  /// In tr, this message translates to:
  /// **'Ödeme Tamamlandı!'**
  String get qrPaymentComplete;

  /// No description provided for @qrSpendPrompt.
  ///
  /// In tr, this message translates to:
  /// **'Puan harcamak için kasada personelin okutmasına izin verin'**
  String get qrSpendPrompt;

  /// No description provided for @qrNoCode.
  ///
  /// In tr, this message translates to:
  /// **'Şu anda gösterilecek QR kodu yok.'**
  String get qrNoCode;

  /// No description provided for @qrRefreshing.
  ///
  /// In tr, this message translates to:
  /// **'QR yenileniyor...'**
  String get qrRefreshing;

  /// No description provided for @authWelcome.
  ///
  /// In tr, this message translates to:
  /// **'Hoş Geldiniz'**
  String get authWelcome;

  /// No description provided for @authLoginSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Samsun Büyükşehir Belediyesi cüzdanınıza güvenle giriş yapın.'**
  String get authLoginSubtitle;

  /// No description provided for @lblPhoneNumber.
  ///
  /// In tr, this message translates to:
  /// **'Telefon Numarası'**
  String get lblPhoneNumber;

  /// No description provided for @valPhoneRequired.
  ///
  /// In tr, this message translates to:
  /// **'Lütfen telefon numaranızı girin'**
  String get valPhoneRequired;

  /// No description provided for @valPhoneInvalid.
  ///
  /// In tr, this message translates to:
  /// **'Lütfen geçerli bir telefon numarası girin'**
  String get valPhoneInvalid;

  /// No description provided for @authOtpSendInfo.
  ///
  /// In tr, this message translates to:
  /// **'Numaranızı doğrulamak için tek kullanımlık bir SMS kodu göndereceğiz.'**
  String get authOtpSendInfo;

  /// No description provided for @otpAppBarTitle.
  ///
  /// In tr, this message translates to:
  /// **'Doğrulama Kodu'**
  String get otpAppBarTitle;

  /// No description provided for @otpVerifyPhoneTitle.
  ///
  /// In tr, this message translates to:
  /// **'Telefonunu Doğrula'**
  String get otpVerifyPhoneTitle;

  /// No description provided for @otpSentToLabel.
  ///
  /// In tr, this message translates to:
  /// **'Doğrulama kodu şu numaraya gönderildi:'**
  String get otpSentToLabel;

  /// No description provided for @lblRemainingTime.
  ///
  /// In tr, this message translates to:
  /// **'Kalan süre'**
  String get lblRemainingTime;

  /// No description provided for @btnResendCode.
  ///
  /// In tr, this message translates to:
  /// **'Kodu Tekrar Gönder'**
  String get btnResendCode;

  /// No description provided for @otpPendingDeletionTitle.
  ///
  /// In tr, this message translates to:
  /// **'Hesabınız silinmek üzere'**
  String get otpPendingDeletionTitle;

  /// No description provided for @otpPendingDeletionBody.
  ///
  /// In tr, this message translates to:
  /// **'Bu hesap için silme talebi alınmış. Kalıcı olarak silinmesine {days} gün kaldı.\n\nHesabınızı geri yüklemek ister misiniz? \"Vazgeç\" derseniz silme süreci devam eder.'**
  String otpPendingDeletionBody(int days);

  /// No description provided for @btnRestoreAccount.
  ///
  /// In tr, this message translates to:
  /// **'Hesabımı Geri Yükle'**
  String get btnRestoreAccount;

  /// No description provided for @accountRestoredMsg.
  ///
  /// In tr, this message translates to:
  /// **'Hesabınız geri yüklendi. Hoş geldiniz!'**
  String get accountRestoredMsg;

  /// No description provided for @otpAccountDeletedTitle.
  ///
  /// In tr, this message translates to:
  /// **'Hesap silinmiş'**
  String get otpAccountDeletedTitle;

  /// No description provided for @otpAccountDeletedBody.
  ///
  /// In tr, this message translates to:
  /// **'Bu telefon numarasına ait hesap kalıcı olarak silinmiş. Devam etmek için yeni bir hesap oluşturmanız gerekir.'**
  String get otpAccountDeletedBody;

  /// No description provided for @btnCreateNewAccount.
  ///
  /// In tr, this message translates to:
  /// **'Yeni Hesap Oluştur'**
  String get btnCreateNewAccount;

  /// No description provided for @registerSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Cüzdanınızı oluşturmak için bilgilerinizi doldurun.'**
  String get registerSubtitle;

  /// No description provided for @lblFirstName.
  ///
  /// In tr, this message translates to:
  /// **'Adınız'**
  String get lblFirstName;

  /// No description provided for @valFirstNameRequired.
  ///
  /// In tr, this message translates to:
  /// **'Lütfen adınızı girin'**
  String get valFirstNameRequired;

  /// No description provided for @lblLastName.
  ///
  /// In tr, this message translates to:
  /// **'Soyadınız'**
  String get lblLastName;

  /// No description provided for @valLastNameRequired.
  ///
  /// In tr, this message translates to:
  /// **'Lütfen soyadınızı girin'**
  String get valLastNameRequired;

  /// No description provided for @valEmailRequired.
  ///
  /// In tr, this message translates to:
  /// **'Lütfen e-posta adresinizi girin'**
  String get valEmailRequired;

  /// No description provided for @valEmailInvalid.
  ///
  /// In tr, this message translates to:
  /// **'Lütfen geçerli bir e-posta adresi girin'**
  String get valEmailInvalid;

  /// No description provided for @legalClarificationText.
  ///
  /// In tr, this message translates to:
  /// **'Aydınlatma Metni'**
  String get legalClarificationText;

  /// No description provided for @legalTermsOfUse.
  ///
  /// In tr, this message translates to:
  /// **'Kullanım Koşulları'**
  String get legalTermsOfUse;

  /// No description provided for @lblEmail.
  ///
  /// In tr, this message translates to:
  /// **'E-posta'**
  String get lblEmail;

  /// No description provided for @registerConsentPrefix.
  ///
  /// In tr, this message translates to:
  /// **''**
  String get registerConsentPrefix;

  /// No description provided for @registerConsentMid.
  ///
  /// In tr, this message translates to:
  /// **'\'ni okudum; '**
  String get registerConsentMid;

  /// No description provided for @registerConsentSuffix.
  ///
  /// In tr, this message translates to:
  /// **'\'nı kabul ediyor ve kişisel verilerimin işlenmesine açık rıza veriyorum.'**
  String get registerConsentSuffix;

  /// No description provided for @favRecordCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} kayıt'**
  String favRecordCount(int count);

  /// No description provided for @favEmptyPlaces.
  ///
  /// In tr, this message translates to:
  /// **'Henüz favori mekanınız yok'**
  String get favEmptyPlaces;

  /// No description provided for @favEmptyRecipes.
  ///
  /// In tr, this message translates to:
  /// **'Henüz favori tarifiniz yok'**
  String get favEmptyRecipes;

  /// No description provided for @favEmptyRoutes.
  ///
  /// In tr, this message translates to:
  /// **'Henüz favori rotanız yok'**
  String get favEmptyRoutes;

  /// No description provided for @favEmptyDelicacies.
  ///
  /// In tr, this message translates to:
  /// **'Henüz favori lezzetiniz yok'**
  String get favEmptyDelicacies;

  /// No description provided for @favRemove.
  ///
  /// In tr, this message translates to:
  /// **'Favorilerden kaldır'**
  String get favRemove;

  /// No description provided for @favHint.
  ///
  /// In tr, this message translates to:
  /// **'İçeriklerin yanındaki kalp simgesine dokunarak favorilerinize ekleyebilirsiniz.'**
  String get favHint;

  /// No description provided for @itineraryDeleteTitle.
  ///
  /// In tr, this message translates to:
  /// **'Plan silinsin mi?'**
  String get itineraryDeleteTitle;

  /// No description provided for @btnDelete.
  ///
  /// In tr, this message translates to:
  /// **'Sil'**
  String get btnDelete;

  /// No description provided for @itineraryDeleteConfirm.
  ///
  /// In tr, this message translates to:
  /// **'\"{title}\" planı kalıcı olarak silinecek.'**
  String itineraryDeleteConfirm(String title);

  /// No description provided for @itineraryEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz gezi planınız yok'**
  String get itineraryEmpty;

  /// No description provided for @itineraryEmptyHint.
  ///
  /// In tr, this message translates to:
  /// **'Aşağıdaki \"Yeni Plan\" butonuyla rotanızı oluşturun, dilediğiniz mekan ve etkinlikleri ekleyin.'**
  String get itineraryEmptyHint;

  /// No description provided for @sortRecommended.
  ///
  /// In tr, this message translates to:
  /// **'Önerilen'**
  String get sortRecommended;

  /// No description provided for @sortByName.
  ///
  /// In tr, this message translates to:
  /// **'İsme göre (A-Z)'**
  String get sortByName;

  /// No description provided for @sortPopularity.
  ///
  /// In tr, this message translates to:
  /// **'Popülerlik'**
  String get sortPopularity;

  /// No description provided for @sortProximity.
  ///
  /// In tr, this message translates to:
  /// **'Yakınlık'**
  String get sortProximity;

  /// No description provided for @sortDuration.
  ///
  /// In tr, this message translates to:
  /// **'Süre'**
  String get sortDuration;

  /// No description provided for @sortStopCount.
  ///
  /// In tr, this message translates to:
  /// **'Durak sayısı'**
  String get sortStopCount;

  /// No description provided for @sortRating.
  ///
  /// In tr, this message translates to:
  /// **'Puan'**
  String get sortRating;

  /// No description provided for @sortByDate.
  ///
  /// In tr, this message translates to:
  /// **'Tarihe göre'**
  String get sortByDate;

  /// No description provided for @routeModeWalking.
  ///
  /// In tr, this message translates to:
  /// **'Yürüyüş'**
  String get routeModeWalking;

  /// No description provided for @routeModeBike.
  ///
  /// In tr, this message translates to:
  /// **'Bisiklet'**
  String get routeModeBike;

  /// No description provided for @routeModeCar.
  ///
  /// In tr, this message translates to:
  /// **'Araç ile'**
  String get routeModeCar;

  /// No description provided for @routeDiffEasy.
  ///
  /// In tr, this message translates to:
  /// **'Kolay'**
  String get routeDiffEasy;

  /// No description provided for @routeDiffMedium.
  ///
  /// In tr, this message translates to:
  /// **'Orta'**
  String get routeDiffMedium;

  /// No description provided for @routeDiffHard.
  ///
  /// In tr, this message translates to:
  /// **'Zor'**
  String get routeDiffHard;

  /// No description provided for @routeLabelDefault.
  ///
  /// In tr, this message translates to:
  /// **'Rota'**
  String get routeLabelDefault;

  /// No description provided for @permLocationTitle.
  ///
  /// In tr, this message translates to:
  /// **'Konum İzni'**
  String get permLocationTitle;

  /// No description provided for @permLocationDesc.
  ///
  /// In tr, this message translates to:
  /// **'Size en yakın yerleri, etkinlikleri ve harita yönlendirmesini gösterebilmek için konumunuza erişmek istiyoruz.'**
  String get permLocationDesc;

  /// No description provided for @permLocationBullet1.
  ///
  /// In tr, this message translates to:
  /// **'Yakınınızdaki turistik ve kültürel noktalar listelenir.'**
  String get permLocationBullet1;

  /// No description provided for @permLocationBullet2.
  ///
  /// In tr, this message translates to:
  /// **'Haritada konumunuz ve yol tarifi gösterilir.'**
  String get permLocationBullet2;

  /// No description provided for @permLocationBullet3.
  ///
  /// In tr, this message translates to:
  /// **'Konumunuz yalnızca hizmet için kullanılır, paylaşılmaz.'**
  String get permLocationBullet3;

  /// No description provided for @permLocationBgTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yakındaki Yer Bildirimleri'**
  String get permLocationBgTitle;

  /// No description provided for @permLocationBgDesc.
  ///
  /// In tr, this message translates to:
  /// **'Önemli bölgelere yaklaştığınızda (telefon cebinizdeyken bile) sizi bilgilendirebilmek için arka plan konum erişimi gerekir. Açılan izin ekranında lütfen \"Her zaman izin ver\" seçeneğini seçin.'**
  String get permLocationBgDesc;

  /// No description provided for @permLocationBgBullet1.
  ///
  /// In tr, this message translates to:
  /// **'Turistik noktalara yaklaşınca bildirim alırsınız.'**
  String get permLocationBgBullet1;

  /// No description provided for @permLocationBgBullet2.
  ///
  /// In tr, this message translates to:
  /// **'Bunun çalışması için konum iznini \"Her zaman izin ver\" olarak ayarlamanız gerekir.'**
  String get permLocationBgBullet2;

  /// No description provided for @permLocationBgBullet3.
  ///
  /// In tr, this message translates to:
  /// **'Bazı cihazlarda bu seçenek ayarlar sayfasından işaretlenir; dilediğiniz an yine oradan kapatabilirsiniz.'**
  String get permLocationBgBullet3;

  /// No description provided for @permNotifTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bildirim İzni'**
  String get permNotifTitle;

  /// No description provided for @permNotifDesc.
  ///
  /// In tr, this message translates to:
  /// **'Şehirdeki etkinlik, duyuru ve kampanyalardan haberdar olmanız için bildirim göndermek istiyoruz.'**
  String get permNotifDesc;

  /// No description provided for @permNotifBullet1.
  ///
  /// In tr, this message translates to:
  /// **'Yeni etkinlik ve duyurular anında ulaşır.'**
  String get permNotifBullet1;

  /// No description provided for @permNotifBullet2.
  ///
  /// In tr, this message translates to:
  /// **'Bildirim türlerini ayarlardan tek tek seçebilirsiniz.'**
  String get permNotifBullet2;

  /// No description provided for @permNotifBullet3.
  ///
  /// In tr, this message translates to:
  /// **'İstediğiniz zaman kapatabilirsiniz.'**
  String get permNotifBullet3;

  /// No description provided for @permCameraTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kamera İzni'**
  String get permCameraTitle;

  /// No description provided for @permCameraDesc.
  ///
  /// In tr, this message translates to:
  /// **'QR kod okuma ve artırılmış gerçeklik (AR) deneyimi için kameraya erişmemiz gerekir.'**
  String get permCameraDesc;

  /// No description provided for @permCameraBullet1.
  ///
  /// In tr, this message translates to:
  /// **'Mekanlardaki QR kodlarını okutabilirsiniz.'**
  String get permCameraBullet1;

  /// No description provided for @permCameraBullet2.
  ///
  /// In tr, this message translates to:
  /// **'Tarihi yapıları AR ile canlandırabilirsiniz.'**
  String get permCameraBullet2;

  /// No description provided for @permCameraBullet3.
  ///
  /// In tr, this message translates to:
  /// **'Kamera görüntüsü cihaz dışına gönderilmez.'**
  String get permCameraBullet3;

  /// No description provided for @btnNotNow.
  ///
  /// In tr, this message translates to:
  /// **'Şimdi Değil'**
  String get btnNotNow;

  /// No description provided for @campaignUpcoming.
  ///
  /// In tr, this message translates to:
  /// **'Kampanya Yakında'**
  String get campaignUpcoming;

  /// No description provided for @campaignUpcomingHint.
  ///
  /// In tr, this message translates to:
  /// **'+{points} puan kazanmak için kampanyayı bekleyin'**
  String campaignUpcomingHint(int points);

  /// No description provided for @campaignEnded.
  ///
  /// In tr, this message translates to:
  /// **'Kampanya Bitti'**
  String get campaignEnded;

  /// No description provided for @pointsAmount.
  ///
  /// In tr, this message translates to:
  /// **'+{points} Puan'**
  String pointsAmount(int points);

  /// No description provided for @pointsApproach.
  ///
  /// In tr, this message translates to:
  /// **'Mekana yaklaşarak puan kazanın'**
  String get pointsApproach;

  /// No description provided for @pointsApproachWithDist.
  ///
  /// In tr, this message translates to:
  /// **'Mekana yaklaşarak puan kazanın ({distance} uzakta)'**
  String pointsApproachWithDist(String distance);

  /// No description provided for @almostThere.
  ///
  /// In tr, this message translates to:
  /// **'Neredeyse oradasınız!'**
  String get almostThere;

  /// No description provided for @pointsApproachMore.
  ///
  /// In tr, this message translates to:
  /// **'+{points} puan için {distance} daha yaklaşın'**
  String pointsApproachMore(int points, String distance);

  /// No description provided for @collectPoints.
  ///
  /// In tr, this message translates to:
  /// **'Puanı Topla!'**
  String get collectPoints;

  /// No description provided for @earnPoints.
  ///
  /// In tr, this message translates to:
  /// **'+{points} puan kazanın'**
  String earnPoints(int points);

  /// No description provided for @collectingPoints.
  ///
  /// In tr, this message translates to:
  /// **'Puan toplanıyor...'**
  String get collectingPoints;

  /// No description provided for @routeCompletedBonus.
  ///
  /// In tr, this message translates to:
  /// **'Rota Tamamlandı! +{earned} Bonus Puan'**
  String routeCompletedBonus(int earned);

  /// No description provided for @pointsEarnedExclaim.
  ///
  /// In tr, this message translates to:
  /// **'+{earned} Puan Kazanıldı!'**
  String pointsEarnedExclaim(int earned);

  /// No description provided for @errOccurred.
  ///
  /// In tr, this message translates to:
  /// **'Bir hata oluştu'**
  String get errOccurred;

  /// No description provided for @lblViewCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} görüntülenme'**
  String lblViewCount(int count);

  /// No description provided for @heroDiscoverSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Şehrinizi keşfedin, etkinliklere katılın'**
  String get heroDiscoverSubtitle;

  /// No description provided for @lblAddress.
  ///
  /// In tr, this message translates to:
  /// **'Adres'**
  String get lblAddress;

  /// No description provided for @badgeNew.
  ///
  /// In tr, this message translates to:
  /// **'Yeni'**
  String get badgeNew;

  /// No description provided for @badgeImportant.
  ///
  /// In tr, this message translates to:
  /// **'Önemli'**
  String get badgeImportant;

  /// No description provided for @onboardingStart.
  ///
  /// In tr, this message translates to:
  /// **'Başla'**
  String get onboardingStart;

  /// No description provided for @onbSkip.
  ///
  /// In tr, this message translates to:
  /// **'Atla'**
  String get onbSkip;

  /// No description provided for @onbContinue.
  ///
  /// In tr, this message translates to:
  /// **'Devam'**
  String get onbContinue;

  /// No description provided for @onbWelcomeTitle.
  ///
  /// In tr, this message translates to:
  /// **'Samsun\'a Hoş Geldiniz'**
  String get onbWelcomeTitle;

  /// No description provided for @onbWelcomeDesc.
  ///
  /// In tr, this message translates to:
  /// **'Şehrin tarihini, kültürünü ve güzelliklerini tek bir uygulamada keşfedin. Harita, AR, asistan ve daha fazlasını birkaç adımda tanıtalım.'**
  String get onbWelcomeDesc;

  /// No description provided for @onbNavTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kolay Gezinme'**
  String get onbNavTitle;

  /// No description provided for @onbNavDesc.
  ///
  /// In tr, this message translates to:
  /// **'Her şeye birkaç dokunuşla ulaşın. Aşağıdaki çubuk ana bölümlere, ortadaki buton haritaya götürür.'**
  String get onbNavDesc;

  /// No description provided for @onbNavBullet1Title.
  ///
  /// In tr, this message translates to:
  /// **'Alt çubuk'**
  String get onbNavBullet1Title;

  /// No description provided for @onbNavBullet1Desc.
  ///
  /// In tr, this message translates to:
  /// **'Anasayfa, Yerler, Duyurular ve Profil sekmeleri.'**
  String get onbNavBullet1Desc;

  /// No description provided for @onbNavBullet2Title.
  ///
  /// In tr, this message translates to:
  /// **'Ortadaki harita butonu'**
  String get onbNavBullet2Title;

  /// No description provided for @onbNavBullet2Desc.
  ///
  /// In tr, this message translates to:
  /// **'Şehri canlı haritada keşfedin.'**
  String get onbNavBullet2Desc;

  /// No description provided for @onbNavBullet3Title.
  ///
  /// In tr, this message translates to:
  /// **'Sol üstteki ☰ menü'**
  String get onbNavBullet3Title;

  /// No description provided for @onbNavBullet3Desc.
  ///
  /// In tr, this message translates to:
  /// **'Tüm bölümler ve tema (Açık/Koyu/Sistem) buradan ayarlanır.'**
  String get onbNavBullet3Desc;

  /// No description provided for @onbNavBullet4Title.
  ///
  /// In tr, this message translates to:
  /// **'Sağ üstteki Asistan'**
  String get onbNavBullet4Title;

  /// No description provided for @onbNavBullet4Desc.
  ///
  /// In tr, this message translates to:
  /// **'Samsun Asistan\'a istediğinizi sorun.'**
  String get onbNavBullet4Desc;

  /// No description provided for @onbDiscoverTitle.
  ///
  /// In tr, this message translates to:
  /// **'Keşfet & Ara'**
  String get onbDiscoverTitle;

  /// No description provided for @onbDiscoverDesc.
  ///
  /// In tr, this message translates to:
  /// **'Anasayfa size özel canlı bir keşif akışı sunar; aradığınızı kategori ve konuma göre hızlıca bulun.'**
  String get onbDiscoverDesc;

  /// No description provided for @onbDiscoverBullet1Title.
  ///
  /// In tr, this message translates to:
  /// **'Yakınındakiler'**
  String get onbDiscoverBullet1Title;

  /// No description provided for @onbDiscoverBullet1Desc.
  ///
  /// In tr, this message translates to:
  /// **'Konumunuza göre çevredeki yerler otomatik listelenir.'**
  String get onbDiscoverBullet1Desc;

  /// No description provided for @onbDiscoverBullet2Title.
  ///
  /// In tr, this message translates to:
  /// **'Size özel öneriler'**
  String get onbDiscoverBullet2Title;

  /// No description provided for @onbDiscoverBullet2Desc.
  ///
  /// In tr, this message translates to:
  /// **'İlgi alanlarınıza göre kişiselleştirilmiş içerik.'**
  String get onbDiscoverBullet2Desc;

  /// No description provided for @onbDiscoverBullet3Title.
  ///
  /// In tr, this message translates to:
  /// **'Arama & filtre'**
  String get onbDiscoverBullet3Title;

  /// No description provided for @onbDiscoverBullet3Desc.
  ///
  /// In tr, this message translates to:
  /// **'Kategori ve konuma göre hızlıca süzün.'**
  String get onbDiscoverBullet3Desc;

  /// No description provided for @onbDiscoverBullet4Title.
  ///
  /// In tr, this message translates to:
  /// **'Gezi planı'**
  String get onbDiscoverBullet4Title;

  /// No description provided for @onbDiscoverBullet4Desc.
  ///
  /// In tr, this message translates to:
  /// **'Birden çok durağı tek bir günlük rotada planlayın.'**
  String get onbDiscoverBullet4Desc;

  /// No description provided for @onbRewardsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet, Topla & Tamamla'**
  String get onbRewardsTitle;

  /// No description provided for @onbRewardsDesc.
  ///
  /// In tr, this message translates to:
  /// **'Uygulamayı kullandıkça kazanın. Beğendiklerinizi kaydedin, gittiğiniz yerleri tamamlayın ve puan biriktirin.'**
  String get onbRewardsDesc;

  /// No description provided for @onbRewardsBullet1Title.
  ///
  /// In tr, this message translates to:
  /// **'Favorilere ekle'**
  String get onbRewardsBullet1Title;

  /// No description provided for @onbRewardsBullet1Desc.
  ///
  /// In tr, this message translates to:
  /// **'Kalbe dokunup içeriği favorilerinize kaydedin.'**
  String get onbRewardsBullet1Desc;

  /// No description provided for @onbRewardsBullet2Title.
  ///
  /// In tr, this message translates to:
  /// **'Tamamla'**
  String get onbRewardsBullet2Title;

  /// No description provided for @onbRewardsBullet2Desc.
  ///
  /// In tr, this message translates to:
  /// **'Bir yere gidince \"Yeri Tamamladım\", rotayı bitirince rotayı tamamlayın.'**
  String get onbRewardsBullet2Desc;

  /// No description provided for @onbRewardsBullet3Title.
  ///
  /// In tr, this message translates to:
  /// **'Puan & rozetler'**
  String get onbRewardsBullet3Title;

  /// No description provided for @onbRewardsBullet3Desc.
  ///
  /// In tr, this message translates to:
  /// **'Topladığınız puanlarla rozet ve ödüller açın.'**
  String get onbRewardsBullet3Desc;

  /// No description provided for @onbRewardsBullet4Title.
  ///
  /// In tr, this message translates to:
  /// **'Günlük giriş'**
  String get onbRewardsBullet4Title;

  /// No description provided for @onbRewardsBullet4Desc.
  ///
  /// In tr, this message translates to:
  /// **'Her gün girdiğinizde ekstra ödül kazanın.'**
  String get onbRewardsBullet4Desc;

  /// No description provided for @onbSaveTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet & Hızlı Eriş'**
  String get onbSaveTitle;

  /// No description provided for @onbSaveDesc.
  ///
  /// In tr, this message translates to:
  /// **'Beğendiğiniz yerleri, etkinlikleri ve içerikleri favorilerinize ekleyin; hepsine tek yerden ulaşın.'**
  String get onbSaveDesc;

  /// No description provided for @onbSaveBullet1Title.
  ///
  /// In tr, this message translates to:
  /// **'Favorilere ekle'**
  String get onbSaveBullet1Title;

  /// No description provided for @onbSaveBullet1Desc.
  ///
  /// In tr, this message translates to:
  /// **'Kalbe dokunup içeriği favorilerinize kaydedin.'**
  String get onbSaveBullet1Desc;

  /// No description provided for @onbSaveBullet2Title.
  ///
  /// In tr, this message translates to:
  /// **'Tek listede topla'**
  String get onbSaveBullet2Title;

  /// No description provided for @onbSaveBullet2Desc.
  ///
  /// In tr, this message translates to:
  /// **'Mekanlar, Rotalar, Tarifler ve Lezzetler ayrı sekmelerde.'**
  String get onbSaveBullet2Desc;

  /// No description provided for @onbSaveBullet3Title.
  ///
  /// In tr, this message translates to:
  /// **'Hızlı eriş'**
  String get onbSaveBullet3Title;

  /// No description provided for @onbSaveBullet3Desc.
  ///
  /// In tr, this message translates to:
  /// **'Kaydettiklerinize istediğiniz an tek dokunuşla ulaşın.'**
  String get onbSaveBullet3Desc;

  /// No description provided for @onbMapTitle.
  ///
  /// In tr, this message translates to:
  /// **'Harita & Yol Tarifi'**
  String get onbMapTitle;

  /// No description provided for @onbMapDesc.
  ///
  /// In tr, this message translates to:
  /// **'Şehrin önemli noktalarını harita üzerinde görün ve gitmek istediğiniz yere tek dokunuşla yönlenin.'**
  String get onbMapDesc;

  /// No description provided for @onbMapBullet1Title.
  ///
  /// In tr, this message translates to:
  /// **'Noktalar haritada'**
  String get onbMapBullet1Title;

  /// No description provided for @onbMapBullet1Desc.
  ///
  /// In tr, this message translates to:
  /// **'Turistik, kültürel ve sosyal alanlar harita üzerinde.'**
  String get onbMapBullet1Desc;

  /// No description provided for @onbMapBullet2Title.
  ///
  /// In tr, this message translates to:
  /// **'Isı haritası'**
  String get onbMapBullet2Title;

  /// No description provided for @onbMapBullet2Desc.
  ///
  /// In tr, this message translates to:
  /// **'En çok gezilen bölgeleri tek bakışta görün.'**
  String get onbMapBullet2Desc;

  /// No description provided for @onbMapBullet3Title.
  ///
  /// In tr, this message translates to:
  /// **'Yol tarifi'**
  String get onbMapBullet3Title;

  /// No description provided for @onbMapBullet3Desc.
  ///
  /// In tr, this message translates to:
  /// **'Seçtiğiniz yere navigasyon uygulamanızla yönlenin.'**
  String get onbMapBullet3Desc;

  /// No description provided for @onbMapBullet4Title.
  ///
  /// In tr, this message translates to:
  /// **'Çevremde'**
  String get onbMapBullet4Title;

  /// No description provided for @onbMapBullet4Desc.
  ///
  /// In tr, this message translates to:
  /// **'Bulunduğunuz konuma yakın noktaları anlık görün.'**
  String get onbMapBullet4Desc;

  /// No description provided for @onbScanTitle.
  ///
  /// In tr, this message translates to:
  /// **'QR, AR & Asistan'**
  String get onbScanTitle;

  /// No description provided for @onbScanDesc.
  ///
  /// In tr, this message translates to:
  /// **'Şehri etkileşimli yaşayın: kod okutun, tarihi canlandırın veya asistana sorun.'**
  String get onbScanDesc;

  /// No description provided for @onbScanBullet1Title.
  ///
  /// In tr, this message translates to:
  /// **'QR okut'**
  String get onbScanBullet1Title;

  /// No description provided for @onbScanBullet1Desc.
  ///
  /// In tr, this message translates to:
  /// **'Mekanlardaki kodları okutup içeriğe anında ulaşın.'**
  String get onbScanBullet1Desc;

  /// No description provided for @onbScanBullet2Title.
  ///
  /// In tr, this message translates to:
  /// **'AR ile canlandır'**
  String get onbScanBullet2Title;

  /// No description provided for @onbScanBullet2Desc.
  ///
  /// In tr, this message translates to:
  /// **'Tarihi yapıları radar, kamera ve 3B dünya modunda keşfedin.'**
  String get onbScanBullet2Desc;

  /// No description provided for @onbScanBullet3Title.
  ///
  /// In tr, this message translates to:
  /// **'Samsun Asistan'**
  String get onbScanBullet3Title;

  /// No description provided for @onbScanBullet3Desc.
  ///
  /// In tr, this message translates to:
  /// **'Yazarak sorun; uygulamadaki bilgilerle anında yanıt alın.'**
  String get onbScanBullet3Desc;

  /// No description provided for @onbInterestsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Sizi Ne İlgilendirir?'**
  String get onbInterestsTitle;

  /// No description provided for @onbInterestsDesc.
  ///
  /// In tr, this message translates to:
  /// **'Önerileri size göre kişiselleştirebilmemiz için bir veya birden fazla seçim yapabilirsiniz. Bu adımı atlayabilirsiniz.'**
  String get onbInterestsDesc;

  /// No description provided for @onbInterestHistoric.
  ///
  /// In tr, this message translates to:
  /// **'Tarihi Yerler'**
  String get onbInterestHistoric;

  /// No description provided for @onbInterestCulture.
  ///
  /// In tr, this message translates to:
  /// **'Kültür & Sanat'**
  String get onbInterestCulture;

  /// No description provided for @onbInterestNature.
  ///
  /// In tr, this message translates to:
  /// **'Doğa & Park'**
  String get onbInterestNature;

  /// No description provided for @onbInterestFood.
  ///
  /// In tr, this message translates to:
  /// **'Yeme-İçme'**
  String get onbInterestFood;

  /// No description provided for @onbInterestEvents.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlikler'**
  String get onbInterestEvents;

  /// No description provided for @onbInterestRoutes.
  ///
  /// In tr, this message translates to:
  /// **'Gezi Rotaları'**
  String get onbInterestRoutes;

  /// No description provided for @onbInterestArQr.
  ///
  /// In tr, this message translates to:
  /// **'AR & QR Deneyimi'**
  String get onbInterestArQr;

  /// No description provided for @onbInterestRecipes.
  ///
  /// In tr, this message translates to:
  /// **'Yöresel Tarifler'**
  String get onbInterestRecipes;

  /// No description provided for @filterShowAll.
  ///
  /// In tr, this message translates to:
  /// **'Tümünü göster'**
  String get filterShowAll;

  /// No description provided for @filterFavoritesOnly.
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca favorilerim'**
  String get filterFavoritesOnly;

  /// No description provided for @lblDuration.
  ///
  /// In tr, this message translates to:
  /// **'Süre'**
  String get lblDuration;

  /// No description provided for @recipeLocal.
  ///
  /// In tr, this message translates to:
  /// **'Yöresel'**
  String get recipeLocal;

  /// No description provided for @tapForDetails.
  ///
  /// In tr, this message translates to:
  /// **'Detayları görmek için tıklayın'**
  String get tapForDetails;

  /// No description provided for @favPlacesEmptyOrNoMatch.
  ///
  /// In tr, this message translates to:
  /// **'Favori mekânınız yok veya eşleşen sonuç bulunamadı.'**
  String get favPlacesEmptyOrNoMatch;

  /// No description provided for @emptyTryDifferent.
  ///
  /// In tr, this message translates to:
  /// **'Farklı bir kategori veya arama terimi deneyin'**
  String get emptyTryDifferent;

  /// No description provided for @locationPermissionFromSettings.
  ///
  /// In tr, this message translates to:
  /// **'Konum izni ayarlardan açılmalı'**
  String get locationPermissionFromSettings;

  /// No description provided for @errLocationFailed.
  ///
  /// In tr, this message translates to:
  /// **'Konum alınamadı'**
  String get errLocationFailed;

  /// No description provided for @placeMarkVisited.
  ///
  /// In tr, this message translates to:
  /// **'Burayı ziyaret ettim'**
  String get placeMarkVisited;

  /// No description provided for @placeMarkedVisited.
  ///
  /// In tr, this message translates to:
  /// **'Ziyaret edildi olarak işaretlendi.'**
  String get placeMarkedVisited;

  /// No description provided for @placeUnmarkedVisited.
  ///
  /// In tr, this message translates to:
  /// **'Ziyaret işareti kaldırıldı.'**
  String get placeUnmarkedVisited;

  /// No description provided for @lblComingSoon.
  ///
  /// In tr, this message translates to:
  /// **'Yakında'**
  String get lblComingSoon;

  /// No description provided for @pointsCollected.
  ///
  /// In tr, this message translates to:
  /// **'Puan Alındı'**
  String get pointsCollected;

  /// No description provided for @arViewWith.
  ///
  /// In tr, this message translates to:
  /// **'AR ile Görüntüle'**
  String get arViewWith;

  /// No description provided for @recipePreparation.
  ///
  /// In tr, this message translates to:
  /// **'Hazırlanışı'**
  String get recipePreparation;

  /// No description provided for @recipeLoadError.
  ///
  /// In tr, this message translates to:
  /// **'Tarif yüklenirken bir hata oluştu.'**
  String get recipeLoadError;

  /// No description provided for @errRecipeNotFound.
  ///
  /// In tr, this message translates to:
  /// **'Tarif bulunamadı.'**
  String get errRecipeNotFound;

  /// No description provided for @recipePrepTime.
  ///
  /// In tr, this message translates to:
  /// **'Hazırlık'**
  String get recipePrepTime;

  /// No description provided for @recipeServings.
  ///
  /// In tr, this message translates to:
  /// **'kişi'**
  String get recipeServings;

  /// No description provided for @recipeNoDescription.
  ///
  /// In tr, this message translates to:
  /// **'Bu tarif için açıklama henüz eklenmemiş.'**
  String get recipeNoDescription;

  /// No description provided for @recipeTips.
  ///
  /// In tr, this message translates to:
  /// **'Püf Noktaları'**
  String get recipeTips;

  /// No description provided for @recipeFavEmptyOrNoMatch.
  ///
  /// In tr, this message translates to:
  /// **'Favori tarifiniz yok veya eşleşen sonuç bulunamadı.'**
  String get recipeFavEmptyOrNoMatch;

  /// No description provided for @recipeNoneToShow.
  ///
  /// In tr, this message translates to:
  /// **'Şu anda gösterilecek tarif bulunamadı.'**
  String get recipeNoneToShow;

  /// No description provided for @delicaciesSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Şehrimizin geleneksel tatları'**
  String get delicaciesSubtitle;

  /// No description provided for @delicaciesLoadError.
  ///
  /// In tr, this message translates to:
  /// **'Yöresel lezzetler yüklenirken bir hata oluştu.'**
  String get delicaciesLoadError;

  /// No description provided for @delicacyFavEmptyOrNoMatch.
  ///
  /// In tr, this message translates to:
  /// **'Favori yöresel lezzetiniz yok veya eşleşen sonuç bulunamadı.'**
  String get delicacyFavEmptyOrNoMatch;

  /// No description provided for @delicacyNoneToShow.
  ///
  /// In tr, this message translates to:
  /// **'Şu anda gösterilecek yöresel lezzet bulunamadı.'**
  String get delicacyNoneToShow;

  /// No description provided for @lblLocalDelicacy.
  ///
  /// In tr, this message translates to:
  /// **'Yöresel Lezzet'**
  String get lblLocalDelicacy;

  /// No description provided for @delicacyLoadError.
  ///
  /// In tr, this message translates to:
  /// **'Bu lezzet yüklenirken bir hata oluştu.'**
  String get delicacyLoadError;

  /// No description provided for @delicacyNotFound.
  ///
  /// In tr, this message translates to:
  /// **'Bu lezzet bulunamadı.'**
  String get delicacyNotFound;

  /// No description provided for @delicacyDetail.
  ///
  /// In tr, this message translates to:
  /// **'Lezzet Detayı'**
  String get delicacyDetail;

  /// No description provided for @tapToWatchVideo.
  ///
  /// In tr, this message translates to:
  /// **'Videoyu izlemek için tıklayın'**
  String get tapToWatchVideo;

  /// No description provided for @menuAbout.
  ///
  /// In tr, this message translates to:
  /// **'Menü Hakkında'**
  String get menuAbout;

  /// No description provided for @delicacyNoDescription.
  ///
  /// In tr, this message translates to:
  /// **'Bu lezzet için açıklama henüz eklenmemiş.'**
  String get delicacyNoDescription;

  /// No description provided for @delicacyRestaurantsSoon.
  ///
  /// In tr, this message translates to:
  /// **'Bu lezzeti sunan restoranlar yakında eklenecek.'**
  String get delicacyRestaurantsSoon;

  /// No description provided for @delicacyRestaurantsOnMap.
  ///
  /// In tr, this message translates to:
  /// **'Restoranları Haritada Gör'**
  String get delicacyRestaurantsOnMap;

  /// No description provided for @delicacyShowPointsOnMap.
  ///
  /// In tr, this message translates to:
  /// **'Bu menüyü sunan noktaları haritada göster'**
  String get delicacyShowPointsOnMap;

  /// No description provided for @routeCompleted.
  ///
  /// In tr, this message translates to:
  /// **'Rota Tamamlandı!'**
  String get routeCompleted;

  /// No description provided for @routeAllStopsBonus.
  ///
  /// In tr, this message translates to:
  /// **'+{bonus} Tüm Duraklar Bonusu'**
  String routeAllStopsBonus(int bonus);

  /// No description provided for @routeCompletionBonus.
  ///
  /// In tr, this message translates to:
  /// **'+{bonus} Tamamlama Bonusu'**
  String routeCompletionBonus(int bonus);

  /// No description provided for @routeBonusPoints.
  ///
  /// In tr, this message translates to:
  /// **'+{points} Bonus Puan'**
  String routeBonusPoints(int points);

  /// No description provided for @routeMarkCompleted.
  ///
  /// In tr, this message translates to:
  /// **'Bu rotayı tamamladım'**
  String get routeMarkCompleted;

  /// No description provided for @routeMarkedCompleted.
  ///
  /// In tr, this message translates to:
  /// **'Rota tamamlandı olarak işaretlendi.'**
  String get routeMarkedCompleted;

  /// No description provided for @routeUnmarkedCompleted.
  ///
  /// In tr, this message translates to:
  /// **'Tamamlanma işareti kaldırıldı.'**
  String get routeUnmarkedCompleted;

  /// No description provided for @routeYourProgress.
  ///
  /// In tr, this message translates to:
  /// **'İlerlemeniz'**
  String get routeYourProgress;

  /// No description provided for @routeEarnPointsHint.
  ///
  /// In tr, this message translates to:
  /// **'Bu rotayı tamamlayarak {points} puan kazanabilirsiniz!'**
  String routeEarnPointsHint(int points);

  /// No description provided for @routeView.
  ///
  /// In tr, this message translates to:
  /// **'Rotayı Gör'**
  String get routeView;

  /// No description provided for @cultureCatMuseum.
  ///
  /// In tr, this message translates to:
  /// **'Müze'**
  String get cultureCatMuseum;

  /// No description provided for @cultureCatEvent.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik'**
  String get cultureCatEvent;

  /// No description provided for @cultureCatArt.
  ///
  /// In tr, this message translates to:
  /// **'Sanat'**
  String get cultureCatArt;

  /// No description provided for @cultureCatTheater.
  ///
  /// In tr, this message translates to:
  /// **'Tiyatro'**
  String get cultureCatTheater;

  /// No description provided for @cultureAllEvents.
  ///
  /// In tr, this message translates to:
  /// **'Tüm Etkinlikler'**
  String get cultureAllEvents;

  /// No description provided for @lblResultCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} sonuç'**
  String lblResultCount(int count);

  /// No description provided for @cultureSections.
  ///
  /// In tr, this message translates to:
  /// **'Bölümler'**
  String get cultureSections;

  /// No description provided for @cultureLocationContact.
  ///
  /// In tr, this message translates to:
  /// **'Konum & İletişim'**
  String get cultureLocationContact;

  /// No description provided for @cultureTicketRegistration.
  ///
  /// In tr, this message translates to:
  /// **'Bilet / Kayıt'**
  String get cultureTicketRegistration;

  /// No description provided for @cultureFreeEvent.
  ///
  /// In tr, this message translates to:
  /// **'Ücretsiz Etkinlik'**
  String get cultureFreeEvent;

  /// No description provided for @cultureFreeEventDesc.
  ///
  /// In tr, this message translates to:
  /// **'Bu etkinlik ücretsizdir. Katılım için önceden kayıt gerekmez.'**
  String get cultureFreeEventDesc;

  /// No description provided for @cultureTicketContact.
  ///
  /// In tr, this message translates to:
  /// **'Bilet satışı için lütfen etkinlik mekanı ile iletişime geçin.'**
  String get cultureTicketContact;

  /// No description provided for @errEventNotFound.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik bulunamadı'**
  String get errEventNotFound;

  /// No description provided for @lblVisitor.
  ///
  /// In tr, this message translates to:
  /// **'Ziyaretçi'**
  String get lblVisitor;

  /// No description provided for @lblOpen.
  ///
  /// In tr, this message translates to:
  /// **'Açık'**
  String get lblOpen;

  /// No description provided for @lblClosed.
  ///
  /// In tr, this message translates to:
  /// **'Kapalı'**
  String get lblClosed;

  /// No description provided for @filterEventTitle.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik Filtreleri'**
  String get filterEventTitle;

  /// No description provided for @filterSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Aradığınız etkinlikleri kolayca bulun'**
  String get filterSubtitle;

  /// No description provided for @filterSelectDateRange.
  ///
  /// In tr, this message translates to:
  /// **'Tarih Aralığı Seç'**
  String get filterSelectDateRange;

  /// No description provided for @filterSelectDateRangeHelp.
  ///
  /// In tr, this message translates to:
  /// **'Tarih aralığı seçin'**
  String get filterSelectDateRangeHelp;

  /// No description provided for @filterStartDateHint.
  ///
  /// In tr, this message translates to:
  /// **'Başlangıç tarihi'**
  String get filterStartDateHint;

  /// No description provided for @filterEndDateHint.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş tarihi'**
  String get filterEndDateHint;

  /// No description provided for @filterInvalidRange.
  ///
  /// In tr, this message translates to:
  /// **'Geçerli bir tarih aralığı seçin'**
  String get filterInvalidRange;

  /// No description provided for @filterFreeEventsOnly.
  ///
  /// In tr, this message translates to:
  /// **'Sadece Ücretsiz Etkinlikler'**
  String get filterFreeEventsOnly;

  /// No description provided for @filterFreeEventsOnlyDesc.
  ///
  /// In tr, this message translates to:
  /// **'Ücretsiz katılabileceğiniz etkinlikleri göster'**
  String get filterFreeEventsOnlyDesc;

  /// No description provided for @themeShortLight.
  ///
  /// In tr, this message translates to:
  /// **'Açık'**
  String get themeShortLight;

  /// No description provided for @themeShortDark.
  ///
  /// In tr, this message translates to:
  /// **'Koyu'**
  String get themeShortDark;

  /// No description provided for @themeShortSystem.
  ///
  /// In tr, this message translates to:
  /// **'Sistem'**
  String get themeShortSystem;

  /// No description provided for @drawerSlogan.
  ///
  /// In tr, this message translates to:
  /// **'Şehri keşfet'**
  String get drawerSlogan;

  /// No description provided for @drawerExplore.
  ///
  /// In tr, this message translates to:
  /// **'Keşfet'**
  String get drawerExplore;

  /// No description provided for @drawerViewProfile.
  ///
  /// In tr, this message translates to:
  /// **'Profili görüntüle'**
  String get drawerViewProfile;

  /// No description provided for @drawerGuestSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Giriş yap veya kayıt ol'**
  String get drawerGuestSubtitle;

  /// No description provided for @homeAroundMeAr.
  ///
  /// In tr, this message translates to:
  /// **'Çevremde AR'**
  String get homeAroundMeAr;

  /// No description provided for @mapNoPlacesInArea.
  ///
  /// In tr, this message translates to:
  /// **'Bu bölgede gösterilebilecek bir yer bulunamadı.'**
  String get mapNoPlacesInArea;

  /// No description provided for @mapSearchHint.
  ///
  /// In tr, this message translates to:
  /// **'Konum veya mekan ara...'**
  String get mapSearchHint;

  /// No description provided for @lblEarned.
  ///
  /// In tr, this message translates to:
  /// **'Kazanılan'**
  String get lblEarned;

  /// No description provided for @staffMyTransactions.
  ///
  /// In tr, this message translates to:
  /// **'İşlemlerim'**
  String get staffMyTransactions;

  /// No description provided for @lblNotification.
  ///
  /// In tr, this message translates to:
  /// **'Bildirim'**
  String get lblNotification;

  /// No description provided for @btnView.
  ///
  /// In tr, this message translates to:
  /// **'Görüntüle'**
  String get btnView;

  /// No description provided for @lblErrorWith.
  ///
  /// In tr, this message translates to:
  /// **'Hata: {error}'**
  String lblErrorWith(String error);

  /// No description provided for @docNotFound.
  ///
  /// In tr, this message translates to:
  /// **'Belge bulunamadı.'**
  String get docNotFound;

  /// No description provided for @sectionForYou.
  ///
  /// In tr, this message translates to:
  /// **'Sizin İçin'**
  String get sectionForYou;

  /// No description provided for @sectionNearby.
  ///
  /// In tr, this message translates to:
  /// **'Yakındakiler'**
  String get sectionNearby;

  /// No description provided for @sectionPopular.
  ///
  /// In tr, this message translates to:
  /// **'Popüler'**
  String get sectionPopular;

  /// No description provided for @sectionNewlyAdded.
  ///
  /// In tr, this message translates to:
  /// **'Yeni Eklenenler'**
  String get sectionNewlyAdded;

  /// No description provided for @lblMenu.
  ///
  /// In tr, this message translates to:
  /// **'Menü'**
  String get lblMenu;

  /// No description provided for @qrCreateFailed.
  ///
  /// In tr, this message translates to:
  /// **'QR oluşturulamadı'**
  String get qrCreateFailed;

  /// No description provided for @qrPointsSpent.
  ///
  /// In tr, this message translates to:
  /// **'{amount} puan harcandı.'**
  String qrPointsSpent(int amount);

  /// No description provided for @lblLanguageShort.
  ///
  /// In tr, this message translates to:
  /// **'Dil'**
  String get lblLanguageShort;

  /// No description provided for @itineraryNewButton.
  ///
  /// In tr, this message translates to:
  /// **'Yeni Plan'**
  String get itineraryNewButton;

  /// No description provided for @itineraryNotFound.
  ///
  /// In tr, this message translates to:
  /// **'Plan bulunamadı'**
  String get itineraryNotFound;

  /// No description provided for @itineraryRename.
  ///
  /// In tr, this message translates to:
  /// **'Yeniden adlandır'**
  String get itineraryRename;

  /// No description provided for @itineraryAddPlace.
  ///
  /// In tr, this message translates to:
  /// **'Mekan Ekle'**
  String get itineraryAddPlace;

  /// No description provided for @itineraryRenameTitle.
  ///
  /// In tr, this message translates to:
  /// **'Plan adını değiştir'**
  String get itineraryRenameTitle;

  /// No description provided for @itineraryNewName.
  ///
  /// In tr, this message translates to:
  /// **'Yeni ad'**
  String get itineraryNewName;

  /// No description provided for @btnRemove.
  ///
  /// In tr, this message translates to:
  /// **'Kaldır'**
  String get btnRemove;

  /// No description provided for @itineraryNoStops.
  ///
  /// In tr, this message translates to:
  /// **'Bu plana henüz durak eklemediniz'**
  String get itineraryNoStops;

  /// No description provided for @itinerarySelectPlace.
  ///
  /// In tr, this message translates to:
  /// **'Mekan Seç'**
  String get itinerarySelectPlace;

  /// No description provided for @itinerarySearchPlace.
  ///
  /// In tr, this message translates to:
  /// **'Mekan ara...'**
  String get itinerarySearchPlace;

  /// No description provided for @accountRestoredShort.
  ///
  /// In tr, this message translates to:
  /// **'Hesabınız geri yüklendi.'**
  String get accountRestoredShort;

  /// No description provided for @accountRestoreFailed.
  ///
  /// In tr, this message translates to:
  /// **'Hesap geri yüklenemedi. Lütfen tekrar deneyin.'**
  String get accountRestoreFailed;

  /// No description provided for @itineraryNewTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yeni Gezi Planı'**
  String get itineraryNewTitle;

  /// No description provided for @itineraryNameLabel.
  ///
  /// In tr, this message translates to:
  /// **'Plan adı'**
  String get itineraryNameLabel;

  /// No description provided for @itineraryNameHint.
  ///
  /// In tr, this message translates to:
  /// **'Ör. Hafta sonu Samsun turu'**
  String get itineraryNameHint;

  /// No description provided for @lblStart.
  ///
  /// In tr, this message translates to:
  /// **'Başlangıç'**
  String get lblStart;

  /// No description provided for @lblEnd.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş'**
  String get lblEnd;

  /// No description provided for @btnCreate.
  ///
  /// In tr, this message translates to:
  /// **'Oluştur'**
  String get btnCreate;

  /// No description provided for @achievementsEarned.
  ///
  /// In tr, this message translates to:
  /// **'{unlocked} / {total} rozet kazanıldı'**
  String achievementsEarned(int unlocked, int total);

  /// No description provided for @accountTitle.
  ///
  /// In tr, this message translates to:
  /// **'Hesap Bilgileri'**
  String get accountTitle;

  /// No description provided for @accountContactSection.
  ///
  /// In tr, this message translates to:
  /// **'İletişim Bilgileri'**
  String get accountContactSection;

  /// No description provided for @accountNameLabel.
  ///
  /// In tr, this message translates to:
  /// **'Ad Soyad'**
  String get accountNameLabel;

  /// No description provided for @accountPhoneLabel.
  ///
  /// In tr, this message translates to:
  /// **'Telefon'**
  String get accountPhoneLabel;

  /// No description provided for @accountEmailLabel.
  ///
  /// In tr, this message translates to:
  /// **'E-posta'**
  String get accountEmailLabel;

  /// No description provided for @accountEmailUnverified.
  ///
  /// In tr, this message translates to:
  /// **'Doğrulanmamış'**
  String get accountEmailUnverified;

  /// No description provided for @accountEmailVerified.
  ///
  /// In tr, this message translates to:
  /// **'Doğrulandı'**
  String get accountEmailVerified;

  /// No description provided for @accountNoEmail.
  ///
  /// In tr, this message translates to:
  /// **'E-posta eklenmemiş'**
  String get accountNoEmail;

  /// No description provided for @accountVerifyEmail.
  ///
  /// In tr, this message translates to:
  /// **'Doğrula'**
  String get accountVerifyEmail;

  /// No description provided for @accountAddEmail.
  ///
  /// In tr, this message translates to:
  /// **'E-posta Ekle'**
  String get accountAddEmail;

  /// No description provided for @accountChangeEmail.
  ///
  /// In tr, this message translates to:
  /// **'E-postayı Değiştir'**
  String get accountChangeEmail;

  /// No description provided for @accountChangePhone.
  ///
  /// In tr, this message translates to:
  /// **'Telefonu Değiştir'**
  String get accountChangePhone;

  /// No description provided for @emailVerifyTitle.
  ///
  /// In tr, this message translates to:
  /// **'E-postanı Doğrula'**
  String get emailVerifyTitle;

  /// No description provided for @emailVerifySentTo.
  ///
  /// In tr, this message translates to:
  /// **'{email} adresine 6 haneli bir doğrulama kodu gönderdik.'**
  String emailVerifySentTo(String email);

  /// No description provided for @emailVerifyCodeLabel.
  ///
  /// In tr, this message translates to:
  /// **'Doğrulama kodu'**
  String get emailVerifyCodeLabel;

  /// No description provided for @emailVerifyConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Doğrula'**
  String get emailVerifyConfirm;

  /// No description provided for @emailVerifyResend.
  ///
  /// In tr, this message translates to:
  /// **'Kodu tekrar gönder'**
  String get emailVerifyResend;

  /// No description provided for @emailVerifySuccess.
  ///
  /// In tr, this message translates to:
  /// **'E-postan başarıyla doğrulandı.'**
  String get emailVerifySuccess;

  /// No description provided for @emailVerifyWhyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Neden gerekli?'**
  String get emailVerifyWhyTitle;

  /// No description provided for @emailVerifyWhyBody.
  ///
  /// In tr, this message translates to:
  /// **'Doğrulanmış e-posta, telefon numaranı değiştirmek istediğinde kimliğini güvenle doğrulamamızı sağlar.'**
  String get emailVerifyWhyBody;

  /// No description provided for @emailVerifyErrorInUseElsewhere.
  ///
  /// In tr, this message translates to:
  /// **'Bu e-posta adresi başka bir hesapta zaten doğrulanmış. Güvenlik için aynı e-posta yalnızca tek bir hesapta doğrulanabilir. Adres gerçekten sana aitse destek ekibiyle iletişime geç; sana ait değilse Hesap Bilgileri\'nden e-postanı değiştir.'**
  String get emailVerifyErrorInUseElsewhere;

  /// No description provided for @contactErrorEmailRequiredFirst.
  ///
  /// In tr, this message translates to:
  /// **'Devam etmek için önce e-posta adresini ekleyip doğrulaman gerekiyor.'**
  String get contactErrorEmailRequiredFirst;

  /// No description provided for @contactErrorChangePending.
  ///
  /// In tr, this message translates to:
  /// **'Devam eden bir değişiklik isteği var. Lütfen önce onu tamamla veya iptal et.'**
  String get contactErrorChangePending;

  /// No description provided for @contactErrorInvalidCode.
  ///
  /// In tr, this message translates to:
  /// **'Kod hatalı. Lütfen kontrol edip tekrar dene.'**
  String get contactErrorInvalidCode;

  /// No description provided for @contactErrorCodeExpired.
  ///
  /// In tr, this message translates to:
  /// **'Kodun süresi doldu. Lütfen yeni bir kod iste.'**
  String get contactErrorCodeExpired;

  /// No description provided for @contactErrorTooManyAttempts.
  ///
  /// In tr, this message translates to:
  /// **'Çok fazla hatalı deneme yaptın. Lütfen bir süre sonra tekrar dene.'**
  String get contactErrorTooManyAttempts;

  /// No description provided for @contactErrorRateLimited.
  ///
  /// In tr, this message translates to:
  /// **'Çok fazla istek gönderildi. Lütfen kısa bir süre bekleyip tekrar dene.'**
  String get contactErrorRateLimited;

  /// No description provided for @contactErrorValueInUse.
  ///
  /// In tr, this message translates to:
  /// **'Bu bilgi kullanılamıyor. Lütfen farklı bir değer dene.'**
  String get contactErrorValueInUse;

  /// No description provided for @contactErrorSameValue.
  ///
  /// In tr, this message translates to:
  /// **'Yeni değer mevcut değerinle aynı.'**
  String get contactErrorSameValue;

  /// No description provided for @contactErrorGeneric.
  ///
  /// In tr, this message translates to:
  /// **'Bir hata oluştu. Lütfen tekrar dene.'**
  String get contactErrorGeneric;

  /// No description provided for @changeEmailTitle.
  ///
  /// In tr, this message translates to:
  /// **'E-postayı Değiştir'**
  String get changeEmailTitle;

  /// No description provided for @addEmailTitle.
  ///
  /// In tr, this message translates to:
  /// **'E-posta Ekle'**
  String get addEmailTitle;

  /// No description provided for @changePhoneTitle.
  ///
  /// In tr, this message translates to:
  /// **'Telefonu Değiştir'**
  String get changePhoneTitle;

  /// No description provided for @changeEmailIntro.
  ///
  /// In tr, this message translates to:
  /// **'Kimliğini doğrulamak için önce telefonuna bir doğrulama kodu göndereceğiz.'**
  String get changeEmailIntro;

  /// No description provided for @changePhoneIntro.
  ///
  /// In tr, this message translates to:
  /// **'Kimliğini doğrulamak için önce doğrulanmış e-posta adresine bir kod göndereceğiz.'**
  String get changePhoneIntro;

  /// No description provided for @changeContactSendCode.
  ///
  /// In tr, this message translates to:
  /// **'Kodu Gönder'**
  String get changeContactSendCode;

  /// No description provided for @changeStepPhoneOtpLabel.
  ///
  /// In tr, this message translates to:
  /// **'Telefonuna gelen kod'**
  String get changeStepPhoneOtpLabel;

  /// No description provided for @changeStepEmailCodeLabel.
  ///
  /// In tr, this message translates to:
  /// **'E-postana gelen kod'**
  String get changeStepEmailCodeLabel;

  /// No description provided for @changeNewEmailLabel.
  ///
  /// In tr, this message translates to:
  /// **'Yeni e-posta adresi'**
  String get changeNewEmailLabel;

  /// No description provided for @changeNewEmailCodeLabel.
  ///
  /// In tr, this message translates to:
  /// **'Yeni e-postana gelen kod'**
  String get changeNewEmailCodeLabel;

  /// No description provided for @changeNewPhoneLabel.
  ///
  /// In tr, this message translates to:
  /// **'Yeni telefon numarası'**
  String get changeNewPhoneLabel;

  /// No description provided for @changeNewPhoneHint.
  ///
  /// In tr, this message translates to:
  /// **'+90 5xx xxx xx xx'**
  String get changeNewPhoneHint;

  /// No description provided for @changeNewPhoneInvalid.
  ///
  /// In tr, this message translates to:
  /// **'Geçerli bir telefon numarası gir.'**
  String get changeNewPhoneInvalid;

  /// No description provided for @changeNewPhoneOtpLabel.
  ///
  /// In tr, this message translates to:
  /// **'Yeni numarana gelen kod'**
  String get changeNewPhoneOtpLabel;

  /// No description provided for @changeEmailSuccess.
  ///
  /// In tr, this message translates to:
  /// **'E-posta adresin güncellendi.'**
  String get changeEmailSuccess;

  /// No description provided for @addEmailSuccess.
  ///
  /// In tr, this message translates to:
  /// **'E-posta adresin eklendi ve doğrulandı.'**
  String get addEmailSuccess;

  /// No description provided for @changePhoneSuccess.
  ///
  /// In tr, this message translates to:
  /// **'Telefon numaran güncellendi.'**
  String get changePhoneSuccess;

  /// No description provided for @changePhoneOtherDevicesNote.
  ///
  /// In tr, this message translates to:
  /// **'Güvenliğin için diğer cihazlardaki oturumların kapatıldı.'**
  String get changePhoneOtherDevicesNote;

  /// No description provided for @changeContactStepLabel.
  ///
  /// In tr, this message translates to:
  /// **'Adım {current}/{total}'**
  String changeContactStepLabel(int current, int total);

  /// No description provided for @emailRequiredGateTitle.
  ///
  /// In tr, this message translates to:
  /// **'Önce e-postanı doğrula'**
  String get emailRequiredGateTitle;

  /// No description provided for @emailRequiredGateBody.
  ///
  /// In tr, this message translates to:
  /// **'Telefon numaranı değiştirebilmek için doğrulanmış bir e-posta adresine ihtiyacın var. Önce e-postanı ekleyip doğrula.'**
  String get emailRequiredGateBody;

  /// No description provided for @emailRequiredGateButton.
  ///
  /// In tr, this message translates to:
  /// **'Hesap Bilgilerine Git'**
  String get emailRequiredGateButton;

  /// No description provided for @btnNext.
  ///
  /// In tr, this message translates to:
  /// **'Devam'**
  String get btnNext;

  /// No description provided for @btnChange.
  ///
  /// In tr, this message translates to:
  /// **'Değiştir'**
  String get btnChange;

  /// No description provided for @profileEmailNotVerified.
  ///
  /// In tr, this message translates to:
  /// **'E-posta doğrulanmadı'**
  String get profileEmailNotVerified;

  /// No description provided for @filterSortTitle.
  ///
  /// In tr, this message translates to:
  /// **'Sıralama'**
  String get filterSortTitle;

  /// No description provided for @emailClaimConfirmTitle.
  ///
  /// In tr, this message translates to:
  /// **'E-posta başka hesapta kayıtlı'**
  String get emailClaimConfirmTitle;

  /// No description provided for @emailClaimConfirmBody.
  ///
  /// In tr, this message translates to:
  /// **'Bu e-posta başka bir numaraya doğrulanmamış olarak kayıtlı. Doğrulama kodu alıp bu hesaba bağlamak ister misiniz?'**
  String get emailClaimConfirmBody;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
