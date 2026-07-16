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
  String get quickArScanner => 'AR Scanner';

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
  String get lblSearchAnnouncements => 'Search news...';

  @override
  String get lblSearchRoutes => 'Search routes...';

  @override
  String get lblSearchRecipes => 'Search recipes or restaurants...';

  @override
  String get lblDistance => 'Distance';

  @override
  String lblDistanceKm(String distance) {
    return '$distance km';
  }

  @override
  String get lblAll => 'All';

  @override
  String get lblSubcategories => 'Subcategories';

  @override
  String get btnClear => 'Clear';

  @override
  String get placesSubcategoryFilterHint => 'Narrow by subcategory';

  @override
  String placesSubcategoriesSelected(int count) {
    return '$count subcategories selected';
  }

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
  String get sectionDiscoveryRoutes => 'Discovery Routes';

  @override
  String get sectionCityGuideBlog => 'City Guide & Blog';

  @override
  String get titleBlog => 'City Guide & Blog';

  @override
  String get blogSearchHint => 'Search articles...';

  @override
  String get blogEmpty => 'No articles yet.';

  @override
  String blogReadMinutes(int min) {
    return '$min min read';
  }

  @override
  String get sectionNearbyPlaces => 'Nearby Places';

  @override
  String get sectionQuickAccess => 'Quick Access';

  @override
  String get sectionCategories => 'Categories';

  @override
  String get categoryHealthTourism => 'Health Tourism';

  @override
  String get categoryDiscoverSamsun => 'Discover Samsun';

  @override
  String get categoryGastronomy => 'Gastronomy';

  @override
  String get categoryHistoricalMuseums => 'Historic Sites & Museums';

  @override
  String get categoryNatureParks => 'Nature & Parks';

  @override
  String get categoryBeaches => 'Beaches';

  @override
  String get placesCategoryHealthTourismLabel => 'Health Tourism';

  @override
  String get placesCategoryDiscoverSamsunLabel => 'Discover Samsun';

  @override
  String get placesCategoryGastronomyLabel => 'Gastronomy';

  @override
  String get placesCategoryHistoricalMuseumsLabel => 'Historic Sites & Museums';

  @override
  String get placesCategoryNatureParksLabel => 'Nature & Parks';

  @override
  String get placesCategoryBeachesLabel => 'Beaches';

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
  String get titleNotifications => 'Notifications';

  @override
  String get lblNoNotifications => 'No notifications yet';

  @override
  String get lblNoNotificationsDesc =>
      'New announcements will appear here when they are sent as notifications.';

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
  String get heroSearchHint => 'Where would you like to go?';

  @override
  String get heroSearchAction => 'Search';

  @override
  String get errGenericTitle => 'Error';

  @override
  String get errGenericMessage => 'Something went wrong. Please try again.';

  @override
  String get errNetworkTitle => 'Connection Error';

  @override
  String get errNetworkMessage =>
      'Check your internet connection and try again.';

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
  String get authPhoneNotRegisteredTitle => 'No account for this number';

  @override
  String get authPhoneNotRegisteredBody =>
      'This phone number is not registered yet. Sign up to continue.';

  @override
  String get authPhoneNotRegisteredShort => 'This number is not registered.';

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
  String get lblEnableLocationServices =>
      'Enable location services to see distances';

  @override
  String get lblGrantLocationPermission =>
      'Grant location permission to see distances';

  @override
  String get btnOpenSettings => 'Open Settings';

  @override
  String get btnGrantPermission => 'Grant Permission';

  @override
  String get subtitleDiscoverEvents => 'Discover upcoming events';

  @override
  String get msgPointsGuestLoginGeneric =>
      'Sign in to view point offers and earn rewards';

  @override
  String msgPointsGuestLoginWithValue(int points) {
    return 'Sign in to earn +$points points';
  }

  @override
  String get settingsFavorites => 'My Favorites';

  @override
  String get settingsItineraries => 'My Itineraries';

  @override
  String get profileMyContent => 'My Content';

  @override
  String get settingsLegal => 'Legal';

  @override
  String get settingsLegalSubtitle => 'Privacy notice, privacy & terms';

  @override
  String get settingsAnalyticsTitle => 'Anonymous Usage Statistics';

  @override
  String get settingsAnalyticsSubtitle =>
      'Helps us understand which features are used most. No personal data is collected.';

  @override
  String get languageSheetTitle => 'Language / Dil';

  @override
  String get notifSheetTitle => 'Notification Settings';

  @override
  String get notifGeneralTitle => 'General Notifications';

  @override
  String get notifGeneralSubtitle => 'Turns all push notifications on/off';

  @override
  String get notifCampaignsTitle => 'Campaign Notifications';

  @override
  String get notifCampaignsSubtitle => 'New campaign and offer announcements';

  @override
  String get notifEventsTitle => 'Event Notifications';

  @override
  String get notifEventsSubtitle => 'Upcoming events and organizations';

  @override
  String get notifNearbyTitle => 'Places Near Me';

  @override
  String get notifNearbySubtitle => 'Get notified as you approach key areas';

  @override
  String get geofenceActiveInfo =>
      'You\'ll be automatically notified when you enter areas like Kavak or Atakum. You won\'t be notified again for the same area within 24 hours.';

  @override
  String get geofenceCheckNow => 'Check now';

  @override
  String get lblLastCheck => 'Last Check';

  @override
  String get geoLocationServicesOff => 'Location services are off';

  @override
  String get geoPermissionDenied => 'Location permission denied';

  @override
  String get geoPermissionDeniedForever =>
      'Location permission permanently denied';

  @override
  String get geoLocationNotYet => 'Location not obtained yet, will retry';

  @override
  String get geoServiceDisabled => 'Service disabled';

  @override
  String geoInsideZone(String name) {
    return 'You\'re in $name';
  }

  @override
  String get geoNoZone => 'You\'re not in any area';

  @override
  String geoLocationFailedWith(String error) {
    return 'Couldn\'t get location: $error';
  }

  @override
  String get lblFollowedDistrict => 'Followed District';

  @override
  String get dlgLocationPermissionTitle => 'Location Permission Required';

  @override
  String get dlgLocationPermissionBody =>
      'To receive notifications about tourist spots near you, you need to grant access to your location.\n\nPlease enable location permission in the app settings.';

  @override
  String get dlgNotifPermissionTitle => 'Notification Permission Required';

  @override
  String get dlgNotifPermissionBody =>
      'To enable notifications, you need to allow notification permission for this app in system settings.\n\nPlease enable notifications in the app settings.';

  @override
  String get btnOk => 'OK';

  @override
  String get btnGoToSettings => 'Go to Settings';

  @override
  String get btnGiveUp => 'Cancel';

  @override
  String get btnContinue => 'Continue';

  @override
  String get btnDeleteAccount => 'Delete My Account';

  @override
  String get deleteAccountWarnTitle => 'You\'re about to delete your account';

  @override
  String get deleteAccountIfYouDelete => 'If you delete your account:';

  @override
  String get deleteAccountBulletProfile =>
      'Your profile information is deleted';

  @override
  String get deleteAccountBulletFavorites =>
      'Your favorites and itineraries are lost';

  @override
  String get deleteAccountBulletHistory => 'Your visit history is anonymized';

  @override
  String get deleteAccountBulletNotifications =>
      'Your notification subscriptions are removed';

  @override
  String get deleteAccountReSignupNote =>
      'You can sign up again with the same phone number, but deleted data cannot be recovered.';

  @override
  String get lblReasonOptional => 'Reason (optional)';

  @override
  String get deleteAccountFinalTitle => 'Final Confirmation';

  @override
  String get deleteAccountConfirmWord => 'DELETE MY ACCOUNT';

  @override
  String deleteAccountConfirmPrompt(String word) {
    return 'This action is IRREVERSIBLE. To confirm, type \"$word\" in the box below:';
  }

  @override
  String get deleteAccountDoneTitle => 'Your account has been deleted';

  @override
  String deleteAccountDaysRemaining(int days) {
    return 'Your account will be permanently deleted in $days days. If you sign in again with the same number within this period, you can recover your account.';
  }

  @override
  String get deleteAccountMarkedGeneric =>
      'Your account has been marked for deletion. See you again.';

  @override
  String get deleteAccountFailed =>
      'Your account couldn\'t be deleted right now. Check your connection and try again.';

  @override
  String get deleteReasonNotUsing => 'I no longer use it';

  @override
  String get deleteReasonMissingFeatures =>
      'I couldn\'t find the features I expected';

  @override
  String get deleteReasonPrivacy => 'Privacy / data concerns';

  @override
  String get deleteReasonTooManyNotifs => 'Too many notifications';

  @override
  String get deleteReasonSwitchedApp => 'I switched to another app';

  @override
  String get deleteReasonPreferNotSay => 'Prefer not to say';

  @override
  String get btnExplore => 'Explore';

  @override
  String get btnLater => 'Later';

  @override
  String get geofenceToggleTitle => 'Places Near Me';

  @override
  String get geofenceToggleSubtitle => 'Get notified when you enter areas';

  @override
  String get notifPushTitle => 'Push Notifications';

  @override
  String get notifPushSubtitle => 'Announcement and campaign notifications';

  @override
  String get notifSubtitlePushAndNearby => 'Push and places near you are on';

  @override
  String get notifSubtitlePushOnly => 'Push notifications are on';

  @override
  String get notifSubtitleNearbyOnly => 'Places near me are on';

  @override
  String get notifSubtitleOff => 'Notifications are off';

  @override
  String get announcementsMuteTooltip => 'Mute notifications';

  @override
  String get announcementsUnmuteTooltip => 'Turn on notifications';

  @override
  String get announcementsMutedSnack =>
      'Notifications muted. You may miss important announcements.';

  @override
  String get announcementsUnmutedSnack => 'Notifications turned on';

  @override
  String get btnUndo => 'Undo';

  @override
  String get profileRegisteredUser => 'Registered User';

  @override
  String get staffLoginPrompt => 'Staff sign-in for POS operations.';

  @override
  String get staffLoginTitle => 'Staff Login';

  @override
  String get staffPanelTitle => 'Staff Panel';

  @override
  String get posCashier => 'Cashier';

  @override
  String get staffSwitchFacility => 'Switch facility';

  @override
  String get staffEnterCode => 'Enter Code';

  @override
  String get staffEnterCodeHint =>
      'Enter the 6-digit code on the customer\'s screen';

  @override
  String get btnVerify => 'Verify';

  @override
  String get staffEditTotal => 'Edit Total Amount';

  @override
  String get staffTotalPoints => 'Total Points';

  @override
  String get staffProfileTitle => 'Staff Profile';

  @override
  String get staffLogout => 'Sign Out';

  @override
  String get staffTotalTransactions => 'Total Transactions';

  @override
  String get staffProcessedPoints => 'Processed Points';

  @override
  String get staffPaymentApproval => 'Payment Approval';

  @override
  String posPriceTimesQty(int price, int qty) {
    return '$price points × $qty';
  }

  @override
  String get staffExtraFee => 'Extra fee';

  @override
  String get staffManualAmount => 'Manual Amount';

  @override
  String get staffTransactions => 'Transactions';

  @override
  String get staffScan => 'Scan';

  @override
  String get staffSelectFacility => 'Select facility';

  @override
  String get arViewDetail => 'View detail';

  @override
  String get arAddToPlan => 'Add to plan';

  @override
  String get arHttpsRequired => 'HTTPS is required for AR';

  @override
  String get arCardViewCamera => 'Card View (Camera)';

  @override
  String get arRadarView => 'Radar View';

  @override
  String get arBackToRadar => 'Back to radar view';

  @override
  String get arContinueCardView => 'Continue with Card View';

  @override
  String get arSceneTitle => 'AR Scene';

  @override
  String get arAligned => 'Aligned';

  @override
  String arActiveCount(int count) {
    return '$count active';
  }

  @override
  String get arPreviewModeBanner =>
      'Preview mode — showing unpublished points.';

  @override
  String get arCompassCalibrationBanner =>
      'Compass not calibrated. Move your phone in a figure-eight motion.';

  @override
  String arGpsAccuracyBanner(String accuracy) {
    return 'Low GPS accuracy ($accuracy m).';
  }

  @override
  String get arCloseModel => 'Close model';

  @override
  String get arModelLoading => 'Loading model…';

  @override
  String get arCameraInitFailed =>
      'Camera could not start. Check device support and permissions.';

  @override
  String get loginScreenTitle => 'Sign in to your account';

  @override
  String get loginScreenSubtitle => 'Sign in to access all features';

  @override
  String get qrWaitingConnection => 'Waiting for internet connection...';

  @override
  String get qrPaymentComplete => 'Payment Complete!';

  @override
  String get qrSpendPrompt =>
      'To spend points, let staff scan this at the register';

  @override
  String get qrNoCode => 'There is no QR code to show right now.';

  @override
  String get qrRefreshing => 'Refreshing QR...';

  @override
  String get authWelcome => 'Welcome';

  @override
  String get authLoginSubtitle =>
      'Securely sign in to your Samsun Metropolitan Municipality wallet.';

  @override
  String get lblPhoneNumber => 'Phone Number';

  @override
  String get valPhoneRequired => 'Please enter your phone number';

  @override
  String get valPhoneInvalid => 'Please enter a valid phone number';

  @override
  String get authOtpSendInfo =>
      'We\'ll send a one-time SMS code to verify your number.';

  @override
  String get otpAppBarTitle => 'Verification Code';

  @override
  String get otpVerifyPhoneTitle => 'Verify Your Phone';

  @override
  String get otpSentToLabel => 'A verification code was sent to:';

  @override
  String get lblRemainingTime => 'Remaining time';

  @override
  String get btnResendCode => 'Resend Code';

  @override
  String get otpPendingDeletionTitle =>
      'Your account is scheduled for deletion';

  @override
  String otpPendingDeletionBody(int days) {
    return 'A deletion request was received for this account. It will be permanently deleted in $days days.\n\nWould you like to restore your account? If you choose \"Cancel\", the deletion process continues.';
  }

  @override
  String get btnRestoreAccount => 'Restore My Account';

  @override
  String get accountRestoredMsg =>
      'Your account has been restored. Welcome back!';

  @override
  String get otpAccountDeletedTitle => 'Account deleted';

  @override
  String get otpAccountDeletedBody =>
      'The account for this phone number has been permanently deleted. To continue, you need to create a new account.';

  @override
  String get btnCreateNewAccount => 'Create New Account';

  @override
  String get registerSubtitle => 'Fill in your details to create your wallet.';

  @override
  String get lblFirstName => 'First Name';

  @override
  String get valFirstNameRequired => 'Please enter your first name';

  @override
  String get lblLastName => 'Last Name';

  @override
  String get valLastNameRequired => 'Please enter your last name';

  @override
  String get valEmailRequired => 'Please enter your email address';

  @override
  String get valEmailInvalid => 'Please enter a valid email address';

  @override
  String get legalClarificationText => 'Privacy Notice';

  @override
  String get legalTermsOfUse => 'Terms of Use';

  @override
  String get lblEmail => 'Email';

  @override
  String get registerConsentPrefix => 'I have read the ';

  @override
  String get registerConsentMid => ' and accept the ';

  @override
  String get registerConsentSuffix =>
      ', and give my explicit consent to the processing of my personal data.';

  @override
  String favRecordCount(int count) {
    return '$count items';
  }

  @override
  String get favEmptyPlaces => 'You have no favorite places yet';

  @override
  String get favEmptyRecipes => 'You have no favorite recipes yet';

  @override
  String get favEmptyRoutes => 'You have no favorite routes yet';

  @override
  String get favEmptyDelicacies => 'You have no favorite delicacies yet';

  @override
  String get favRemove => 'Remove from favorites';

  @override
  String get favHint =>
      'Tap the heart icon next to content to add it to your favorites.';

  @override
  String get itineraryDeleteTitle => 'Delete this plan?';

  @override
  String get btnDelete => 'Delete';

  @override
  String itineraryDeleteConfirm(String title) {
    return 'The plan \"$title\" will be permanently deleted.';
  }

  @override
  String get itineraryEmpty => 'You have no itineraries yet';

  @override
  String get itineraryEmptyHint =>
      'Use the \"New Plan\" button below to create your route and add the places and events you like.';

  @override
  String get sortRecommended => 'Recommended';

  @override
  String get sortByName => 'By name (A-Z)';

  @override
  String get sortPopularity => 'Popularity';

  @override
  String get sortProximity => 'Proximity';

  @override
  String get sortDuration => 'Duration';

  @override
  String get sortStopCount => 'Number of stops';

  @override
  String get sortRating => 'Rating';

  @override
  String get sortByDate => 'By date';

  @override
  String get routeModeWalking => 'Walking';

  @override
  String get routeModeBike => 'Cycling';

  @override
  String get routeModeCar => 'By car';

  @override
  String get routeDiffEasy => 'Easy';

  @override
  String get routeDiffMedium => 'Medium';

  @override
  String get routeDiffHard => 'Hard';

  @override
  String get routeLabelDefault => 'Route';

  @override
  String get permLocationTitle => 'Location Permission';

  @override
  String get permLocationDesc =>
      'We\'d like to access your location to show you the nearest places, events and map directions.';

  @override
  String get permLocationBullet1 =>
      'Tourist and cultural spots near you are listed.';

  @override
  String get permLocationBullet2 =>
      'Your location and directions are shown on the map.';

  @override
  String get permLocationBullet3 =>
      'Your location is used only for the service and never shared.';

  @override
  String get permLocationBgTitle => 'Nearby Place Notifications';

  @override
  String get permLocationBgDesc =>
      'Background location access is needed so we can notify you when you approach key areas (even while the phone is in your pocket). On the permission screen, please choose \"Allow all the time\".';

  @override
  String get permLocationBgBullet1 =>
      'You get notified when you approach tourist spots.';

  @override
  String get permLocationBgBullet2 =>
      'For this to work you must set location to \"Allow all the time\".';

  @override
  String get permLocationBgBullet3 =>
      'On some devices this option is set from the settings page; you can turn it off there anytime.';

  @override
  String get permNotifTitle => 'Notification Permission';

  @override
  String get permNotifDesc =>
      'We\'d like to send notifications so you stay informed about events, announcements and campaigns in the city.';

  @override
  String get permNotifBullet1 =>
      'New events and announcements arrive instantly.';

  @override
  String get permNotifBullet2 =>
      'You can select notification types individually in settings.';

  @override
  String get permNotifBullet3 => 'You can turn it off whenever you want.';

  @override
  String get permCameraTitle => 'Camera Permission';

  @override
  String get permCameraDesc =>
      'We need camera access for QR code scanning and the augmented reality (AR) experience.';

  @override
  String get permCameraBullet1 => 'You can scan QR codes at venues.';

  @override
  String get permCameraBullet2 =>
      'You can bring historic structures to life with AR.';

  @override
  String get permCameraBullet3 =>
      'The camera image is never sent off your device.';

  @override
  String get btnNotNow => 'Not Now';

  @override
  String get campaignUpcoming => 'Campaign Soon';

  @override
  String campaignUpcomingHint(int points) {
    return 'Wait for the campaign to earn +$points points';
  }

  @override
  String get campaignEnded => 'Campaign Ended';

  @override
  String pointsAmount(int points) {
    return '+$points Points';
  }

  @override
  String get pointsApproach => 'Get closer to the venue to earn points';

  @override
  String pointsApproachWithDist(String distance) {
    return 'Get closer to the venue to earn points ($distance away)';
  }

  @override
  String get almostThere => 'You\'re almost there!';

  @override
  String pointsApproachMore(int points, String distance) {
    return 'Get $distance closer for +$points points';
  }

  @override
  String get collectPoints => 'Collect Points!';

  @override
  String earnPoints(int points) {
    return 'Earn +$points points';
  }

  @override
  String get collectingPoints => 'Collecting points...';

  @override
  String routeCompletedBonus(int earned) {
    return 'Route Completed! +$earned Bonus Points';
  }

  @override
  String pointsEarnedExclaim(int earned) {
    return '+$earned Points Earned!';
  }

  @override
  String get errOccurred => 'An error occurred';

  @override
  String lblViewCount(int count) {
    return '$count views';
  }

  @override
  String get heroDiscoverSubtitle => 'Discover your city, join events';

  @override
  String get lblAddress => 'Address';

  @override
  String get badgeNew => 'New';

  @override
  String get badgeImportant => 'Important';

  @override
  String get onboardingStart => 'Get Started';

  @override
  String get onbSkip => 'Skip';

  @override
  String get onbContinue => 'Continue';

  @override
  String get onbWelcomeTitle => 'Welcome to Samsun';

  @override
  String get onbWelcomeDesc =>
      'Discover the city\'s history, culture and beauty in a single app. Let us introduce the map, AR, assistant and more in a few steps.';

  @override
  String get onbNavTitle => 'Easy Navigation';

  @override
  String get onbNavDesc =>
      'Reach everything with a few taps. The bar below takes you to the main sections, and the center button to the map.';

  @override
  String get onbNavBullet1Title => 'Bottom bar';

  @override
  String get onbNavBullet1Desc => 'Home, Places, News and Profile tabs.';

  @override
  String get onbNavBullet2Title => 'Center map button';

  @override
  String get onbNavBullet2Desc => 'Explore the city on a live map.';

  @override
  String get onbNavBullet3Title => '☰ menu at top left';

  @override
  String get onbNavBullet3Desc =>
      'All sections and the theme (Light/Dark/System) are set here.';

  @override
  String get onbNavBullet4Title => 'Assistant at top right';

  @override
  String get onbNavBullet4Desc => 'Ask the Samsun Assistant anything you want.';

  @override
  String get onbDiscoverTitle => 'Discover & Search';

  @override
  String get onbDiscoverDesc =>
      'The home screen offers a personalized live discovery feed; find what you\'re looking for quickly by category and location.';

  @override
  String get onbDiscoverBullet1Title => 'Nearby';

  @override
  String get onbDiscoverBullet1Desc =>
      'Places around you are listed automatically based on your location.';

  @override
  String get onbDiscoverBullet2Title => 'Personalized suggestions';

  @override
  String get onbDiscoverBullet2Desc =>
      'Content personalized to your interests.';

  @override
  String get onbDiscoverBullet3Title => 'Search & filter';

  @override
  String get onbDiscoverBullet3Desc =>
      'Filter quickly by category and location.';

  @override
  String get onbDiscoverBullet4Title => 'Itinerary';

  @override
  String get onbDiscoverBullet4Desc =>
      'Plan multiple stops in a single day route.';

  @override
  String get onbRewardsTitle => 'Save, Collect & Complete';

  @override
  String get onbRewardsDesc =>
      'Earn as you use the app. Save what you like, complete the places you visit and collect points.';

  @override
  String get onbRewardsBullet1Title => 'Add to favorites';

  @override
  String get onbRewardsBullet1Desc =>
      'Tap the heart to save content to your favorites.';

  @override
  String get onbRewardsBullet2Title => 'Complete';

  @override
  String get onbRewardsBullet2Desc =>
      'Mark \"I completed the place\" when you arrive, and complete the route when you finish it.';

  @override
  String get onbRewardsBullet3Title => 'Points & badges';

  @override
  String get onbRewardsBullet3Desc =>
      'Unlock badges and rewards with the points you collect.';

  @override
  String get onbRewardsBullet4Title => 'Daily login';

  @override
  String get onbRewardsBullet4Desc =>
      'Earn an extra reward every day you log in.';

  @override
  String get onbSaveTitle => 'Save & Quick Access';

  @override
  String get onbSaveDesc =>
      'Add the places, events and content you like to your favorites; reach them all from one place.';

  @override
  String get onbSaveBullet1Title => 'Add to favorites';

  @override
  String get onbSaveBullet1Desc =>
      'Tap the heart to save content to your favorites.';

  @override
  String get onbSaveBullet2Title => 'Collect in one list';

  @override
  String get onbSaveBullet2Desc =>
      'Places, Routes, Recipes and Delicacies in separate tabs.';

  @override
  String get onbSaveBullet3Title => 'Quick access';

  @override
  String get onbSaveBullet3Desc =>
      'Reach what you saved anytime with a single tap.';

  @override
  String get onbMapTitle => 'Map & Directions';

  @override
  String get onbMapDesc =>
      'See the city\'s key spots on the map and get directed to where you want to go with a single tap.';

  @override
  String get onbMapBullet1Title => 'Spots on the map';

  @override
  String get onbMapBullet1Desc =>
      'Tourist, cultural and social areas on the map.';

  @override
  String get onbMapBullet2Title => 'Heatmap';

  @override
  String get onbMapBullet2Desc => 'See the most visited areas at a glance.';

  @override
  String get onbMapBullet3Title => 'Directions';

  @override
  String get onbMapBullet3Desc =>
      'Navigate to your chosen place with your navigation app.';

  @override
  String get onbMapBullet4Title => 'Around me';

  @override
  String get onbMapBullet4Desc =>
      'Instantly see spots near your current location.';

  @override
  String get onbScanTitle => 'QR, AR & Assistant';

  @override
  String get onbScanDesc =>
      'Experience the city interactively: scan codes, bring history to life, or ask the assistant.';

  @override
  String get onbScanBullet1Title => 'Scan QR';

  @override
  String get onbScanBullet1Desc =>
      'Scan codes at venues to instantly access content.';

  @override
  String get onbScanBullet2Title => 'Bring to life with AR';

  @override
  String get onbScanBullet2Desc =>
      'Explore historic structures in radar, camera and 3D world mode.';

  @override
  String get onbScanBullet3Title => 'Samsun Assistant';

  @override
  String get onbScanBullet3Desc =>
      'Ask by typing; get instant answers from the app\'s information.';

  @override
  String get onbInterestsTitle => 'What Interests You?';

  @override
  String get onbInterestsDesc =>
      'You can make one or more selections so we can personalize suggestions for you. You can skip this step.';

  @override
  String get onbInterestHistoric => 'Historic Places';

  @override
  String get onbInterestCulture => 'Culture & Arts';

  @override
  String get onbInterestNature => 'Nature & Parks';

  @override
  String get onbInterestFood => 'Food & Drink';

  @override
  String get onbInterestEvents => 'Events';

  @override
  String get onbInterestRoutes => 'Travel Routes';

  @override
  String get onbInterestArQr => 'AR & QR Experience';

  @override
  String get onbInterestRecipes => 'Local Recipes';

  @override
  String get filterShowAll => 'Show all';

  @override
  String get filterFavoritesOnly => 'My favorites only';

  @override
  String get lblDuration => 'Duration';

  @override
  String get recipeLocal => 'Local';

  @override
  String get tapForDetails => 'Tap to see details';

  @override
  String get favPlacesEmptyOrNoMatch =>
      'You have no favorite places or no matching results were found.';

  @override
  String get emptyTryDifferent => 'Try a different category or search term';

  @override
  String get locationPermissionFromSettings =>
      'Location permission must be enabled in settings';

  @override
  String get errLocationFailed => 'Couldn\'t get location';

  @override
  String get placeMarkVisited => 'I visited here';

  @override
  String get placeMarkedVisited => 'Marked as visited.';

  @override
  String get placeUnmarkedVisited => 'Visit mark removed.';

  @override
  String get lblComingSoon => 'Coming soon';

  @override
  String get pointsCollected => 'Points Collected';

  @override
  String get arViewWith => 'View in AR';

  @override
  String get recipePreparation => 'Preparation';

  @override
  String get recipeLoadError => 'An error occurred while loading the recipe.';

  @override
  String get errRecipeNotFound => 'Recipe not found.';

  @override
  String get recipePrepTime => 'Prep';

  @override
  String get recipeServings => 'servings';

  @override
  String get recipeNoDescription =>
      'No description has been added for this recipe yet.';

  @override
  String get recipeTips => 'Tips';

  @override
  String get recipeFavEmptyOrNoMatch =>
      'You have no favorite recipes or no matching results were found.';

  @override
  String get recipeNoneToShow => 'No recipes to show right now.';

  @override
  String get delicaciesSubtitle => 'Traditional flavors of our city';

  @override
  String get delicaciesLoadError =>
      'An error occurred while loading local delicacies.';

  @override
  String get delicacyFavEmptyOrNoMatch =>
      'You have no favorite delicacies or no matching results were found.';

  @override
  String get delicacyNoneToShow => 'No local delicacies to show right now.';

  @override
  String get lblLocalDelicacy => 'Local Delicacy';

  @override
  String get delicacyLoadError =>
      'An error occurred while loading this delicacy.';

  @override
  String get delicacyNotFound => 'This delicacy was not found.';

  @override
  String get delicacyDetail => 'Delicacy Detail';

  @override
  String get tapToWatchVideo => 'Tap to watch the video';

  @override
  String get menuAbout => 'About the Menu';

  @override
  String get delicacyNoDescription =>
      'No description has been added for this delicacy yet.';

  @override
  String get delicacyRestaurantsSoon =>
      'Restaurants serving this delicacy will be added soon.';

  @override
  String get delicacyRestaurantsOnMap => 'View Restaurants on Map';

  @override
  String get delicacyShowPointsOnMap =>
      'Show the spots serving this menu on the map';

  @override
  String get routeCompleted => 'Route Completed!';

  @override
  String routeAllStopsBonus(int bonus) {
    return '+$bonus All Stops Bonus';
  }

  @override
  String routeCompletionBonus(int bonus) {
    return '+$bonus Completion Bonus';
  }

  @override
  String routeBonusPoints(int points) {
    return '+$points Bonus Points';
  }

  @override
  String get routeMarkCompleted => 'I completed this route';

  @override
  String get routeMarkedCompleted => 'Marked as route completed.';

  @override
  String get routeUnmarkedCompleted => 'Completion mark removed.';

  @override
  String get routeYourProgress => 'Your progress';

  @override
  String routeEarnPointsHint(int points) {
    return 'You can earn $points points by completing this route!';
  }

  @override
  String get routeView => 'View Route';

  @override
  String get cultureCatMuseum => 'Museum';

  @override
  String get cultureCatEvent => 'Event';

  @override
  String get cultureCatArt => 'Art';

  @override
  String get cultureCatTheater => 'Theater';

  @override
  String get cultureAllEvents => 'All Events';

  @override
  String lblResultCount(int count) {
    return '$count results';
  }

  @override
  String get cultureSections => 'Sections';

  @override
  String get cultureLocationContact => 'Location & Contact';

  @override
  String get cultureTicketRegistration => 'Ticket / Registration';

  @override
  String get cultureFreeEvent => 'Free Event';

  @override
  String get cultureFreeEventDesc =>
      'This event is free. No prior registration is required to attend.';

  @override
  String get cultureTicketContact =>
      'For ticket sales, please contact the event venue.';

  @override
  String get errEventNotFound => 'Event not found';

  @override
  String get lblVisitor => 'Visitor';

  @override
  String get lblOpen => 'Open';

  @override
  String get lblClosed => 'Closed';

  @override
  String get filterEventTitle => 'Event Filters';

  @override
  String get filterSubtitle => 'Easily find the events you\'re looking for';

  @override
  String get filterSelectDateRange => 'Select Date Range';

  @override
  String get filterSelectDateRangeHelp => 'Select a date range';

  @override
  String get filterStartDateHint => 'Start date';

  @override
  String get filterEndDateHint => 'End date';

  @override
  String get filterInvalidRange => 'Select a valid date range';

  @override
  String get filterFreeEventsOnly => 'Free Events Only';

  @override
  String get filterFreeEventsOnlyDesc => 'Show events you can attend for free';

  @override
  String get themeShortLight => 'Light';

  @override
  String get themeShortDark => 'Dark';

  @override
  String get themeShortSystem => 'System';

  @override
  String get drawerSlogan => 'Explore the city';

  @override
  String get drawerExplore => 'Explore';

  @override
  String get drawerViewProfile => 'View profile';

  @override
  String get drawerGuestSubtitle => 'Sign in or register';

  @override
  String get homeAroundMeAr => 'AR Around Me';

  @override
  String get mapNoPlacesInArea => 'No places to show in this area.';

  @override
  String get mapSearchHint => 'Search location or place...';

  @override
  String get lblEarned => 'Earned';

  @override
  String get staffMyTransactions => 'My Transactions';

  @override
  String get lblNotification => 'Notification';

  @override
  String get btnView => 'View';

  @override
  String lblErrorWith(String error) {
    return 'Error: $error';
  }

  @override
  String get docNotFound => 'Document not found.';

  @override
  String get sectionForYou => 'For You';

  @override
  String get sectionNearby => 'Nearby';

  @override
  String get sectionPopular => 'Popular';

  @override
  String get sectionNewlyAdded => 'Newly Added';

  @override
  String get lblMenu => 'Menu';

  @override
  String get qrCreateFailed => 'Couldn\'t create QR';

  @override
  String qrPointsSpent(int amount) {
    return '$amount points spent.';
  }

  @override
  String get lblLanguageShort => 'Language';

  @override
  String get itineraryNewButton => 'New Plan';

  @override
  String get itineraryNotFound => 'Plan not found';

  @override
  String get itineraryRename => 'Rename';

  @override
  String get itineraryAddPlace => 'Add Place';

  @override
  String get itineraryRenameTitle => 'Rename plan';

  @override
  String get itineraryNewName => 'New name';

  @override
  String get btnRemove => 'Remove';

  @override
  String get itineraryNoStops =>
      'You haven\'t added any stops to this plan yet';

  @override
  String get itinerarySelectPlace => 'Select Place';

  @override
  String get itinerarySearchPlace => 'Search places...';

  @override
  String get accountRestoredShort => 'Your account has been restored.';

  @override
  String get accountRestoreFailed =>
      'Account couldn\'t be restored. Please try again.';

  @override
  String get itineraryNewTitle => 'New Itinerary';

  @override
  String get itineraryNameLabel => 'Plan name';

  @override
  String get itineraryNameHint => 'e.g. Weekend Samsun tour';

  @override
  String get lblStart => 'Start';

  @override
  String get lblEnd => 'End';

  @override
  String get btnCreate => 'Create';

  @override
  String achievementsEarned(int unlocked, int total) {
    return '$unlocked / $total badges earned';
  }

  @override
  String get accountTitle => 'Account Details';

  @override
  String get accountContactSection => 'Contact information';

  @override
  String get accountNameLabel => 'Full name';

  @override
  String get accountPhoneLabel => 'Phone';

  @override
  String get accountEmailLabel => 'Email';

  @override
  String get accountEmailUnverified => 'Unverified';

  @override
  String get accountEmailVerified => 'Verified';

  @override
  String get accountNoEmail => 'No email added';

  @override
  String get accountVerifyEmail => 'Verify';

  @override
  String get accountAddEmail => 'Add email';

  @override
  String get accountChangeEmail => 'Change email';

  @override
  String get accountChangePhone => 'Change phone';

  @override
  String get emailVerifyTitle => 'Verify your email';

  @override
  String emailVerifySentTo(String email) {
    return 'We sent a 6-digit verification code to $email.';
  }

  @override
  String get emailVerifyCodeLabel => 'Verification code';

  @override
  String get emailVerifyConfirm => 'Verify';

  @override
  String get emailVerifyResend => 'Resend code';

  @override
  String get emailVerifySuccess => 'Your email has been verified.';

  @override
  String get emailVerifyWhyTitle => 'Why is this needed?';

  @override
  String get emailVerifyWhyBody =>
      'A verified email lets us securely confirm your identity when you want to change your phone number.';

  @override
  String get emailVerifyErrorInUseElsewhere =>
      'This email address is already verified on another account. For security, the same email can be verified on only one account. If this address is really yours, contact support; otherwise change your email from Account Details.';

  @override
  String get contactErrorEmailRequiredFirst =>
      'You need to add and verify your email address before you can continue.';

  @override
  String get contactErrorChangePending =>
      'There is a change request in progress. Please complete or cancel it first.';

  @override
  String get contactErrorInvalidCode =>
      'The code is incorrect. Please check and try again.';

  @override
  String get contactErrorCodeExpired =>
      'The code has expired. Please request a new one.';

  @override
  String get contactErrorTooManyAttempts =>
      'Too many incorrect attempts. Please try again later.';

  @override
  String get contactErrorRateLimited =>
      'Too many requests. Please wait a moment and try again.';

  @override
  String get contactErrorValueInUse =>
      'This information can\'t be used. Please try a different value.';

  @override
  String get contactErrorSameValue =>
      'The new value is the same as your current one.';

  @override
  String get contactErrorGeneric => 'Something went wrong. Please try again.';

  @override
  String get changeEmailTitle => 'Change email';

  @override
  String get addEmailTitle => 'Add email';

  @override
  String get changePhoneTitle => 'Change phone';

  @override
  String get changeEmailIntro =>
      'To confirm it\'s you, we\'ll first send a verification code to your phone.';

  @override
  String get changePhoneIntro =>
      'To confirm it\'s you, we\'ll first send a code to your verified email address.';

  @override
  String get changeContactSendCode => 'Send code';

  @override
  String get changeStepPhoneOtpLabel => 'Code sent to your phone';

  @override
  String get changeStepEmailCodeLabel => 'Code sent to your email';

  @override
  String get changeNewEmailLabel => 'New email address';

  @override
  String get changeNewEmailCodeLabel => 'Code sent to your new email';

  @override
  String get changeNewPhoneLabel => 'New phone number';

  @override
  String get changeNewPhoneHint => '+90 5xx xxx xx xx';

  @override
  String get changeNewPhoneInvalid => 'Enter a valid phone number.';

  @override
  String get changeNewPhoneOtpLabel => 'Code sent to your new number';

  @override
  String get changeEmailSuccess => 'Your email address has been updated.';

  @override
  String get addEmailSuccess =>
      'Your email address has been added and verified.';

  @override
  String get changePhoneSuccess => 'Your phone number has been updated.';

  @override
  String get changePhoneOtherDevicesNote =>
      'For your security, sessions on your other devices have been signed out.';

  @override
  String changeContactStepLabel(int current, int total) {
    return 'Step $current/$total';
  }

  @override
  String get emailRequiredGateTitle => 'Verify your email first';

  @override
  String get emailRequiredGateBody =>
      'To change your phone number you need a verified email address. Please add and verify your email first.';

  @override
  String get emailRequiredGateButton => 'Go to Account Details';

  @override
  String get btnNext => 'Continue';

  @override
  String get btnChange => 'Change';

  @override
  String get profileEmailNotVerified => 'Email not verified';

  @override
  String get filterSortTitle => 'Sort';

  @override
  String get emailClaimConfirmTitle => 'Email registered to another account';

  @override
  String get emailClaimConfirmBody =>
      'This email is registered to another number but not verified. Do you want to receive a verification code and link it to this account?';
}
