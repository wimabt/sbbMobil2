// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Samsun City Guide';

  @override
  String get navHome => 'Home';

  @override
  String get navMap => 'Map';

  @override
  String get navPlaces => 'Places';

  @override
  String get navAnnouncements => 'News';

  @override
  String get navProfile => 'Profile';

  @override
  String get navCulture => 'Culture';

  @override
  String get quickCampaigns => 'Campaigns';

  @override
  String get quickRoutes => 'Routes';

  @override
  String get quickFood => 'Food';

  @override
  String get quickEvents => 'Events';

  @override
  String get btnGetDirections => 'Get Directions';

  @override
  String get btnShowOnMap => 'View on Map';

  @override
  String get btnShare => 'Share';

  @override
  String get btnSave => 'Save';

  @override
  String get btnCancel => 'Cancel';

  @override
  String get btnClose => 'Close';

  @override
  String get btnRetry => 'Try Again';

  @override
  String get btnViewAll => 'View All';

  @override
  String get btnApply => 'Apply';

  @override
  String get btnClearFilters => 'Clear Filters';

  @override
  String get btnLogout => 'Sign Out';

  @override
  String get btnLogin => 'Sign In';

  @override
  String get lblSearch => 'Search';

  @override
  String get lblSearchPlaceholder => 'Search...';

  @override
  String get lblSearchPlaces => 'Search places...';

  @override
  String get lblSearchEvents => 'Search events...';

  @override
  String get lblDistance => 'Distance';

  @override
  String lblDistanceKm(String distance) {
    return '$distance km';
  }

  @override
  String get lblAll => 'All';

  @override
  String get lblFilter => 'Filter';

  @override
  String get lblSort => 'Sort';

  @override
  String get lblDate => 'Date';

  @override
  String get lblTime => 'Time';

  @override
  String get lblPrice => 'Price';

  @override
  String get lblFree => 'Free';

  @override
  String get lblPaid => 'Paid';

  @override
  String get lblCategory => 'Category';

  @override
  String get lblLanguage => 'Language';

  @override
  String get lblSettings => 'Settings';

  @override
  String get lblTheme => 'Theme';

  @override
  String get lblLightMode => 'Light Mode';

  @override
  String get lblDarkMode => 'Dark Mode';

  @override
  String get lblSystemDefault => 'System Default';

  @override
  String get lblNotifications => 'Notifications';

  @override
  String get lblPrivacy => 'Privacy';

  @override
  String get lblHelp => 'Help & Support';

  @override
  String get lblPoints => 'Points';

  @override
  String get lblLevel => 'Level';

  @override
  String get lblVisits => 'Visits';

  @override
  String get lblRoutesDone => 'Routes';

  @override
  String lblMemberSince(String date) {
    return 'Member since $date';
  }

  @override
  String get sectionFeaturedPlaces => 'Featured Places';

  @override
  String get sectionNearbyPlaces => 'Nearby Places';

  @override
  String get sectionUpcomingEvents => 'Upcoming Events';

  @override
  String get sectionAnnouncements => 'Announcements';

  @override
  String get sectionTravelRoutes => 'Travel Routes';

  @override
  String get sectionRecipes => 'Recipes';

  @override
  String get sectionLocalDelicacies => 'Local Delicacies';

  @override
  String get sectionActiveCampaigns => 'Active Campaigns';

  @override
  String get sectionAchievements => 'Achievements';

  @override
  String get sectionCompletedRoutes => 'Completed Routes';

  @override
  String get titleEvents => 'Events';

  @override
  String get titlePlaces => 'Places';

  @override
  String get titleAnnouncements => 'Announcements';

  @override
  String get titleProfile => 'My Profile';

  @override
  String get titleMyQrCode => 'My QR Code';

  @override
  String get titleCampaigns => 'Campaigns';

  @override
  String get titleRoutes => 'Travel Routes';

  @override
  String get titleCulture => 'Culture & Events';

  @override
  String get titleRecipes => 'Recipes';

  @override
  String get titleMap => 'Map';

  @override
  String get heroWelcome => 'Welcome to Samsun';

  @override
  String get heroSubtitle => 'Discover the pearl of the Black Sea';

  @override
  String get errGenericTitle => 'Error';

  @override
  String get errGenericMessage => 'Something went wrong. Please try again.';

  @override
  String get errNetworkTitle => 'Connection Error';

  @override
  String get errNetworkMessage => 'Check your internet connection and try again.';

  @override
  String get errNoResults => 'No results found';

  @override
  String get errNoEvents => 'No events found';

  @override
  String get errNoPlaces => 'No places found';

  @override
  String get errLocationDisabled => 'Location services are disabled';

  @override
  String get errLocationPermissionDenied => 'Location permission denied';

  @override
  String get loadingMessage => 'Loading...';

  @override
  String get successTitle => 'Success';

  @override
  String get confirmDeleteTitle => 'Are you sure you want to delete?';

  @override
  String get confirmDeleteMessage => 'This action cannot be undone.';

  @override
  String placesCount(int count) {
    return '$count places';
  }

  @override
  String eventsCount(int count) {
    return '$count events';
  }

  @override
  String dateRange(String start, String end) {
    return '$start - $end';
  }

  @override
  String get btnGoBack => 'Go Back';

  @override
  String get btnStartRoute => 'Start Route';

  @override
  String get btnTriedRecipe => 'I Tried This';

  @override
  String get lblAbout => 'About';

  @override
  String get lblNotes => 'Notes';

  @override
  String get lblTags => 'Tags';

  @override
  String get lblContact => 'Contact';

  @override
  String get lblOpeningHours => 'Opening Hours';

  @override
  String get lblPhotos => 'Photos';

  @override
  String get lblVideo => 'Video';

  @override
  String get lblPhotosAndVideo => 'Photos & Video';

  @override
  String lblReviews(int count) {
    return '$count reviews';
  }

  @override
  String get lblDistanceLabel => 'Distance';

  @override
  String get errPlaceNotFound => 'Place not found';

  @override
  String get errRouteNotFound => 'Route not found';

  @override
  String get errRouteLoadFailed => 'Failed to load route';

  @override
  String get errRoutesLoadFailed => 'Failed to load routes';

  @override
  String get errAnnouncementNotFound => 'Announcement not found';

  @override
  String get errPageNotFound => 'Page Not Found';

  @override
  String get titleRouteAbout => 'About Route';

  @override
  String get titleRouteFeatures => 'Route Features';

  @override
  String get titleRouteStops => 'Route Stops';

  @override
  String get titleRecipeAbout => 'About Recipe';

  @override
  String get titleRecipeDetail => 'Recipe Details';

  @override
  String get titleDigitalId => 'Digital ID';

  @override
  String get titleQrCode => 'My QR Code';

  @override
  String get titleLocalDelicacies => 'Local Delicacies';

  @override
  String get titlePopularPlaces => 'Popular Places';

  @override
  String get titleCompletedRoutes => 'Completed Routes';

  @override
  String get lblPhotoSpots => 'Photo Spots';

  @override
  String get lblRestAreas => 'Rest Areas';

  @override
  String get lblUnnamedStop => 'Unnamed Stop';

  @override
  String get lblTotalDistance => 'Total Distance';

  @override
  String get lblEarnedPoints => 'Earned Points';

  @override
  String get lblSampleData => '* Sample data - Real data coming from API';

  @override
  String get btnRegister => 'Sign Up';

  @override
  String get msgLoginSuccess => 'Login Successful';

  @override
  String get msgInsufficientPoints => 'Insufficient Points';

  @override
  String get badgeFirstStep => 'First Step';

  @override
  String get badgeNatureFriend => 'Nature Friend';

  @override
  String get badgeCultureAmbassador => 'Culture Ambassador';

  @override
  String get badgeCompleteMuseums => 'Complete museums';

  @override
  String get badgeSuperCitizen => 'Super Citizen';

  @override
  String get lblParkWalk => 'Park Walk';

  @override
  String get filterToday => 'Today';

  @override
  String get filterTomorrow => 'Tomorrow';

  @override
  String get filterThisWeekend => 'This Weekend';

  @override
  String get filterCustomDate => 'Select Date';

  @override
  String get filterDateRange => 'Date Range';

  @override
  String get filterPriceRange => 'Price Range';

  @override
  String get filterFreeOnly => 'Free Only';

  @override
  String get filterPaidOnly => 'Paid Only';

  @override
  String get filterTitle => 'Filters';

  @override
  String get filterReset => 'Reset';

  @override
  String get lblEnableLocationServices => 'Enable location services to see distances';

  @override
  String get lblGrantLocationPermission => 'Grant location permission to see distances';

  @override
  String get btnOpenSettings => 'Open Settings';

  @override
  String get btnGrantPermission => 'Grant Permission';

  @override
  String get subtitleDiscoverEvents => 'Discover upcoming events';
}
