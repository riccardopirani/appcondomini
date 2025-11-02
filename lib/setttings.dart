/// File di configurazione centralizzato per l'app Condominio
///
/// Tutte le configurazioni dell'app sono centralizzate qui per facilitare
/// la manutenzione e le modifiche.

class AppSettings {
  // Singleton pattern
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  // ==========================================
  // CONFIGURAZIONI SITO WEB
  // ==========================================

  /// URL base del sito WordPress
  static const String _urlSitoBase = 'https://www.new.portobellodigallura.it';

  /// Getter per URL base del sito
  String get urlSito => _urlSitoBase;

  /// URL della pagina "Dove siamo"
  String get urlDoveSiamo => '$_urlSitoBase/dove-siamo/';

  /// URL della pagina "Numeri utili"
  String get urlNumeriUtili => '$_urlSitoBase/numeri-util/';

  /// URL della pagina "Parco di Portobello" (Contatti)
  String get urlParcoPortobello => _urlSitoBase;

  /// URL della home page del sito
  String get urlHome => '$_urlSitoBase/';

  // ==========================================
  // API WORDPRESS
  // ==========================================

  /// Endpoint per il login WordPress
  String get urlLogin => '$_urlSitoBase/wp-login.php';

  /// Endpoint per l'admin WordPress
  String get urlAdmin => '$_urlSitoBase/wp-admin/';

  /// Endpoint per l'API REST WordPress
  String get urlApi => '$_urlSitoBase/wp-json/wp/v2/';

  /// Endpoint per i post
  String get urlPosts => '$_urlSitoBase/wp-json/wp/v2/posts';

  /// Endpoint per l'utente corrente
  String get urlMe => '$_urlSitoBase/wp-json/wp/v2/users/me';

  /// Endpoint per heartbeat admin
  String get urlHeartbeat =>
      '$_urlSitoBase/wp-admin/admin-ajax.php?action=heartbeat';

  /// Endpoint per menu items
  String get urlMenuItems => '$_urlSitoBase/wp-json/wp/v2/menu-items';

  /// Endpoint per admin AJAX
  String get urlAdminAjax => '$_urlSitoBase/wp-admin/admin-ajax.php';

  // ==========================================
  // CREDENZIALI E AUTENTICAZIONE
  // ==========================================

  /// Token JWT (variabile globale, gestita dinamicamente)
  String? jwtToken;

  /// App Password per l'autenticazione WordPress
  static const String appPassword = 'fCVv 7j1Y sQbP MWZZ fc1T 7XMe';

  /// Username admin per scaricare tutti i post
  static const String adminUsername = 'PdGadmin';

  /// App Password admin per scaricare tutti i post
  static const String adminAppPassword = 'fCVv 7j1Y sQbP MWZZ fc1T 7XMe';

  // ==========================================
  // API TRADUZIONI
  // ==========================================

  /// URL dell'API di traduzione MyMemory
  static const String translationApiUrl =
      'https://api.mymemory.translated.net/get';

  // ==========================================
  // WEB CAM E METEO
  // ==========================================

  /// URL webcam del porto
  static const String webcamPorto =
      'https://player.castr.com/live_c8ab600012f411f08aa09953068f9db6';

  /// URL webcam panoramica
  static const String webcamPanoramica =
      'https://player.castr.com/live_e63170f014a311f0bf78a9d871469680';

  /// URL stazione meteo
  static const String stazioneMeteo =
      'https://stazioni5.soluzionimeteo.it/portobellodigallura/';

  // ==========================================
  // EMAIL
  // ==========================================

  /// Email webmaster per contatti
  static const String emailWebmaster = 'webmaster@portobellodigallura.it';

  // ==========================================
  // PARAMETRI POST API
  // ==========================================

  /// Numero di post per pagina di default
  static const int postsPerPageDefault = 20;

  /// Numero massimo di post da recuperare
  static const int postsPerPageMax = 100;

  // ==========================================
  // USER AGENT
  // ==========================================

  /// User Agent per le richieste HTTP
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';

  // ==========================================
  // METODI UTILITY
  // ==========================================

  /// Costruisce l'URL completo per i post con parametri
  String buildPostsUrl({
    int? perPage,
    String? status,
    String? embed,
    String? orderby,
    String? order,
    int? author,
    int? category,
  }) {
    final params = <String>[];

    if (perPage != null) params.add('per_page=$perPage');
    if (status != null) params.add('status=$status');
    if (embed != null) params.add('_embed=$embed');
    if (orderby != null) params.add('orderby=$orderby');
    if (order != null) params.add('order=$order');
    if (author != null) params.add('author=$author');
    if (category != null) params.add('categories=$category');

    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    return '$urlPosts$query';
  }

  /// Verifica se il token JWT è valido
  bool get hasValidToken => jwtToken != null && jwtToken!.isNotEmpty;

  /// Pulisce il token JWT
  void clearToken() {
    jwtToken = null;
  }

  /// Imposta il token JWT
  void setToken(String token) {
    jwtToken = token;
  }
}

/// Istanza globale delle configurazioni
final appSettings = AppSettings.instance;
