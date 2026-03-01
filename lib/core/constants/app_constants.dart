class AppConstants {
  // API URLs
  static const String baseUrl = 'https://kardosi.filesdna.com/';//  http://192.168.1.201:8017/
  static const String apiVersion = '';
  
  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String sessionIdKey = 'session_id';
  static const String userKey = 'user_data';
  static const String themeKey = 'app_theme';
  static const String currencyKey = 'user_currency';
  static const String currencyIdKey = 'user_currency_id';
  static const String favoritesKey = 'favorites';
  
  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
  
  // Pagination
  static const int defaultPageSize = 20;
  
  // App Info
  static const String appName = 'Kardosi'; // TODO: This should be localized in the app
  static const String appVersion = '1.0.4';
}

class AppStrings {
  // These are now handled by the localization system
  // Use AppLocalizations.of(context).stringKey instead
  
  // Promotional messages used in welcome section
  static const List<String> promoMessages = <String>[
    'signInToUnlockDeals',
    'freeDeliveryOver',
    'newArrivalsDaily',
    'extraOffSelectedStyles',
  ];
}
