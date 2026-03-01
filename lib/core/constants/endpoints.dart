class Endpoints {
  // Auth (Postman collection)
  static const String login = '/ecom/portal/login';
  static const String register = '/ecom/portal/register';
  static const String logout = '/ecom/portal/logout';
  static const String resetPassword = '/ecom/portal/reset/password';
  static const String verifyToken = '/ecom/portal/verify-token';
  static const String resendMailVerification = '/ecom/portal/resend/mail-verification';
  static const String verifyMobileCode = '/ecom/portal/verify/mobile-code';
  static const String resendMobileVerification = '/ecom/portal/resend/mobile-verification';
  static const String googleAuth = '/ecom/auth/google';
  static const String guestLogin = '/ecom/guest/login';

  // Design APIs
  static const String getPages = '/ecom/get/pages';
  static const String getPageComponents = '/ecom/get/component';
  static const String getOnboarding = '/ecom/get/onboarding';
  static const String getWelcomeMessage = '/ecom/get/welcome-message';
  // Profile APIs
  static const String getUserProfile = '/ecom/user/profile';
  // Address APIs
  static const String userAddress = '/ecom/user/address';
  // Master Data APIs
  static const String getCountryList = '/ecom/get/country-list';
  static const String getStateList = '/ecom/get/state-list';
  static const String getProvinceList = '/ecom/get/iq_provice-list';
  static const String getAvailableLanguage = '/ecom/get/language-list';
  
  // Product APIs
  static const String getProduct = '/ecom/get/product';
  static const String getProductCategory = '/ecom/get/product-category';
  static const String productWishList = '/ecom/product/wish-list';
  static const String productLite = '/ecom/get/variant/lite'; //fetch variants data based on selected attribute ids

  // Search APIs
  static const String searchProducts = '/ecom/get/product/filter-search';
  
  // Cart APIs
  static const String cart = '/ecom/product/cart';

  static Map<String, dynamic> withParams(Map<String, dynamic> params) => {
        'params': params,
      };
}
  

