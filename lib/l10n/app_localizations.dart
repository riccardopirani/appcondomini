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
      'porto_bello': 'Porto Bello di Gallura',
      'porto_di_gallura': 'Porto di Gallura',

      // Menu laterale
      'useful_sections': 'Sezioni Utili',
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
    },
    'en': {
      'app_title': 'Condo App',
      'porto_bello': 'Porto Bello di Gallura',
      'porto_di_gallura': 'Port of Gallura',

      // Side menu
      'useful_sections': 'Useful Sections',
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
    },
    'fr': {
      'app_title': 'App Condominium',
      'porto_bello': 'Porto Bello di Gallura',
      'porto_di_gallura': 'Port de Gallura',

      // Menu latéral
      'useful_sections': 'Sections Utiles',
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
    },
    'zh': {
      'app_title': '公寓应用',
      'porto_bello': 'Porto Bello di Gallura',
      'porto_di_gallura': '加卢拉港',

      // 侧边菜单
      'useful_sections': '实用部分',
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
