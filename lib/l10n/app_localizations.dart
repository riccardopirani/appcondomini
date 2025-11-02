import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'it': {
      'app_title': 'Condominio App',
      'porto_bello': 'Portobello di Gallura',
      'porto_di_gallura': 'Porto di Gallura',

      // Menu laterale
      'useful_sections': 'Sito online',
      'links_and_resources': 'Link e risorse',
      'contacts': 'Contatti',
      'contact_the_port': 'Contatta il porto',
      'account': 'Account',
      'manage_your_account': 'Gestisci il tuo account',
      'app_info': 'Informazioni App',
      'version_and_details': 'Versione e dettagli',
      'language': 'Lingua',
      'choose_language': 'Seleziona lingua',
      'logout': 'Logout',
      'menu': 'Menu',

      // Schermata Home
      'home': 'Home',
      'services': 'Servizi',
      'articles': 'Articoli',

      // Articoli
      'article_categories': 'Categorie Articoli',
      'search_articles': 'Cerca negli articoli...',
      'no_articles_found': 'Nessun articolo trovato',
      'try_modify_filters': 'Prova a modificare i filtri di ricerca',
      'articles_in': 'articoli in',
      'status': 'Status',
      'all': 'Tutti',
      'public': 'Pubblico',
      'private': 'Privato',
      'reset': 'Reset',
      'without_category': 'Senza categoria',

      // Login
      'login': 'Accedi',
      'username': 'Nome utente',
      'password': 'Password',
      'remember_me': 'Ricordami',
      'enter_credentials': 'Inserisci le tue credenziali',
      'enter_username': 'Inserisci il tuo nome utente',
      'enter_password': 'Inserisci la tua password',
      'logging_in': 'Accesso in corso...',
      'login_error': 'Errore di accesso',
      'ok': 'OK',

      // Messaggi
      'loading': 'Caricamento...',
      'error': 'Errore',
      'success': 'Successo',

      // Lingue
      'italian': 'Italiano',
      'english': 'Inglese',
      'french': 'Francese',
      'chinese': 'Cinese',

      // WebCam
      'webcam_live': 'Webcam Live',
      'realtime_monitoring': 'Monitoraggio in Tempo Reale',
      'view_webcams_weather': 'Visualizza le webcam e i dati meteo del Porto',
      'port_webcam': 'Webcam Porto',
      'direct_port_view': 'Vista diretta del porto',
      'monitor_port_activity': 'Monitora l\'attività del porto in tempo reale',
      'panoramic_webcam': 'Webcam Panoramica',
      'panoramic_360_view': 'Vista a 360° del territorio',
      'enjoy_panoramic_view': 'Goditi la vista panoramica del paesaggio',
      'weather_station': 'Stazione Meteo',
      'weather_data': 'Dati meteorologici',
      'check_weather_conditions':
          'Consulta temperatura, vento e condizioni meteo',

      // Servizi
      'contact_port': 'Contatta il Porto',
      'select_service': 'Seleziona il servizio',
      'gas_cylinders': 'Bombole Gas',
      'waste': 'Rifiuti',
      'malfunction': 'Guasto',
      'port': 'Porto',
      'fill_required_fields': 'Compila tutti i campi obbligatori',
      'name': 'Nome',
      'email': 'Email',
      'phone': 'Telefono',
      'subject': 'Oggetto',
      'message': 'Messaggio',
      'send_message': 'Invia un messaggio',
      'send': 'Invia',
      'name_required': 'Nome *',
      'email_required': 'Email *',
      'phone_optional': 'Telefono',
      'message_required': 'Messaggio *',
    },
    'en': {
      'app_title': 'Condo App',
      'porto_bello': 'Portobello di Gallura',
      'porto_di_gallura': 'Port of Gallura',

      // Side menu
      'useful_sections': 'Online Site',
      'links_and_resources': 'Links and resources',
      'contacts': 'Contacts',
      'contact_the_port': 'Contact the port',
      'account': 'Account',
      'manage_your_account': 'Manage your account',
      'app_info': 'App Information',
      'version_and_details': 'Version and details',
      'language': 'Language',
      'choose_language': 'Select language',
      'logout': 'Logout',
      'menu': 'Menu',

      // Home screen
      'home': 'Home',
      'services': 'Services',
      'articles': 'Articles',

      // Articles
      'article_categories': 'Article Categories',
      'search_articles': 'Search in articles...',
      'no_articles_found': 'No articles found',
      'try_modify_filters': 'Try modifying search filters',
      'articles_in': 'articles in',
      'status': 'Status',
      'all': 'All',
      'public': 'Public',
      'private': 'Private',
      'reset': 'Reset',
      'without_category': 'Without category',

      // Login
      'login': 'Login',
      'username': 'Username',
      'password': 'Password',
      'remember_me': 'Remember me',
      'enter_credentials': 'Enter your credentials',
      'enter_username': 'Enter your username',
      'enter_password': 'Enter your password',
      'logging_in': 'Logging in...',
      'login_error': 'Login error',
      'ok': 'OK',

      // Messages
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',

      // Languages
      'italian': 'Italian',
      'english': 'English',
      'french': 'French',
      'chinese': 'Chinese',

      // WebCam
      'webcam_live': 'Live Webcam',
      'realtime_monitoring': 'Real-Time Monitoring',
      'view_webcams_weather': 'View the webcams and weather data of the Port',
      'port_webcam': 'Port Webcam',
      'direct_port_view': 'Direct view of the port',
      'monitor_port_activity': 'Monitor port activity in real time',
      'panoramic_webcam': 'Panoramic Webcam',
      'panoramic_360_view': '360° view of the territory',
      'enjoy_panoramic_view': 'Enjoy the panoramic view of the landscape',
      'weather_station': 'Weather Station',
      'weather_data': 'Weather data',
      'check_weather_conditions':
          'Check temperature, wind and weather conditions',

      // Services
      'contact_port': 'Contact the Port',
      'select_service': 'Select service',
      'gas_cylinders': 'Gas Cylinders',
      'waste': 'Waste',
      'malfunction': 'Malfunction',
      'port': 'Port',
      'fill_required_fields': 'Fill all required fields',
      'name': 'Name',
      'email': 'Email',
      'phone': 'Phone',
      'subject': 'Subject',
      'message': 'Message',
      'send_message': 'Send a message',
      'send': 'Send',
      'name_required': 'Name *',
      'email_required': 'Email *',
      'phone_optional': 'Phone',
      'message_required': 'Message *',
    },
    'fr': {
      'app_title': 'App Condominium',
      'porto_bello': 'Portobello di Gallura',
      'porto_di_gallura': 'Port de Gallura',

      // Menu latéral
      'useful_sections': 'Site en ligne',
      'links_and_resources': 'Liens et ressources',
      'contacts': 'Contacts',
      'contact_the_port': 'Contactez le port',
      'account': 'Compte',
      'manage_your_account': 'Gérez votre compte',
      'app_info': 'Informations App',
      'version_and_details': 'Version et détails',
      'language': 'Langue',
      'choose_language': 'Sélectionner la langue',
      'logout': 'Déconnexion',
      'menu': 'Menu',

      // Écran d\'accueil
      'home': 'Accueil',
      'services': 'Services',
      'articles': 'Articles',

      // Articles
      'article_categories': 'Catégories d\'Articles',
      'search_articles': 'Rechercher dans les articles...',
      'no_articles_found': 'Aucun article trouvé',
      'try_modify_filters': 'Essayez de modifier les filtres de recherche',
      'articles_in': 'articles dans',
      'status': 'Statut',
      'all': 'Tous',
      'public': 'Public',
      'private': 'Privé',
      'reset': 'Réinitialiser',
      'without_category': 'Sans catégorie',

      // Connexion
      'login': 'Connexion',
      'username': 'Nom d\'utilisateur',
      'password': 'Mot de passe',
      'remember_me': 'Se souvenir de moi',
      'enter_credentials': 'Entrez vos identifiants',
      'enter_username': 'Entrez votre nom d\'utilisateur',
      'enter_password': 'Entrez votre mot de passe',
      'logging_in': 'Connexion en cours...',
      'login_error': 'Erreur de connexion',
      'ok': 'OK',

      // Messages
      'loading': 'Chargement...',
      'error': 'Erreur',
      'success': 'Succès',

      // Langues
      'italian': 'Italien',
      'english': 'Anglais',
      'french': 'Français',
      'chinese': 'Chinois',

      // WebCam
      'webcam_live': 'Webcam en Direct',
      'realtime_monitoring': 'Surveillance en Temps Réel',
      'view_webcams_weather':
          'Visualisez les webcams et les données météo du Port',
      'port_webcam': 'Webcam du Port',
      'direct_port_view': 'Vue directe du port',
      'monitor_port_activity': 'Surveillez l\'activité du port en temps réel',
      'panoramic_webcam': 'Webcam Panoramique',
      'panoramic_360_view': 'Vue à 360° du territoire',
      'enjoy_panoramic_view': 'Profitez de la vue panoramique du paysage',
      'weather_station': 'Station Météo',
      'weather_data': 'Données météorologiques',
      'check_weather_conditions':
          'Consultez la température, le vent et les conditions météo',

      // Services
      'contact_port': 'Contacter le Port',
      'select_service': 'Sélectionner le service',
      'gas_cylinders': 'Bouteilles de Gaz',
      'waste': 'Déchets',
      'malfunction': 'Panne',
      'port': 'Port',
      'fill_required_fields': 'Remplir tous les champs obligatoires',
      'name': 'Nom',
      'email': 'Email',
      'phone': 'Téléphone',
      'subject': 'Objet',
      'message': 'Message',
      'send_message': 'Envoyer un message',
      'send': 'Envoyer',
      'name_required': 'Nom *',
      'email_required': 'Email *',
      'phone_optional': 'Téléphone',
      'message_required': 'Message *',
    },
    'zh': {
      'app_title': '公寓应用',
      'porto_bello': 'Portobello di Gallura',
      'porto_di_gallura': '加卢拉港',

      // 侧边菜单
      'useful_sections': '在线网站',
      'links_and_resources': '链接和资源',
      'contacts': '联系方式',
      'contact_the_port': '联系港口',
      'account': '账户',
      'manage_your_account': '管理您的账户',
      'app_info': '应用信息',
      'version_and_details': '版本和详情',
      'language': '语言',
      'choose_language': '选择语言',
      'logout': '登出',
      'menu': '菜单',

      // 主屏幕
      'home': '主页',
      'services': '服务',
      'articles': '文章',

      // 文章
      'article_categories': '文章分类',
      'search_articles': '搜索文章...',
      'no_articles_found': '未找到文章',
      'try_modify_filters': '尝试修改搜索过滤器',
      'articles_in': '篇文章在',
      'status': '状态',
      'all': '全部',
      'public': '公开',
      'private': '私密',
      'reset': '重置',
      'without_category': '无分类',

      // 登录
      'login': '登录',
      'username': '用户名',
      'password': '密码',
      'remember_me': '记住我',
      'enter_credentials': '输入您的凭据',
      'enter_username': '输入您的用户名',
      'enter_password': '输入您的密码',
      'logging_in': '登录中...',
      'login_error': '登录错误',
      'ok': '确定',

      // 消息
      'loading': '加载中...',
      'error': '错误',
      'success': '成功',

      // 语言
      'italian': '意大利语',
      'english': '英语',
      'french': '法语',
      'chinese': '中文',

      // 网络摄像头
      'webcam_live': '实时网络摄像头',
      'realtime_monitoring': '实时监控',
      'view_webcams_weather': '查看港口的网络摄像头和天气数据',
      'port_webcam': '港口摄像头',
      'direct_port_view': '港口直接视图',
      'monitor_port_activity': '实时监控港口活动',
      'panoramic_webcam': '全景摄像头',
      'panoramic_360_view': '360°领土视图',
      'enjoy_panoramic_view': '欣赏全景风景',
      'weather_station': '气象站',
      'weather_data': '气象数据',
      'check_weather_conditions': '查看温度、风力和天气状况',

      // 服务
      'contact_port': '联系港口',
      'select_service': '选择服务',
      'gas_cylinders': '煤气瓶',
      'waste': '垃圾',
      'malfunction': '故障',
      'port': '港口',
      'fill_required_fields': '填写所有必填字段',
      'name': '姓名',
      'email': '电子邮件',
      'phone': '电话',
      'subject': '主题',
      'message': '消息',
      'send_message': '发送消息',
      'send': '发送',
      'name_required': '姓名 *',
      'email_required': '电子邮件 *',
      'phone_optional': '电话',
      'message_required': '消息 *',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }

  // Getter methods for easy access
  String get appTitle => translate('app_title');
  String get portoBello => translate('porto_bello');
  String get portoDiGallura => translate('porto_di_gallura');
  String get usefulSections => translate('useful_sections');
  String get linksAndResources => translate('links_and_resources');
  String get contacts => translate('contacts');
  String get contactThePort => translate('contact_the_port');
  String get account => translate('account');
  String get manageYourAccount => translate('manage_your_account');
  String get appInfo => translate('app_info');
  String get versionAndDetails => translate('version_and_details');
  String get language => translate('language');
  String get chooseLanguage => translate('choose_language');
  String get logout => translate('logout');
  String get menu => translate('menu');
  String get home => translate('home');
  String get services => translate('services');
  String get articles => translate('articles');
  String get articleCategories => translate('article_categories');
  String get searchArticles => translate('search_articles');
  String get noArticlesFound => translate('no_articles_found');
  String get tryModifyFilters => translate('try_modify_filters');
  String get articlesIn => translate('articles_in');
  String get status => translate('status');
  String get all => translate('all');
  String get public => translate('public');
  String get private => translate('private');
  String get reset => translate('reset');
  String get withoutCategory => translate('without_category');
  String get login => translate('login');
  String get username => translate('username');
  String get password => translate('password');
  String get rememberMe => translate('remember_me');
  String get enterCredentials => translate('enter_credentials');
  String get enterUsername => translate('enter_username');
  String get enterPassword => translate('enter_password');
  String get loggingIn => translate('logging_in');
  String get loginError => translate('login_error');
  String get ok => translate('ok');
  String get loading => translate('loading');
  String get error => translate('error');
  String get success => translate('success');
  String get italian => translate('italian');
  String get english => translate('english');
  String get french => translate('french');
  String get chinese => translate('chinese');

  // WebCam
  String get webcamLive => translate('webcam_live');
  String get realtimeMonitoring => translate('realtime_monitoring');
  String get viewWebcamsWeather => translate('view_webcams_weather');
  String get portWebcam => translate('port_webcam');
  String get directPortView => translate('direct_port_view');
  String get monitorPortActivity => translate('monitor_port_activity');
  String get panoramicWebcam => translate('panoramic_webcam');
  String get panoramic360View => translate('panoramic_360_view');
  String get enjoyPanoramicView => translate('enjoy_panoramic_view');
  String get weatherStation => translate('weather_station');
  String get weatherData => translate('weather_data');
  String get checkWeatherConditions => translate('check_weather_conditions');

  // Services
  String get contactPort => translate('contact_port');
  String get selectService => translate('select_service');
  String get gasCylinders => translate('gas_cylinders');
  String get waste => translate('waste');
  String get malfunction => translate('malfunction');
  String get port => translate('port');
  String get fillRequiredFields => translate('fill_required_fields');
  String get name => translate('name');
  String get email => translate('email');
  String get phone => translate('phone');
  String get subject => translate('subject');
  String get message => translate('message');
  String get sendMessage => translate('send_message');
  String get send => translate('send');
  String get nameRequired => translate('name_required');
  String get emailRequired => translate('email_required');
  String get phoneOptional => translate('phone_optional');
  String get messageRequired => translate('message_required');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['it', 'en', 'fr', 'zh'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
