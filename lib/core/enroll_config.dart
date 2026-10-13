/// Registration (enroll) constants, ported from config/enroll.php in regForPal.
class EnrollConfig {
  static const endpoints = {
    'pre_enroll': '/api/v1.0/register/PreEnroll',
    'enroll': '/api/v1.0/register/EnrollInMobileBanking',
    'resend': '/api/v1.0/register/resendActivationInfo',
  };

  // Response prefixes that mean success.
  static const successPreEnroll = 'Your uploaded images';
  static const successResend = 'Wait for resent SMS/email to arrive';

  // Signing key (Base64) for the Authorization header. Empty = unsigned ":<ts>:0".
  static const secretKey = '';

  // Form defaults.
  static const emailDomain = 'gmail.com';
  static const defaultPassword = 'Aa10203040##';
  static const defaultAddress = 'غزة';
  static const defaultCountry = '134'; // Palestine, used for issuance/nationality/country

  // The two image slots sent in one PreEnroll request.
  static const imageSlots = {
    'idImage': 'صورة الهوية',
    'personalImage': 'صورة شخصية',
  };

  // Dropdown sources. 'regions' is a fixed list; the rest come from the info API.
  static const regions = {'1': 'الضفة الغربية', '2': 'قطاع غزة'};

  // path + optional parent query key (child lists need the parent's id).
  static const lookups = {
    'countries': {'path': '/api/v1.0/info/countries'},
    'governorates': {'path': '/api/v1.0/info/governates', 'parent': 'region'},
    'cities': {'path': '/api/v1.0/info/cities', 'parent': 'govid'},
    'job_titles': {'path': '/api/v1.0/info/jobTitles'},
    'job_positions': {'path': '/api/v1.0/info/jobPositions', 'parent': 'titleId'},
  };

  static const timeoutSeconds = 60;
  static const imageMaxDimension = 1280;
  static const imageQuality = 70;
}
