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
/// import 'l10n/app_localizations.dart';
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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Samsun City Guide'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get navMap;

  /// No description provided for @navPlaces.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get navPlaces;

  /// No description provided for @navAnnouncements.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get navAnnouncements;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @navCulture.
  ///
  /// In en, this message translates to:
  /// **'Culture'**
  String get navCulture;

  /// No description provided for @quickCampaigns.
  ///
  /// In en, this message translates to:
  /// **'Campaigns'**
  String get quickCampaigns;

  /// No description provided for @quickRoutes.
  ///
  /// In en, this message translates to:
  /// **'Routes'**
  String get quickRoutes;

  /// No description provided for @quickFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get quickFood;

  /// No description provided for @quickEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get quickEvents;

  /// No description provided for @btnGetDirections.
  ///
  /// In en, this message translates to:
  /// **'Get Directions'**
  String get btnGetDirections;

  /// No description provided for @btnShowOnMap.
  ///
  /// In en, this message translates to:
  /// **'View on Map'**
  String get btnShowOnMap;

  /// No description provided for @btnShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get btnShare;

  /// No description provided for @btnSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get btnSave;

  /// No description provided for @btnCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get btnCancel;

  /// No description provided for @btnClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get btnClose;

  /// No description provided for @btnRetry.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get btnRetry;

  /// No description provided for @btnViewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get btnViewAll;

  /// No description provided for @btnApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get btnApply;

  /// No description provided for @btnClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear Filters'**
  String get btnClearFilters;

  /// No description provided for @btnLogout.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get btnLogout;

  /// No description provided for @btnLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get btnLogin;

  /// No description provided for @lblSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get lblSearch;

  /// No description provided for @lblSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get lblSearchPlaceholder;

  /// No description provided for @lblSearchPlaces.
  ///
  /// In en, this message translates to:
  /// **'Search places...'**
  String get lblSearchPlaces;

  /// No description provided for @lblSearchEvents.
  ///
  /// In en, this message translates to:
  /// **'Search events...'**
  String get lblSearchEvents;

  /// No description provided for @lblDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get lblDistance;

  /// Distance in kilometers
  ///
  /// In en, this message translates to:
  /// **'{distance} km'**
  String lblDistanceKm(String distance);

  /// No description provided for @lblAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get lblAll;

  /// No description provided for @lblFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get lblFilter;

  /// No description provided for @lblSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get lblSort;

  /// No description provided for @lblDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get lblDate;

  /// No description provided for @lblTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get lblTime;

  /// No description provided for @lblPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get lblPrice;

  /// No description provided for @lblFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get lblFree;

  /// No description provided for @lblPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get lblPaid;

  /// No description provided for @lblCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get lblCategory;

  /// No description provided for @lblLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get lblLanguage;

  /// No description provided for @lblSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get lblSettings;

  /// No description provided for @lblTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get lblTheme;

  /// No description provided for @lblLightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lblLightMode;

  /// No description provided for @lblDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get lblDarkMode;

  /// No description provided for @lblSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get lblSystemDefault;

  /// No description provided for @lblNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get lblNotifications;

  /// No description provided for @lblPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get lblPrivacy;

  /// No description provided for @lblHelp.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get lblHelp;

  /// No description provided for @lblPoints.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get lblPoints;

  /// No description provided for @lblLevel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get lblLevel;

  /// No description provided for @lblVisits.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get lblVisits;

  /// No description provided for @lblRoutesDone.
  ///
  /// In en, this message translates to:
  /// **'Routes'**
  String get lblRoutesDone;

  /// Label: Member since date
  ///
  /// In en, this message translates to:
  /// **'Member since {date}'**
  String lblMemberSince(String date);

  /// No description provided for @sectionFeaturedPlaces.
  ///
  /// In en, this message translates to:
  /// **'Featured Places'**
  String get sectionFeaturedPlaces;

  /// No description provided for @sectionNearbyPlaces.
  ///
  /// In en, this message translates to:
  /// **'Nearby Places'**
  String get sectionNearbyPlaces;

  /// No description provided for @sectionUpcomingEvents.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Events'**
  String get sectionUpcomingEvents;

  /// No description provided for @sectionAnnouncements.
  ///
  /// In en, this message translates to:
  /// **'Announcements'**
  String get sectionAnnouncements;

  /// No description provided for @sectionTravelRoutes.
  ///
  /// In en, this message translates to:
  /// **'Travel Routes'**
  String get sectionTravelRoutes;

  /// No description provided for @sectionRecipes.
  ///
  /// In en, this message translates to:
  /// **'Recipes'**
  String get sectionRecipes;

  /// No description provided for @sectionLocalDelicacies.
  ///
  /// In en, this message translates to:
  /// **'Local Delicacies'**
  String get sectionLocalDelicacies;

  /// No description provided for @sectionActiveCampaigns.
  ///
  /// In en, this message translates to:
  /// **'Active Campaigns'**
  String get sectionActiveCampaigns;

  /// No description provided for @sectionAchievements.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get sectionAchievements;

  /// No description provided for @sectionCompletedRoutes.
  ///
  /// In en, this message translates to:
  /// **'Completed Routes'**
  String get sectionCompletedRoutes;

  /// No description provided for @titleEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get titleEvents;

  /// No description provided for @titlePlaces.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get titlePlaces;

  /// No description provided for @titleAnnouncements.
  ///
  /// In en, this message translates to:
  /// **'Announcements'**
  String get titleAnnouncements;

  /// No description provided for @titleProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get titleProfile;

  /// No description provided for @titleMyQrCode.
  ///
  /// In en, this message translates to:
  /// **'My QR Code'**
  String get titleMyQrCode;

  /// No description provided for @titleCampaigns.
  ///
  /// In en, this message translates to:
  /// **'Campaigns'**
  String get titleCampaigns;

  /// No description provided for @titleRoutes.
  ///
  /// In en, this message translates to:
  /// **'Travel Routes'**
  String get titleRoutes;

  /// No description provided for @titleCulture.
  ///
  /// In en, this message translates to:
  /// **'Culture & Events'**
  String get titleCulture;

  /// No description provided for @titleRecipes.
  ///
  /// In en, this message translates to:
  /// **'Recipes'**
  String get titleRecipes;

  /// No description provided for @titleMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get titleMap;

  /// No description provided for @heroWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Samsun'**
  String get heroWelcome;

  /// No description provided for @heroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Discover the pearl of the Black Sea'**
  String get heroSubtitle;

  /// No description provided for @errGenericTitle.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get errGenericTitle;

  /// No description provided for @errGenericMessage.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errGenericMessage;

  /// No description provided for @errNetworkTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection Error'**
  String get errNetworkTitle;

  /// No description provided for @errNetworkMessage.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and try again.'**
  String get errNetworkMessage;

  /// No description provided for @errNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get errNoResults;

  /// No description provided for @errNoEvents.
  ///
  /// In en, this message translates to:
  /// **'No events found'**
  String get errNoEvents;

  /// No description provided for @errNoPlaces.
  ///
  /// In en, this message translates to:
  /// **'No places found'**
  String get errNoPlaces;

  /// No description provided for @errLocationDisabled.
  ///
  /// In en, this message translates to:
  /// **'Location services are disabled'**
  String get errLocationDisabled;

  /// No description provided for @errLocationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied'**
  String get errLocationPermissionDenied;

  /// No description provided for @loadingMessage.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loadingMessage;

  /// No description provided for @successTitle.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get successTitle;

  /// No description provided for @confirmDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete?'**
  String get confirmDeleteTitle;

  /// No description provided for @confirmDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get confirmDeleteMessage;

  /// Places count label
  ///
  /// In en, this message translates to:
  /// **'{count} places'**
  String placesCount(int count);

  /// Events count label
  ///
  /// In en, this message translates to:
  /// **'{count} events'**
  String eventsCount(int count);

  /// Date range display
  ///
  /// In en, this message translates to:
  /// **'{start} - {end}'**
  String dateRange(String start, String end);

  /// No description provided for @btnGoBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get btnGoBack;

  /// No description provided for @btnStartRoute.
  ///
  /// In en, this message translates to:
  /// **'Start Route'**
  String get btnStartRoute;

  /// No description provided for @btnTriedRecipe.
  ///
  /// In en, this message translates to:
  /// **'I Tried This'**
  String get btnTriedRecipe;

  /// No description provided for @lblAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get lblAbout;

  /// No description provided for @lblNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get lblNotes;

  /// No description provided for @lblTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get lblTags;

  /// No description provided for @lblContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get lblContact;

  /// No description provided for @lblOpeningHours.
  ///
  /// In en, this message translates to:
  /// **'Opening Hours'**
  String get lblOpeningHours;

  /// No description provided for @lblPhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get lblPhotos;

  /// No description provided for @lblVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get lblVideo;

  /// No description provided for @lblPhotosAndVideo.
  ///
  /// In en, this message translates to:
  /// **'Photos & Video'**
  String get lblPhotosAndVideo;

  /// Review count label
  ///
  /// In en, this message translates to:
  /// **'{count} reviews'**
  String lblReviews(int count);

  /// No description provided for @lblDistanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get lblDistanceLabel;

  /// No description provided for @errPlaceNotFound.
  ///
  /// In en, this message translates to:
  /// **'Place not found'**
  String get errPlaceNotFound;

  /// No description provided for @errRouteNotFound.
  ///
  /// In en, this message translates to:
  /// **'Route not found'**
  String get errRouteNotFound;

  /// No description provided for @errRouteLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load route'**
  String get errRouteLoadFailed;

  /// No description provided for @errRoutesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load routes'**
  String get errRoutesLoadFailed;

  /// No description provided for @errAnnouncementNotFound.
  ///
  /// In en, this message translates to:
  /// **'Announcement not found'**
  String get errAnnouncementNotFound;

  /// No description provided for @errPageNotFound.
  ///
  /// In en, this message translates to:
  /// **'Page Not Found'**
  String get errPageNotFound;

  /// No description provided for @titleRouteAbout.
  ///
  /// In en, this message translates to:
  /// **'About Route'**
  String get titleRouteAbout;

  /// No description provided for @titleRouteFeatures.
  ///
  /// In en, this message translates to:
  /// **'Route Features'**
  String get titleRouteFeatures;

  /// No description provided for @titleRouteStops.
  ///
  /// In en, this message translates to:
  /// **'Route Stops'**
  String get titleRouteStops;

  /// No description provided for @titleRecipeAbout.
  ///
  /// In en, this message translates to:
  /// **'About Recipe'**
  String get titleRecipeAbout;

  /// No description provided for @titleRecipeDetail.
  ///
  /// In en, this message translates to:
  /// **'Recipe Details'**
  String get titleRecipeDetail;

  /// No description provided for @titleDigitalId.
  ///
  /// In en, this message translates to:
  /// **'Digital ID'**
  String get titleDigitalId;

  /// No description provided for @titleQrCode.
  ///
  /// In en, this message translates to:
  /// **'My QR Code'**
  String get titleQrCode;

  /// No description provided for @titleLocalDelicacies.
  ///
  /// In en, this message translates to:
  /// **'Local Delicacies'**
  String get titleLocalDelicacies;

  /// No description provided for @titlePopularPlaces.
  ///
  /// In en, this message translates to:
  /// **'Popular Places'**
  String get titlePopularPlaces;

  /// No description provided for @titleCompletedRoutes.
  ///
  /// In en, this message translates to:
  /// **'Completed Routes'**
  String get titleCompletedRoutes;

  /// No description provided for @lblPhotoSpots.
  ///
  /// In en, this message translates to:
  /// **'Photo Spots'**
  String get lblPhotoSpots;

  /// No description provided for @lblRestAreas.
  ///
  /// In en, this message translates to:
  /// **'Rest Areas'**
  String get lblRestAreas;

  /// No description provided for @lblUnnamedStop.
  ///
  /// In en, this message translates to:
  /// **'Unnamed Stop'**
  String get lblUnnamedStop;

  /// No description provided for @lblTotalDistance.
  ///
  /// In en, this message translates to:
  /// **'Total Distance'**
  String get lblTotalDistance;

  /// No description provided for @lblEarnedPoints.
  ///
  /// In en, this message translates to:
  /// **'Earned Points'**
  String get lblEarnedPoints;

  /// No description provided for @lblSampleData.
  ///
  /// In en, this message translates to:
  /// **'* Sample data - Real data coming from API'**
  String get lblSampleData;

  /// No description provided for @btnRegister.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get btnRegister;

  /// No description provided for @msgLoginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Login Successful'**
  String get msgLoginSuccess;

  /// No description provided for @msgInsufficientPoints.
  ///
  /// In en, this message translates to:
  /// **'Insufficient Points'**
  String get msgInsufficientPoints;

  /// No description provided for @badgeFirstStep.
  ///
  /// In en, this message translates to:
  /// **'First Step'**
  String get badgeFirstStep;

  /// No description provided for @badgeNatureFriend.
  ///
  /// In en, this message translates to:
  /// **'Nature Friend'**
  String get badgeNatureFriend;

  /// No description provided for @badgeCultureAmbassador.
  ///
  /// In en, this message translates to:
  /// **'Culture Ambassador'**
  String get badgeCultureAmbassador;

  /// No description provided for @badgeCompleteMuseums.
  ///
  /// In en, this message translates to:
  /// **'Complete museums'**
  String get badgeCompleteMuseums;

  /// No description provided for @badgeSuperCitizen.
  ///
  /// In en, this message translates to:
  /// **'Super Citizen'**
  String get badgeSuperCitizen;

  /// No description provided for @lblParkWalk.
  ///
  /// In en, this message translates to:
  /// **'Park Walk'**
  String get lblParkWalk;

  /// No description provided for @filterToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get filterToday;

  /// No description provided for @filterTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get filterTomorrow;

  /// No description provided for @filterThisWeekend.
  ///
  /// In en, this message translates to:
  /// **'This Weekend'**
  String get filterThisWeekend;

  /// No description provided for @filterCustomDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get filterCustomDate;

  /// No description provided for @filterDateRange.
  ///
  /// In en, this message translates to:
  /// **'Date Range'**
  String get filterDateRange;

  /// No description provided for @filterPriceRange.
  ///
  /// In en, this message translates to:
  /// **'Price Range'**
  String get filterPriceRange;

  /// No description provided for @filterFreeOnly.
  ///
  /// In en, this message translates to:
  /// **'Free Only'**
  String get filterFreeOnly;

  /// No description provided for @filterPaidOnly.
  ///
  /// In en, this message translates to:
  /// **'Paid Only'**
  String get filterPaidOnly;

  /// No description provided for @filterTitle.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filterTitle;

  /// No description provided for @filterReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get filterReset;

  /// No description provided for @lblEnableLocationServices.
  ///
  /// In en, this message translates to:
  /// **'Enable location services to see distances'**
  String get lblEnableLocationServices;

  /// No description provided for @lblGrantLocationPermission.
  ///
  /// In en, this message translates to:
  /// **'Grant location permission to see distances'**
  String get lblGrantLocationPermission;

  /// No description provided for @btnOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get btnOpenSettings;

  /// No description provided for @btnGrantPermission.
  ///
  /// In en, this message translates to:
  /// **'Grant Permission'**
  String get btnGrantPermission;

  /// No description provided for @subtitleDiscoverEvents.
  ///
  /// In en, this message translates to:
  /// **'Discover upcoming events'**
  String get subtitleDiscoverEvents;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'tr': return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
