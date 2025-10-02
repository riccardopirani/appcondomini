import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'l10n/app_localizations.dart';
import 'language_provider.dart';

String? jwtToken;
String urlSito = 'https://www.new.portobellodigallura.it';
String appPassword = 'oNod nxLF mW9Y vMkv DQrU wKwi';

// Cache per le traduzioni
final Map<String, Map<String, String>> _translationCache = {};

const String _translationApiUrl = 'https://api.mymemory.translated.net/get';

// Funzione per tradurre il testo usando MyMemory Translation API
Future<String> translateText(String text, String targetLanguage) async {
  // Se la lingua target è italiano, ritorna il testo originale
  if (targetLanguage == 'it') {
    return text;
  }

  // Controlla se la traduzione è già in cache
  if (_translationCache.containsKey(targetLanguage) &&
      _translationCache[targetLanguage]!.containsKey(text)) {
    return _translationCache[targetLanguage]![text]!;
  }

  try {
    // Rimuovi i tag HTML prima della traduzione
    String cleanText = text
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'&[a-z]+;'), '')
        .trim();

    if (cleanText.isEmpty) return text;

    // Limita la lunghezza del testo per evitare timeout (max 5000 caratteri)
    if (cleanText.length > 5000) {
      cleanText = cleanText.substring(0, 5000);
    }

    // Chiamata API MyMemory (GET request)
    final uri = Uri.parse(_translationApiUrl).replace(queryParameters: {
      'q': cleanText,
      'langpair': 'it|$targetLanguage',
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      // MyMemory ritorna responseData.translatedText
      // responseStatus può essere int o String
      final responseStatus = data['responseStatus'];
      final statusOk = responseStatus == 200 || responseStatus == '200';
      
      if (statusOk && data['responseData'] != null && data['responseData']['translatedText'] != null) {
        final translatedText = data['responseData']['translatedText'] as String;
        
        // Debug per verificare la traduzione
        debugPrint('Tradotto: "${text.substring(0, text.length > 50 ? 50 : text.length)}" → "${translatedText.substring(0, translatedText.length > 50 ? 50 : translatedText.length)}"');

        // Salva in cache
        if (!_translationCache.containsKey(targetLanguage)) {
          _translationCache[targetLanguage] = {};
        }
        _translationCache[targetLanguage]![text] = translatedText;

        return translatedText;
      } else {
        debugPrint('Errore traduzione MyMemory: status=$responseStatus, details=${data['responseDetails']}');
        return text;
      }
    } else {
      debugPrint('Errore API MyMemory: ${response.statusCode} - ${response.body}');
      return text;
    }
  } catch (e) {
    debugPrint('Errore traduzione: $e');
    // In caso di errore, ritorna il testo originale
    return text;
  }
}

// Funzione per tradurre i post
Future<Map<String, dynamic>> translatePost(
    Map<String, dynamic> post, String targetLanguage) async {
  if (targetLanguage == 'it') {
    return post;
  }

  try {
    final translatedPost = Map<String, dynamic>.from(post);

    // Traduci il titolo
    if (post['title']?['rendered'] != null) {
      final originalTitle = decodeHtmlEntities(post['title']['rendered']);
      final translatedTitle =
          await translateText(originalTitle, targetLanguage);
      translatedPost['title'] = {'rendered': translatedTitle};
    }

    // Traduci l'excerpt
    if (post['excerpt']?['rendered'] != null) {
      final originalExcerpt = decodeHtmlEntities(post['excerpt']['rendered']);
      final translatedExcerpt =
          await translateText(originalExcerpt, targetLanguage);
      translatedPost['excerpt'] = {'rendered': translatedExcerpt};
    }

    // Traduci il contenuto
    if (post['content']?['rendered'] != null) {
      final originalContent = decodeHtmlEntities(post['content']['rendered']);
      final translatedContent =
          await translateText(originalContent, targetLanguage);
      translatedPost['content'] = {'rendered': translatedContent};
    }

    return translatedPost;
  } catch (e) {
    debugPrint('Errore traduzione post: $e');
    return post;
  }
}

Future<void> sendEmail({
  required String to,
  String? subject,
  String? body,
}) async {
  final uri = Uri(
    scheme: 'mailto',
    path: to,
    queryParameters: {
      if (subject != null) 'subject': subject,
      if (body != null) 'body': body,
    },
  );

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    // mostra un messaggio all'utente
  }
}

// Funzione per creare l'autenticazione Basic Auth
String createBasicAuth(String username, String password) {
  final credentials = '$username:$password';
  final encoded = base64Encode(utf8.encode(credentials));
  return 'Basic $encoded';
}

// Funzione per decodificare le entità HTML nei testi
String decodeHtmlEntities(String htmlString) {
  if (htmlString.isEmpty) return htmlString;

  // Mappa delle entità HTML più comuni
  final Map<String, String> htmlEntities = {
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&apos;': "'",
    '&nbsp;': ' ',
    '&ndash;': '–',
    '&mdash;': '—',
    '&hellip;': '…',
    '&lsquo;': ''',
    '&rsquo;': ''',
    '&ldquo;': '"',
    '&rdquo;': '"',
    '&bull;': '•',
    '&copy;': '©',
    '&reg;': '®',
    '&trade;': '™',
    '&euro;': '€',
    '&pound;': '£',
    '&yen;': '¥',
    '&cent;': '¢',
    '&sect;': '§',
    '&para;': '¶',
    '&middot;': '·',
    '&deg;': '°',
    '&plusmn;': '±',
    '&times;': '×',
    '&divide;': '÷',
    '&frac14;': '¼',
    '&frac12;': '½',
    '&frac34;': '¾',
    '&sup1;': '¹',
    '&sup2;': '²',
    '&sup3;': '³',
    '&ordm;': 'º',
    '&ordf;': 'ª',
    '&alpha;': 'α',
    '&beta;': 'β',
    '&gamma;': 'γ',
    '&delta;': 'δ',
    '&epsilon;': 'ε',
    '&zeta;': 'ζ',
    '&eta;': 'η',
    '&theta;': 'θ',
    '&iota;': 'ι',
    '&kappa;': 'κ',
    '&lambda;': 'λ',
    '&mu;': 'μ',
    '&nu;': 'ν',
    '&xi;': 'ξ',
    '&omicron;': 'ο',
    '&pi;': 'π',
    '&rho;': 'ρ',
    '&sigma;': 'σ',
    '&tau;': 'τ',
    '&upsilon;': 'υ',
    '&phi;': 'φ',
    '&chi;': 'χ',
    '&psi;': 'ψ',
    '&omega;': 'ω',
    '&Agrave;': 'À',
    '&Aacute;': 'Á',
    '&Acirc;': 'Â',
    '&Atilde;': 'Ã',
    '&Auml;': 'Ä',
    '&Aring;': 'Å',
    '&AElig;': 'Æ',
    '&Ccedil;': 'Ç',
    '&Egrave;': 'È',
    '&Eacute;': 'É',
    '&Ecirc;': 'Ê',
    '&Euml;': 'Ë',
    '&Igrave;': 'Ì',
    '&Iacute;': 'Í',
    '&Icirc;': 'Î',
    '&Iuml;': 'Ï',
    '&ETH;': 'Ð',
    '&Ntilde;': 'Ñ',
    '&Ograve;': 'Ò',
    '&Oacute;': 'Ó',
    '&Ocirc;': 'Ô',
    '&Otilde;': 'Õ',
    '&Ouml;': 'Ö',
    '&Oslash;': 'Ø',
    '&Ugrave;': 'Ù',
    '&Uacute;': 'Ú',
    '&Ucirc;': 'Û',
    '&Uuml;': 'Ü',
    '&Yacute;': 'Ý',
    '&THORN;': 'Þ',
    '&szlig;': 'ß',
    '&agrave;': 'à',
    '&aacute;': 'á',
    '&acirc;': 'â',
    '&atilde;': 'ã',
    '&auml;': 'ä',
    '&aring;': 'å',
    '&aelig;': 'æ',
    '&ccedil;': 'ç',
    '&egrave;': 'è',
    '&eacute;': 'é',
    '&ecirc;': 'ê',
    '&euml;': 'ë',
    '&igrave;': 'ì',
    '&iacute;': 'í',
    '&icirc;': 'î',
    '&iuml;': 'ï',
    '&eth;': 'ð',
    '&ntilde;': 'ñ',
    '&ograve;': 'ò',
    '&oacute;': 'ó',
    '&ocirc;': 'ô',
    '&otilde;': 'õ',
    '&ouml;': 'ö',
    '&oslash;': 'ø',
    '&ugrave;': 'ù',
    '&uacute;': 'ú',
    '&ucirc;': 'û',
    '&uuml;': 'ü',
    '&yacute;': 'ý',
    '&thorn;': 'þ',
    '&yuml;': 'ÿ',
    // Entità specifiche per i post del condominio
    '&#8211;': '–', // en dash
    '&#8212;': '—', // em dash
    '&#8216;': ''', // left single quotation mark
    '&#8217;': ''', // right single quotation mark
    '&#8218;': '‚', // single low-9 quotation mark
    '&#8219;': '‛', // single high-reversed-9 quotation mark
    '&#8220;': '"', // left double quotation mark
    '&#8221;': '"', // right double quotation mark
    '&#8222;': '„', // double low-9 quotation mark
    '&#8226;': '•', // bullet
    '&#8230;': '…', // horizontal ellipsis
    '&#8242;': '′', // prime
    '&#8243;': '″', // double prime
    '&#8249;': '‹', // single left-pointing angle quotation mark
    '&#8250;': '›', // single right-pointing angle quotation mark
    '&#8364;': '€', // euro sign
    '&#8482;': '™', // trade mark sign
    '&#8592;': '←', // leftwards arrow
    '&#8593;': '↑', // upwards arrow
    '&#8594;': '→', // rightwards arrow
    '&#8595;': '↓', // downwards arrow
    '&#8596;': '↔', // left right arrow
    '&#8597;': '↕', // up down arrow
    '&#8598;': '↖', // north west arrow
    '&#8599;': '↗', // north east arrow
    '&#8600;': '↘', // south east arrow
    '&#8601;': '↙', // south west arrow
    '&#8602;': '↚', // leftwards arrow with stroke
    '&#8603;': '↛', // rightwards arrow with stroke
    '&#8604;': '↜', // leftwards wave arrow
    '&#8605;': '↝', // rightwards wave arrow
    '&#8606;': '↞', // leftwards two headed arrow
    '&#8607;': '↟', // upwards two headed arrow
    '&#8608;': '↠', // rightwards two headed arrow
    '&#8609;': '↡', // downwards two headed arrow
    '&#8610;': '↢', // leftwards arrow with tail
    '&#8611;': '↣', // rightwards arrow with tail
    '&#8612;': '↤', // leftwards arrow from bar
    '&#8613;': '↥', // upwards arrow from bar
    '&#8614;': '↦', // rightwards arrow from bar
    '&#8615;': '↧', // downwards arrow from bar
    '&#8616;': '↨', // up down arrow with base
    '&#8617;': '↩', // leftwards arrow with hook
    '&#8618;': '↪', // rightwards arrow with hook
    '&#8619;': '↫', // leftwards arrow with loop
    '&#8620;': '↬', // rightwards arrow with loop
    '&#8621;': '↭', // left right wave arrow
    '&#8622;': '↮', // left right arrow with stroke
    '&#8623;': '↯', // downwards zigzag arrow
    '&#8624;': '↰', // upwards arrow with tip leftwards
    '&#8625;': '↱', // upwards arrow with tip rightwards
    '&#8626;': '↲', // downwards arrow with tip leftwards
    '&#8627;': '↳', // downwards arrow with tip rightwards
    '&#8628;': '↴', // rightwards arrow with corner downwards
    '&#8629;': '↵', // downwards arrow with corner leftwards
    '&#8630;': '↶', // anticlockwise top semicircle arrow
    '&#8631;': '↷', // clockwise top semicircle arrow
    '&#8632;': '↸', // north west arrow to long bar
    '&#8633;': '↹', // leftwards arrow to bar over rightwards arrow to bar
    '&#8634;': '↺', // anticlockwise open circle arrow
    '&#8635;': '↻', // clockwise open circle arrow
    '&#8636;': '↼', // leftwards harpoon with barb upwards
    '&#8637;': '↽', // leftwards harpoon with barb downwards
    '&#8638;': '↾', // upwards harpoon with barb rightwards
    '&#8639;': '↿', // upwards harpoon with barb leftwards
    '&#8640;': '⇀', // rightwards harpoon with barb upwards
    '&#8641;': '⇁', // rightwards harpoon with barb downwards
    '&#8642;': '⇂', // downwards harpoon with barb rightwards
    '&#8643;': '⇃', // downwards harpoon with barb leftwards
    '&#8644;': '⇄', // rightwards arrow over leftwards arrow
    '&#8645;': '⇅', // upwards arrow leftwards of downwards arrow
    '&#8646;': '⇆', // leftwards arrow over rightwards arrow
    '&#8647;': '⇇', // leftwards paired arrows
    '&#8648;': '⇈', // upwards paired arrows
    '&#8649;': '⇉', // rightwards paired arrows
    '&#8650;': '⇊', // downwards paired arrows
    '&#8651;': '⇋', // leftwards harpoon over rightwards harpoon
    '&#8652;': '⇌', // rightwards harpoon over leftwards harpoon
    '&#8653;': '⇍', // leftwards double arrow with stroke
    '&#8654;': '⇎', // left right double arrow with stroke
    '&#8655;': '⇏', // rightwards double arrow with stroke
    '&#8656;': '⇐', // leftwards double arrow
    '&#8657;': '⇑', // upwards double arrow
    '&#8658;': '⇒', // rightwards double arrow
    '&#8659;': '⇓', // downwards double arrow
    '&#8660;': '⇔', // left right double arrow
    '&#8661;': '⇕', // up down double arrow
    '&#8662;': '⇖', // north west double arrow
    '&#8663;': '⇗', // north east double arrow
    '&#8664;': '⇘', // south east double arrow
    '&#8665;': '⇙', // south west double arrow
    '&#8666;': '⇚', // leftwards triple arrow
    '&#8667;': '⇛', // rightwards triple arrow
    '&#8668;': '⇜', // leftwards squiggle arrow
    '&#8669;': '⇝', // rightwards squiggle arrow
    '&#8670;': '⇞', // upwards arrow with double stroke
    '&#8671;': '⇟', // downwards arrow with double stroke
    '&#8672;': '⇠', // leftwards dashed arrow
    '&#8673;': '⇡', // upwards dashed arrow
    '&#8674;': '⇢', // rightwards dashed arrow
    '&#8675;': '⇣', // downwards dashed arrow
    '&#8676;': '⇤', // leftwards arrow to bar
    '&#8677;': '⇥', // rightwards arrow to bar
    '&#8678;': '⇦', // leftwards white arrow
    '&#8679;': '⇧', // upwards white arrow
    '&#8680;': '⇨', // rightwards white arrow
    '&#8681;': '⇩', // downwards white arrow
    '&#8682;': '⇪', // upwards white arrow from bar
    '&#8683;': '⇫', // upwards white arrow on pedestal
    '&#8684;': '⇬', // rightwards white arrow on pedestal
    '&#8685;': '⇭', // rightwards white arrow in wall bracket
    '&#8686;': '⇮', // rightwards white arrow in wall bracket
    '&#8687;': '⇯', // rightwards white arrow in wall bracket
    '&#8688;': '⇰', // rightwards white arrow in wall bracket
    '&#8689;': '⇱', // rightwards white arrow in wall bracket
    '&#8690;': '⇲', // rightwards white arrow in wall bracket
    '&#8691;': '⇳', // rightwards white arrow in wall bracket
    '&#8692;': '⇴', // rightwards white arrow in wall bracket
    '&#8693;': '⇵', // rightwards white arrow in wall bracket
    '&#8694;': '⇶', // rightwards white arrow in wall bracket
    '&#8695;': '⇷', // rightwards white arrow in wall bracket
    '&#8696;': '⇸', // rightwards white arrow in wall bracket
    '&#8697;': '⇹', // rightwards white arrow in wall bracket
    '&#8698;': '⇺', // rightwards white arrow in wall bracket
    '&#8699;': '⇻', // rightwards white arrow in wall bracket
    '&#8700;': '⇼', // rightwards white arrow in wall bracket
    '&#8701;': '⇽', // rightwards white arrow in wall bracket
    '&#8702;': '⇾', // rightwards white arrow in wall bracket
    '&#8703;': '⇿', // rightwards white arrow in wall bracket
  };

  String result = htmlString;

  // Decodifica le entità HTML
  htmlEntities.forEach((entity, char) {
    result = result.replaceAll(entity, char);
  });

  // Gestisce le entità numeriche come &#8211; (en dash)
  result = result.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
    final code = int.tryParse(match.group(1) ?? '');
    if (code != null && code >= 32 && code <= 0x10FFFF) {
      return String.fromCharCode(code);
    }
    return match.group(0) ?? '';
  });

  // Gestisce le entità esadecimali come &#x2013; (en dash)
  result = result.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
    final code = int.tryParse(match.group(1) ?? '', radix: 16);
    if (code != null && code >= 32 && code <= 0x10FFFF) {
      return String.fromCharCode(code);
    }
    return match.group(0) ?? '';
  });

  return result;
}

// Funzione per ricaricare il token dalle SharedPreferences (utile per hot reload)
Future<void> reloadTokenFromStorage() async {
  try {
    debugPrint('=== RICARICA TOKEN DA STORAGE ===');
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('jwtToken');
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final username = prefs.getString('username');
    final password = prefs.getString('password');

    debugPrint('Dati salvati:');
    debugPrint(
        '- Token: ${savedToken != null ? "Presente (${savedToken.length} chars)" : "Mancante"}');
    debugPrint('- isLoggedIn: $isLoggedIn');
    debugPrint('- Username: ${username != null ? "Presente" : "Mancante"}');
    debugPrint('- Password: ${password != null ? "Presente" : "Mancante"}');

    if (savedToken != null && savedToken.isNotEmpty && isLoggedIn) {
      jwtToken = savedToken;
      debugPrint('Token ricaricato dalle SharedPreferences');
      debugPrint('Token valido: ${jwtToken!.contains('wordpress_logged_in')}');
    } else {
      jwtToken = null;
      debugPrint('Nessun token valido trovato nelle SharedPreferences');
      if (savedToken == null) debugPrint('Motivo: Token null');
      if (savedToken != null && savedToken.isEmpty)
        debugPrint('Motivo: Token vuoto');
      if (!isLoggedIn) debugPrint('Motivo: isLoggedIn = false');
    }
  } catch (e) {
    debugPrint('Errore ricaricamento token: $e');
    jwtToken = null;
  }
}

Future<void> regenerateToken() async {
  final prefs = await SharedPreferences.getInstance();
  final username = prefs.getString('username');
  final password = prefs.getString('password');

  if (username != null && password != null) {
    debugPrint('Rigenerazione cookie per: $username');
    try {
      // Prima ottieni il nonce necessario per il login
      final nonceResponse = await http.get(
        Uri.parse('$urlSito/wp-login.php'),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      );

      debugPrint('Nonce response status: ${nonceResponse.statusCode}');

      // Estrai il nonce dalla risposta HTML
      String nonce = '';
      final nonceMatch = RegExp(r'name="_wpnonce" value="([^"]+)"')
          .firstMatch(nonceResponse.body);
      if (nonceMatch != null) {
        nonce = nonceMatch.group(1)!;
        debugPrint('Nonce estratto: $nonce');
      }

      // Effettua nuovo login con il nonce
      final loginResponse = await http.post(
        Uri.parse('$urlSito/wp-login.php'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Referer': '$urlSito/wp-login.php',
        },
        body: nonce.isNotEmpty
            ? 'log=$username&pwd=$password&wp-submit=Log+In&redirect_to=$urlSito/wp-admin/&testcookie=1&_wpnonce=$nonce'
            : 'log=$username&pwd=$password&wp-submit=Log+In&redirect_to=$urlSito/wp-admin/&testcookie=1',
      );

      debugPrint(
          'Regenerate token response status: ${loginResponse.statusCode}');
      debugPrint('Regenerate token response headers: ${loginResponse.headers}');

      if (loginResponse.headers['set-cookie'] != null) {
        final cookies = loginResponse.headers['set-cookie']!;
        debugPrint('Nuovi cookie ricevuti: $cookies');

        // Verifica se il login è riuscito
        if (loginResponse.statusCode == 302 ||
            loginResponse.headers['location']?.contains('wp-admin') == true ||
            loginResponse.body.contains('wp-admin') ||
            cookies.contains('wordpress_logged_in')) {
          jwtToken = cookies;
          await prefs.setString('jwtToken', jwtToken!);
          await prefs.setBool('isLoggedIn', true);
          debugPrint('Cookie rigenerati con successo');

          // Verifica che il login sia effettivamente riuscito
          await _verifyLoginSuccess();
        } else {
          debugPrint('Rigenerazione cookie fallita - login non riuscito');
          debugPrint('Response body: ${loginResponse.body}');
          await clearLoginData();
        }
      } else {
        debugPrint('Rigenerazione cookie fallita - nessun cookie ricevuto');
        await clearLoginData();
      }
    } catch (e) {
      debugPrint('Errore rigenerazione cookie: $e');
      await clearLoginData();
    }
  } else {
    debugPrint('Credenziali non trovate per rigenerazione token');
    await clearLoginData();
  }
}

Future<void> _verifyLoginSuccess() async {
  try {
    debugPrint('Verifica successo login...');

    // Prova ad accedere a wp-admin per verificare il login
    final adminResponse = await http.get(
      Uri.parse('$urlSito/wp-admin/'),
      headers: {
        'Cookie': jwtToken!,
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
    );

    debugPrint('Admin access status: ${adminResponse.statusCode}');

    if (adminResponse.statusCode == 200 &&
        !adminResponse.body.contains('wp-login.php')) {
      debugPrint('Login verificato con successo');
    } else {
      debugPrint(
          'Login non verificato - potrebbe essere necessario un approccio diverso');
    }
  } catch (e) {
    debugPrint('Errore verifica login: $e');
  }
}

Future<void> clearLoginData() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('jwtToken');
  await prefs.remove('username');
  await prefs.remove('password');
  await prefs.setBool('isLoggedIn', false);
  jwtToken = null;
}

Future<void> _openInAppBrowser(String url) async {
  final Uri uri = Uri.parse(url);

  if (!await launchUrl(
    uri,
    mode: LaunchMode.inAppWebView,
    webViewConfiguration: const WebViewConfiguration(
      enableJavaScript: true,
    ),
  )) {
    throw Exception('Impossibile aprire $url');
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final LanguageProvider languageProvider = LanguageProvider();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class ModernArticlesScreen extends StatefulWidget {
  final List<dynamic> posts;
  final String userName;
  final String userEmail;

  const ModernArticlesScreen({
    super.key,
    required this.posts,
    required this.userName,
    required this.userEmail,
  });

  @override
  State<ModernArticlesScreen> createState() => _ModernArticlesScreenState();
}

class _ModernArticlesScreenState extends State<ModernArticlesScreen> {
  late List<dynamic> filteredPosts;
  late List<dynamic> translatedPosts;
  String searchQuery = '';
  String selectedCategory = 'Tutti';
  String selectedStatus = 'Tutti';
  bool isSearchExpanded = false;
  bool isLoading = false;
  bool showCategories = true;
  String currentCategory = '';
  Map<String, List<dynamic>> categoryMap = {};
  String currentLanguage = 'it';

  @override
  void initState() {
    super.initState();
    translatedPosts = widget.posts;
    currentLanguage = languageProvider.locale.languageCode;

    // Traduci i post all'inizializzazione se la lingua non è italiano
    if (currentLanguage != 'it') {
      _translatePostsOnInit();
    } else {
      _buildCategoryMap();
      filteredPosts = widget.posts;
    }

    languageProvider.addListener(_onLanguageChanged);
  }

  Future<void> _translatePostsOnInit() async {
    debugPrint('🌍 Inizio traduzione ${widget.posts.length} post in $currentLanguage');
    setState(() {
      isLoading = true;
    });

    final translated = <dynamic>[];
    int count = 0;
    for (final post in widget.posts) {
      count++;
      debugPrint('📝 Traduco post $count/${widget.posts.length}...');
      final translatedPost = await translatePost(post, currentLanguage);
      translated.add(translatedPost);
    }

    if (mounted) {
      debugPrint('✅ Traduzione completata! ${translated.length} post tradotti');
      setState(() {
        translatedPosts = translated;
        isLoading = false;
      });
      _buildCategoryMap();
      _filterPosts();
    }
  }

  @override
  void dispose() {
    languageProvider.removeListener(_onLanguageChanged);
    super.dispose();
  }

  Future<void> _onLanguageChanged() async {
    final newLanguage = languageProvider.locale.languageCode;
    debugPrint('🔄 Cambio lingua da $currentLanguage a $newLanguage');
    
    if (newLanguage != currentLanguage) {
      setState(() {
        isLoading = true;
        currentLanguage = newLanguage;
      });

      debugPrint('🌍 Inizio traduzione ${widget.posts.length} post in $newLanguage');
      
      // Traduci tutti i post
      final translated = <dynamic>[];
      int count = 0;
      for (final post in widget.posts) {
        count++;
        debugPrint('📝 Traduco post $count/${widget.posts.length}...');
        final translatedPost = await translatePost(post, newLanguage);
        translated.add(translatedPost);
      }

      debugPrint('✅ Traduzione completata! ${translated.length} post tradotti');
      
      setState(() {
        translatedPosts = translated;
        isLoading = false;
        _buildCategoryMap();
        _filterPosts();
      });
    }
  }

  void _buildCategoryMap() {
    categoryMap.clear();
    for (final post in translatedPosts) {
      final categories = post['_embedded']?['wp:term']?[0];
      final names = (categories != null && categories.isNotEmpty)
          ? categories.map<String>((c) => c['name'] as String).toList()
          : [AppLocalizations.of(context).withoutCategory];

      for (final name in names) {
        categoryMap.putIfAbsent(name, () => []).add(post);
      }
    }
  }

  void _showCategoryPosts(String category) {
    setState(() {
      showCategories = false;
      currentCategory = category;
      filteredPosts = categoryMap[category] ?? [];
    });
  }

  void _goBackToCategories() {
    setState(() {
      showCategories = true;
      currentCategory = '';
      searchQuery = '';
      selectedCategory = 'Tutti';
      selectedStatus = 'Tutti';
      isSearchExpanded = false;
    });
  }

  void _filterPosts() {
    try {
      setState(() {
        final postsToFilter = showCategories
            ? translatedPosts
            : (categoryMap[currentCategory] ?? []);
        filteredPosts = postsToFilter.where((post) {
          try {
            final title = decodeHtmlEntities(post['title']?['rendered'] ?? '')
                .toLowerCase();
            final content =
                decodeHtmlEntities(post['content']?['rendered'] ?? '')
                    .toLowerCase();
            final excerpt =
                decodeHtmlEntities(post['excerpt']?['rendered'] ?? '')
                    .toLowerCase();
            final status = post['status'] ?? '';

            // Filtro per ricerca
            final matchesSearch = searchQuery.isEmpty ||
                title.contains(searchQuery.toLowerCase()) ||
                content.contains(searchQuery.toLowerCase()) ||
                excerpt.contains(searchQuery.toLowerCase());

            // Filtro per categoria (solo se non stiamo mostrando una categoria specifica)
            final categories = post['_embedded']?['wp:term']?[0];
            final categoryNames = (categories != null && categories.isNotEmpty)
                ? categories.map<String>((c) => c['name'] as String).toList()
                : ['Senza categoria'];

            final matchesCategory = showCategories
                ? (selectedCategory == 'Tutti' ||
                    categoryNames.any((cat) => cat == selectedCategory))
                : true; // Se stiamo mostrando una categoria specifica, non filtrare per categoria

            // Filtro per status
            final matchesStatus = selectedStatus == 'Tutti' ||
                (selectedStatus == 'Pubblico' && status == 'publish') ||
                (selectedStatus == 'Privato' && status == 'private');

            return matchesSearch && matchesCategory && matchesStatus;
          } catch (e) {
            debugPrint('Errore nel filtraggio del post: $e');
            return false;
          }
        }).toList();
      });
    } catch (e) {
      debugPrint('Errore nella funzione _filterPosts: $e');
      setState(() {
        filteredPosts = [];
      });
    }
  }

  Future<void> _refreshPosts() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Simula un refresh - in una implementazione reale qui ricaricheresti i post
      await Future.delayed(const Duration(seconds: 1));
      _filterPosts();
    } catch (e) {
      debugPrint('Errore refresh articoli: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  List<String> _getAvailableCategories() {
    final Set<String> categories = {AppLocalizations.of(context).all};
    for (final post in translatedPosts) {
      final postCategories = post['_embedded']?['wp:term']?[0];
      if (postCategories != null && postCategories.isNotEmpty) {
        for (final cat in postCategories) {
          categories.add(cat['name'] as String);
        }
      }
    }
    return categories.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final availableCategories = _getAvailableCategories();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          showCategories
              ? AppLocalizations.of(context).articleCategories
              : currentCategory,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF01579B),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: showCategories
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _goBackToCategories,
              ),
        actions: [
          if (!showCategories) ...[
            IconButton(
              icon: Icon(isSearchExpanded ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  isSearchExpanded = !isSearchExpanded;
                  if (!isSearchExpanded) {
                    searchQuery = '';
                    _filterPosts();
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshPosts,
            ),
          ],
        ],
      ),
      body: showCategories ? _buildCategoriesView() : _buildArticlesView(),
    );
  }

  Widget _buildCategoriesView() {
    final categories = categoryMap.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final postCount = categoryMap[category]?.length ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _showCategoryPosts(category),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Colors.white, Color(0xFFFAFAFA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2196F3).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.folder_outlined,
                          color: Color(0xFF2196F3),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$postCount ${AppLocalizations.of(context).articles.toLowerCase()}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.grey[400],
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildArticlesView() {
    return Column(
      children: [
        // Barra di ricerca espandibile
        if (isSearchExpanded)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context).searchArticles,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                searchQuery = '';
                                _filterPosts();
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                      _filterPosts();
                    });
                  },
                ),
                const SizedBox(height: 12),
                // Filtri
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedStatus,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context).status,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        items: [
                          DropdownMenuItem(
                              value: 'Tutti',
                              child: Text(AppLocalizations.of(context).all)),
                          DropdownMenuItem(
                              value: 'Pubblico',
                              child: Text(AppLocalizations.of(context).public)),
                          DropdownMenuItem(
                              value: 'Privato',
                              child:
                                  Text(AppLocalizations.of(context).private)),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedStatus = value!;
                            _filterPosts();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        // Contatore risultati
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          child: Row(
            children: [
              Icon(
                Icons.article_outlined,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Text(
                '${filteredPosts.length} ${AppLocalizations.of(context).articlesIn} "$currentCategory"',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (searchQuery.isNotEmpty || selectedStatus != 'Tutti')
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      searchQuery = '';
                      selectedStatus = 'Tutti';
                      _filterPosts();
                    });
                  },
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: Text(AppLocalizations.of(context).reset),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF01579B),
                  ),
                ),
            ],
          ),
        ),

        // Lista articoli
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredPosts.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _refreshPosts,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredPosts.length,
                        itemBuilder: (context, index) {
                          if (index >= filteredPosts.length) {
                            return const SizedBox.shrink();
                          }
                          return _buildArticleCard(filteredPosts[index]);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).noArticlesFound,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).tryModifyFilters,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArticleCard(Map<String, dynamic> post) {
    try {
      final title = decodeHtmlEntities(post['title']?['rendered'] ?? '');
      final excerpt = decodeHtmlEntities(post['excerpt']?['rendered'] ?? '');
      final authorId = post['author'] ?? 0;
      final status = post['status'] ?? '';
      final url = post['link'] ?? '';
      final date = post['date'] ?? '';

      // Estrai categoria
      final categories = post['_embedded']?['wp:term']?[0];
      final categoryNames = (categories != null && categories.isNotEmpty)
          ? categories.map<String>((c) => c['name'] as String).toList()
          : ['Senza categoria'];

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PostDetailScreen(
                    post: post,
                    userName: widget.userName,
                    userEmail: widget.userEmail,
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: status == 'private'
                    ? const LinearGradient(
                        colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [Colors.white, Color(0xFFFAFAFA)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                border: status == 'private'
                    ? Border.all(
                        color: const Color(0xFFFF9800).withOpacity(0.3),
                        width: 1.5,
                      )
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header con icona e status
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: status == 'private'
                                ? const Color(0xFFFF9800).withOpacity(0.1)
                                : const Color(0xFF2196F3).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            status == 'private'
                                ? Icons.lock_rounded
                                : Icons.article_rounded,
                            color: status == 'private'
                                ? const Color(0xFFFF9800)
                                : const Color(0xFF2196F3),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title.isNotEmpty ? title : 'Titolo non disponibile',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: status == 'private'
                                  ? const Color(0xFFE65100)
                                  : const Color(0xFF2C3E50),
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: status == 'private'
                                ? const Color(0xFFFF9800).withOpacity(0.1)
                                : const Color(0xFF4CAF50).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status == 'private' ? 'Privato' : 'Pubblico',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: status == 'private'
                                  ? const Color(0xFFFF9800)
                                  : const Color(0xFF4CAF50),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Categoria
                    if (categoryNames.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children:
                              categoryNames.take(2).map<Widget>((category) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3F2FD).withOpacity(0.8),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                category,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1976D2),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],

                    // Excerpt
                    if (excerpt.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        _removeHtmlTags(excerpt),
                        style: TextStyle(
                          fontSize: 14,
                          color: status == 'private'
                              ? const Color(0xFFBF360C).withOpacity(0.8)
                              : const Color(0xFF7F8C8D),
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // Footer con info
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'ID: $authorId',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        if (date.isNotEmpty) ...[
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(date),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.grey[400],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Errore nel rendering della card: $e');
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red[200]!),
        ),
        child: const Text(
          'Errore nel caricamento dell\'articolo',
          style: TextStyle(color: Colors.red),
        ),
      );
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  String _removeHtmlTags(String htmlText) {
    if (htmlText.isEmpty) return htmlText;
    return htmlText
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }
}

class CategoryPostViewer extends StatelessWidget {
  final List<dynamic> posts;

  const CategoryPostViewer({super.key, required this.posts});

  @override
  Widget build(BuildContext context) {
    final Map<String, List<dynamic>> categoryMap = {};

    for (final post in posts) {
      final categories = post['_embedded']?['wp:term']?[0];
      final names = (categories != null && categories.isNotEmpty)
          ? categories.map<String>((c) => c['name'] as String).toList()
          : ['Senza categoria'];

      for (final name in names) {
        categoryMap.putIfAbsent(name, () => []).add(post);
      }
    }

    final categories = categoryMap.keys.toList()..sort();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final category = categories[index];
        final postCount = categoryMap[category]?.length ?? 0;

        return Card(
          elevation: 2,
          child: ListTile(
            title: Text(
              category,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text('$postCount post'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CategoryPostsScreen(
                    category: category,
                    posts: categoryMap[category] ?? [],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class CategoryPostsScreen extends StatefulWidget {
  final String category;
  final List<dynamic> posts;

  const CategoryPostsScreen({
    super.key,
    required this.category,
    required this.posts,
  });

  @override
  State<CategoryPostsScreen> createState() => _CategoryPostsScreenState();
}

class _CategoryPostsScreenState extends State<CategoryPostsScreen> {
  late List<dynamic> currentPosts;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    currentPosts = widget.posts;
  }

  Future<void> _refreshPosts() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      // Ricarica i post per questa categoria
      await _MyHomePageState()
          .fetchUserPostsByCategory(1); // Usa categoria di default

      // In alternativa, ricarica tutti i post
      await _MyHomePageState().fetchPosts();
    } catch (e) {
      debugPrint('Errore refresh post categoria: $e');
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category),
        backgroundColor: const Color(0xFFFFC107),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshPosts,
            tooltip: 'Aggiorna post',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshPosts,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: currentPosts.length,
                itemBuilder: (context, index) {
                  final post = currentPosts[index];
                  final title =
                      decodeHtmlEntities(post['title']['rendered'] ?? '');
                  final excerpt =
                      decodeHtmlEntities(post['excerpt']['rendered'] ?? '');
                  final authorId = post['author'] ?? 0;
                  final status = post['status'] ?? '';
                  final url = post['link'] ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          if (url.isNotEmpty) {
                            _openInAppBrowser(url);
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: status == 'private'
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFFFFF3E0),
                                      Color(0xFFFFE0B2)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : const LinearGradient(
                                    colors: [Colors.white, Color(0xFFFAFAFA)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                            border: status == 'private'
                                ? Border.all(
                                    color: const Color(0xFFFF9800)
                                        .withOpacity(0.3),
                                    width: 1.5,
                                  )
                                : null,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: status == 'private'
                                            ? const Color(0xFFFF9800)
                                                .withOpacity(0.1)
                                            : const Color(0xFF2196F3)
                                                .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        status == 'private'
                                            ? Icons.lock_rounded
                                            : Icons.article_rounded,
                                        color: status == 'private'
                                            ? const Color(0xFFFF9800)
                                            : const Color(0xFF2196F3),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: status == 'private'
                                              ? const Color(0xFFE65100)
                                              : const Color(0xFF2C3E50),
                                          height: 1.3,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 14,
                                        color: Color(0xFF7F8C8D),
                                      ),
                                    ),
                                  ],
                                ),
                                if (excerpt.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    _removeHtmlTags(excerpt),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: status == 'private'
                                          ? const Color(0xFFBF360C)
                                              .withOpacity(0.8)
                                          : const Color(0xFF7F8C8D),
                                      height: 1.4,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: status == 'private'
                                            ? const Color(0xFFFF9800)
                                                .withOpacity(0.1)
                                            : const Color(0xFF4CAF50)
                                                .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        status == 'private'
                                            ? 'Privato'
                                            : 'Pubblico',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: status == 'private'
                                              ? const Color(0xFFFF9800)
                                              : const Color(0xFF4CAF50),
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'ID: $authorId',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF95A5A6),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  String _removeHtmlTags(String htmlText) {
    if (htmlText.isEmpty) return htmlText;

    // Prima decodifica le entità HTML
    final decodedText = decodeHtmlEntities(htmlText);

    // Poi rimuovi i tag HTML rimanenti
    final regex = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true);
    return decodedText.replaceAll(regex, '');
  }

  Future<void> _openInAppBrowser(String url) async {
    final Uri uri = Uri.parse(url);

    if (!await launchUrl(
      uri,
      mode: LaunchMode.inAppWebView,
      webViewConfiguration: const WebViewConfiguration(
        enableJavaScript: true,
      ),
    )) {
      throw Exception('Impossibile aprire $url');
    }
  }
}

class WebcamScreen extends StatelessWidget {
  const WebcamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).webcamLive,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFFFFC107),
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFC107),
              Color(0xFFF8F9FA),
            ],
            stops: [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Text(
                  AppLocalizations.of(context).realtimeMonitoring,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context).viewWebcamsWeather,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF7F8C8D),
                  ),
                ),
                const SizedBox(height: 40),
                Expanded(
                  child: ListView(
                    children: [
                      _buildWebcamCard(
                        context,
                        icon: Icons.videocam_rounded,
                        title: AppLocalizations.of(context).portWebcam,
                        subtitle: AppLocalizations.of(context).directPortView,
                        description: AppLocalizations.of(context).monitorPortActivity,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3498DB), Color(0xFF2980B9)],
                        ),
                        onTap: () {
                          _openInAppBrowser(
                            'https://player.castr.com/live_c8ab600012f411f08aa09953068f9db6',
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildWebcamCard(
                        context,
                        icon: Icons.landscape_rounded,
                        title: AppLocalizations.of(context).panoramicWebcam,
                        subtitle: AppLocalizations.of(context).panoramic360View,
                        description: AppLocalizations.of(context).enjoyPanoramicView,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF27AE60), Color(0xFF229954)],
                        ),
                        onTap: () {
                          _openInAppBrowser(
                            'https://player.castr.com/live_e63170f014a311f0bf78a9d871469680',
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildWebcamCard(
                        context,
                        icon: Icons.wb_sunny_rounded,
                        title: AppLocalizations.of(context).weatherStation,
                        subtitle: AppLocalizations.of(context).weatherData,
                        description: AppLocalizations.of(context).checkWeatherConditions,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE67E22), Color(0xFFD35400)],
                        ),
                        onTap: () {
                          _openInAppBrowser(
                            'https://stazioni5.soluzionimeteo.it/portobellodigallura/',
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebcamCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: gradient,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    languageProvider.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    languageProvider.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: ValueKey(languageProvider
          .locale.languageCode), // Forza rebuild quando cambia lingua
      navigatorKey: navigatorKey,
      title: 'Condominio App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          headlineLarge: TextStyle(
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      locale: languageProvider.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('it'),
        Locale('en'),
        Locale('fr'),
        Locale('zh'),
      ],
      home: const SplashScreen(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage(
      {super.key,
      required this.title,
      required this.userEmail,
      required this.userName});

  final String title;
  final String userEmail;
  final String userName;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2E86C1),
              Color(0xFF3498DB),
              Color(0xFF5DADE2),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Indicatore di pagina
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? Colors.white
                            : Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),

              // PageView
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  children: [
                    _buildOnboardingPage(
                      Icons.home_rounded,
                      'Benvenuto nell\'app del condominio!',
                      'Gestisci facilmente tutte le informazioni relative al tuo condominio in modo semplice e intuitivo.',
                      const Color(0xFF3498DB),
                    ),
                    _buildOnboardingPage(
                      Icons.notifications_rounded,
                      'Rimani sempre aggiornato!',
                      'Visualizza le ultime novità, comunicazioni e aggiornamenti riguardanti il tuo condominio.',
                      const Color(0xFFE74C3C),
                    ),
                    _buildOnboardingPage(
                      Icons.people_rounded,
                      'Connettiti con i vicini',
                      'Usa il nostro sistema di messaggistica per restare in contatto con i tuoi vicini e l\'amministrazione.',
                      const Color(0xFF2ECC71),
                    ),
                  ],
                ),
              ),

              // Pulsante di azione
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Pulsante principale
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFC107),
                          foregroundColor: Colors.white,
                          elevation: 8,
                          shadowColor: const Color(0xFFFFC107).withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Inizia ora',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Pulsante skip
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Salta',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOnboardingPage(
      IconData icon, String title, String description, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icona principale
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(60),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 60,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 48),

          // Titolo
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // Descrizione
          Text(
            description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> handleLogin(String username, String password) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('=== INIZIO LOGIN ===');
      debugPrint('Username: $username');

      // Step 1: Ottieni il nonce necessario per il login
      final nonceResponse = await http.get(
        Uri.parse('$urlSito/wp-login.php'),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      );

      debugPrint('Nonce response status: ${nonceResponse.statusCode}');

      // Estrai il nonce dalla risposta HTML
      String nonce = '';
      final nonceMatch = RegExp(r'name="_wpnonce" value="([^"]+)"')
          .firstMatch(nonceResponse.body);
      if (nonceMatch != null) {
        nonce = nonceMatch.group(1)!;
        debugPrint('Nonce estratto: $nonce');
      }

      // Step 2: Effettua login con il nonce
      final loginResponse = await http.post(
        Uri.parse('$urlSito/wp-login.php'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Referer': '$urlSito/wp-login.php',
        },
        body: nonce.isNotEmpty
            ? 'log=$username&pwd=$password&wp-submit=Log+In&redirect_to=$urlSito/wp-admin/&testcookie=1&_wpnonce=$nonce'
            : 'log=$username&pwd=$password&wp-submit=Log+In&redirect_to=$urlSito/wp-admin/&testcookie=1',
      );

      debugPrint('Login response status: ${loginResponse.statusCode}');
      debugPrint('Login response headers: ${loginResponse.headers}');

      // Step 3: Verifica se il login è riuscito controllando i cookie
      if (loginResponse.headers['set-cookie'] != null) {
        final cookies = loginResponse.headers['set-cookie']!;
        debugPrint('Login cookies ricevuti: $cookies');

        // Step 4: Verifica il login controllando se siamo reindirizzati
        // Se il login è riuscito, WordPress reindirizza a wp-admin
        if (loginResponse.statusCode == 302 ||
            loginResponse.headers['location']?.contains('wp-admin') == true ||
            loginResponse.body.contains('wp-admin') ||
            cookies.contains('wordpress_logged_in')) {
          // Login riuscito - salva i cookie
          jwtToken = cookies;

          // Salva le credenziali e i cookie
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwtToken', jwtToken!);
          await prefs.setString('username', username);
          await prefs.setString('password', password);
          await prefs.setBool('isLoggedIn', true);

          debugPrint('Login successful, cookies saved');

          if (context.mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const MyHomePage(
                  title: '',
                  userEmail: '',
                  userName: '',
                ),
              ),
            );
          }
        } else {
          debugPrint('Login failed - no valid session');
          debugPrint('Response body: ${loginResponse.body}');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Login fallito. Verifica le credenziali.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        debugPrint('No cookies received, login failed');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login fallito. Verifica le credenziali.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (err) {
      debugPrint('Login error: $err');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore di connessione. Riprova.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2E86C1),
              Color(0xFF3498DB),
              Color(0xFF5DADE2),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Card(
                  elevation: 20,
                  shadowColor: Colors.black.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.white, Color(0xFFFAFAFA)],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo e titolo
                          Container(
                            padding: const EdgeInsets.all(20),
                            
                            child: Image.asset(
                              "assets/logo.png",
                              width: 170,
                              height: 170,
                            ),
                          ),
                          const Text(
                            'Benvenuto',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Accedi al tuo account',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF7F8C8D),
                            ),
                          ),
                          const SizedBox(height: 40),

                          // Campo username
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _usernameController,
                              decoration: InputDecoration(
                                labelText: 'Nome utente',
                                hintText: 'Inserisci il tuo username',
                                prefixIcon: Container(
                                  margin: const EdgeInsets.all(8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2196F3)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.person_rounded,
                                    color: Color(0xFF2196F3),
                                    size: 20,
                                  ),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.grey.withOpacity(0.05),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Campo password
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                hintText: 'Inserisci la tua password',
                                prefixIcon: Container(
                                  margin: const EdgeInsets.all(8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2196F3)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.lock_rounded,
                                    color: Color(0xFF2196F3),
                                    size: 20,
                                  ),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.grey.withOpacity(0.05),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Pulsante login
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      final username =
                                          _usernameController.text.trim();
                                      final password =
                                          _passwordController.text.trim();

                                      if (username.isEmpty ||
                                          password.isEmpty) {
                                        _showErrorDialog('Campi mancanti',
                                            'Inserisci username e password per effettuare il login.');
                                      } else {
                                        handleLogin(username, password);
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFC107),
                                foregroundColor: Colors.white,
                                elevation: 8,
                                shadowColor:
                                    const Color(0xFFFFC107).withOpacity(0.3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Accedi',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Link di supporto
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              TextButton(
                                onPressed: () {
                                  launchUrl(Uri.parse(
                                      '$urlSito/wp-login.php?action=register'));
                                },
                                child: const Text(
                                  'Registrati',
                                  style: TextStyle(
                                    color: Color(0xFF2196F3),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  launchUrl(Uri.parse(
                                      '$urlSito/wp-login.php?action=lostpassword'));
                                },
                                child: const Text(
                                  'Password\ndimenticata?',
                                  style: TextStyle(
                                    color: Color(0xFF2196F3),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Color(0xFF2196F3),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLogin();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      debugPrint('App riattivata, verifica sessione...');
      _checkLogin();
    }
  }

  Future<void> _checkLogin() async {
    debugPrint('check login user');
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('jwtToken');
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final username = prefs.getString('username');
    final password = prefs.getString('password');

    debugPrint('Dati salvati:');
    debugPrint(
        '- Token: ${savedToken != null ? "Presente (${savedToken.length} chars)" : "Assente"}');
    debugPrint('- isLoggedIn: $isLoggedIn');
    debugPrint('- Username: ${username != null ? "Presente" : "Assente"}');
    debugPrint('- Password: ${password != null ? "Presente" : "Assente"}');

    if (savedToken != null &&
        savedToken.isNotEmpty &&
        isLoggedIn &&
        username != null &&
        password != null) {
      jwtToken = savedToken;

      // Verifica se i cookie contengono una sessione valida
      if (jwtToken!.contains('wordpress_logged_in')) {
        debugPrint('Cookie di sessione valido, utente già loggato');

        // Verifica aggiuntiva: testa se la sessione è ancora attiva
        final isValid = await _verifySessionValidity();
        if (isValid) {
          debugPrint('Sessione verificata e valida, vai alla home');
          // Vai direttamente alla home
          if (context.mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const MyHomePage(
                  title: '',
                  userEmail: '',
                  userName: '',
                ),
              ),
            );
          }
        } else {
          debugPrint('Sessione non valida, riautenticazione automatica');
          await _autoReLogin(username, password);
        }
      } else {
        debugPrint('Cookie di sessione scaduto, riautenticazione automatica');
        // Prova a riautenticare automaticamente
        await _autoReLogin(username, password);
      }
    } else {
      debugPrint('Nessun token salvato, mostra onboarding');
      // Mostra l'onboarding che porta al login
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      }
    }
  }

  Future<bool> _verifySessionValidity() async {
    try {
      debugPrint('Verifica validità sessione...');

      // Prova ad accedere a un endpoint che richiede autenticazione
      final response = await http.get(
        Uri.parse('$urlSito/wp-json/wp/v2/users/me'),
        headers: {
          'Cookie': jwtToken!,
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );

      debugPrint('Verifica sessione status: ${response.statusCode}');

      if (response.statusCode == 200) {
        debugPrint('Sessione valida');
        return true;
      } else {
        debugPrint('Sessione non valida - status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Errore verifica sessione: $e');
      return false;
    }
  }

  Future<void> _autoReLogin(String username, String password) async {
    try {
      debugPrint('Tentativo riautenticazione automatica per: $username');

      // Prima ottieni il nonce necessario per il login
      final nonceResponse = await http.get(
        Uri.parse('$urlSito/wp-login.php'),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      );

      debugPrint('Nonce response status: ${nonceResponse.statusCode}');

      // Estrai il nonce dalla risposta HTML
      String nonce = '';
      final nonceMatch = RegExp(r'name="_wpnonce" value="([^"]+)"')
          .firstMatch(nonceResponse.body);
      if (nonceMatch != null) {
        nonce = nonceMatch.group(1)!;
        debugPrint('Nonce estratto: $nonce');
      }

      // Effettua login automatico con il nonce
      final loginResponse = await http.post(
        Uri.parse('$urlSito/wp-login.php'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Referer': '$urlSito/wp-login.php',
        },
        body: nonce.isNotEmpty
            ? 'log=$username&pwd=$password&wp-submit=Log+In&redirect_to=$urlSito/wp-admin/&testcookie=1&_wpnonce=$nonce'
            : 'log=$username&pwd=$password&wp-submit=Log+In&redirect_to=$urlSito/wp-admin/&testcookie=1',
      );

      debugPrint('Auto re-login response status: ${loginResponse.statusCode}');
      debugPrint('Auto re-login response headers: ${loginResponse.headers}');

      if (loginResponse.headers['set-cookie'] != null) {
        final cookies = loginResponse.headers['set-cookie']!;

        // Verifica se il login è riuscito
        if (loginResponse.statusCode == 302 ||
            loginResponse.headers['location']?.contains('wp-admin') == true ||
            loginResponse.body.contains('wp-admin') ||
            cookies.contains('wordpress_logged_in')) {
          // Riautenticazione riuscita
          jwtToken = cookies;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwtToken', jwtToken!);
          await prefs.setString('username', username);
          await prefs.setString('password', password);
          await prefs.setBool('isLoggedIn', true);

          debugPrint('Riautenticazione automatica riuscita');

          if (context.mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const MyHomePage(
                  title: '',
                  userEmail: '',
                  userName: '',
                ),
              ),
            );
          }
        } else {
          debugPrint(
              'Riautenticazione automatica fallita - login non riuscito');
          debugPrint('Response body: ${loginResponse.body}');
          // Non cancellare i dati, mostra direttamente il login
          if (context.mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          }
        }
      } else {
        debugPrint(
            'Riautenticazione automatica fallita - nessun cookie ricevuto');
        // Non cancellare i dati, mostra direttamente il login
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      }
    } catch (e) {
      debugPrint('Errore riautenticazione automatica: $e');
      // Non cancellare i dati, mostra direttamente il login
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mostra un loader mentre controlla
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  late List<dynamic> posts = [];
  late List<dynamic> translatedPosts = []; // Post tradotti
  String currentLanguage = 'it';
  bool isLoggedIn = false;
  int _selectedIndex = 0;
  Map<String, dynamic>? userData;
  bool isLoadingUserData = true;
  final Set<int> _notifiedUrgentPostIds = {};
  Timer? _notificationTimer;

  List<dynamic> wpMenuItems = [];
  bool isLoadingMenu = true;

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  void startUrgentNotificationWatcher(
      BuildContext context, List<dynamic> posts) {
    _notificationTimer?.cancel();
    _notificationTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      final urgentPosts = posts.where((post) {
        final isUrgente = _isUrgent(post);
        final id = post['id'];
        return isUrgente && !_notifiedUrgentPostIds.contains(id);
      }).toList();

      if (urgentPosts.isNotEmpty && context.mounted) {
        final latest = urgentPosts.first;
        final id = latest['id'];
        _notifiedUrgentPostIds.add(id);

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('🚨 Comunicazione urgente'),
            content: const Text('Nuova comunicazione urgente disponibile'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Chiudi'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Apri'),
              ),
            ],
          ),
        );
      }
    });
  }

  Future<void> fetchUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('jwtToken');
    final username = prefs.getString('username');

    if (savedToken != null) {
      jwtToken = savedToken;
      isLoggedIn = true;
    }

    setState(() {
      userData = {
        'name': username ?? 'Utente',
        'email': username ?? 'user@example.com',
        'id': 1,
      };
      isLoadingUserData = false;
    });

    debugPrint('Dati utente caricati: $userData');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    currentLanguage = languageProvider.locale.languageCode;
    languageProvider.addListener(_onLanguageChanged);
    _initializeWithTokenReload();
  }

  Future<void> _onLanguageChanged() async {
    final newLanguage = languageProvider.locale.languageCode;
    debugPrint('🏠 Home: Cambio lingua da $currentLanguage a $newLanguage');
    
    if (newLanguage != currentLanguage && posts.isNotEmpty) {
      currentLanguage = newLanguage;
      
      debugPrint('🏠 Home: Traduco ${posts.length} post in $newLanguage (2 alla volta)');
      
      // Traduci 2 post alla volta in parallelo
      final translated = <dynamic>[];
      for (int i = 0; i < posts.length; i += 2) {
        final batch = <Future<Map<String, dynamic>>>[];
        
        // Primo post del batch
        batch.add(translatePost(posts[i], newLanguage));
        
        // Secondo post del batch (se esiste)
        if (i + 1 < posts.length) {
          batch.add(translatePost(posts[i + 1], newLanguage));
        }
        
        // Attendi che entrambi i post siano tradotti
        final results = await Future.wait(batch);
        translated.addAll(results);
        
        debugPrint('📝 Home: Tradotti ${translated.length}/${posts.length} post');
      }

      debugPrint('✅ Home: Traduzione completata! ${translated.length} post tradotti');
      
      if (mounted) {
        setState(() {
          translatedPosts = translated;
        });
      }
    }
  }

  @override
  void dispose() {
    languageProvider.removeListener(_onLanguageChanged);
    WidgetsBinding.instance.removeObserver(this);
    _notificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeWithTokenReload() async {
    debugPrint('=== INIZIALIZZAZIONE CON RICARICA TOKEN ===');
    await reloadTokenFromStorage();

    debugPrint(
        'Token dopo ricarica: ${jwtToken != null ? "Presente" : "Mancante"}');
    if (jwtToken != null) {
      debugPrint(
          'Token contiene wordpress_logged_in: ${jwtToken!.contains('wordpress_logged_in')}');
      debugPrint('Token length: ${jwtToken!.length}');
    }

    if (jwtToken != null && !jwtToken!.contains('wordpress_logged_in')) {
      debugPrint('Token presente ma non valido, tentativo di rigenerazione...');
      await regenerateToken();
      await reloadTokenFromStorage();
      debugPrint(
          'Token dopo rigenerazione: ${jwtToken != null ? "Presente" : "Mancante"}');
    }

    await _initializeData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      debugPrint('App riattivata dalla pausa, verifica sessione...');
      _checkSessionAndReauth();
    }
  }

  Future<void> _checkSessionAndReauth() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('jwtToken');
    final username = prefs.getString('username');
    final password = prefs.getString('password');

    if (savedToken != null && username != null && password != null) {
      if (!savedToken.contains('wordpress_logged_in')) {
        debugPrint('Sessione scaduta durante la pausa, riautenticazione...');
        await _autoReLoginFromHome(username, password);
      } else {
        debugPrint('Sessione ancora valida');
      }
    }
  }

  Future<void> _autoReLoginFromHome(String username, String password) async {
    try {
      debugPrint('Riautenticazione automatica dalla home per: $username');

      // Prima ottieni il nonce necessario per il login
      final nonceResponse = await http.get(
        Uri.parse('$urlSito/wp-login.php'),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      );

      debugPrint('Nonce response status: ${nonceResponse.statusCode}');

      // Estrai il nonce dalla risposta HTML
      String nonce = '';
      final nonceMatch = RegExp(r'name="_wpnonce" value="([^"]+)"')
          .firstMatch(nonceResponse.body);
      if (nonceMatch != null) {
        nonce = nonceMatch.group(1)!;
        debugPrint('Nonce estratto: $nonce');
      }

      // Effettua login automatico con il nonce
      final loginResponse = await http.post(
        Uri.parse('$urlSito/wp-login.php'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Referer': '$urlSito/wp-login.php',
        },
        body: nonce.isNotEmpty
            ? 'log=$username&pwd=$password&wp-submit=Log+In&redirect_to=$urlSito/wp-admin/&testcookie=1&_wpnonce=$nonce'
            : 'log=$username&pwd=$password&wp-submit=Log+In&redirect_to=$urlSito/wp-admin/&testcookie=1',
      );

      debugPrint('Home re-login response status: ${loginResponse.statusCode}');
      debugPrint('Home re-login response headers: ${loginResponse.headers}');

      if (loginResponse.headers['set-cookie'] != null) {
        final cookies = loginResponse.headers['set-cookie']!;

        // Verifica se il login è riuscito
        if (loginResponse.statusCode == 302 ||
            loginResponse.headers['location']?.contains('wp-admin') == true ||
            loginResponse.body.contains('wp-admin') ||
            cookies.contains('wordpress_logged_in')) {
          jwtToken = cookies;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwtToken', jwtToken!);
          await prefs.setString('username', username);
          await prefs.setString('password', password);
          await prefs.setBool('isLoggedIn', true);

          debugPrint('Riautenticazione automatica dalla home riuscita');
          await _initializeData();
        } else {
          debugPrint('Riautenticazione automatica dalla home fallita');
          debugPrint('Response body: ${loginResponse.body}');
          // Non cancellare i dati, mostra direttamente il login
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          }
        }
      } else {
        debugPrint(
            'Riautenticazione automatica dalla home fallita - nessun cookie ricevuto');
        // Non cancellare i dati, mostra direttamente il login
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      }
    } catch (e) {
      debugPrint('Errore riautenticazione automatica dalla home: $e');
      // Non cancellare i dati, mostra direttamente il login
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  Future<void> _initializeData() async {
    debugPrint('=== INIZIALIZZAZIONE DATI ===');

    try {
      await fetchWpMenu();
      await fetchPosts();
      await fetchUserData();

      if (mounted) {
        startUrgentNotificationWatcher(context, posts);
        startTokenRefreshTimer();
      }

      debugPrint('Inizializzazione completata');
    } catch (e) {
      debugPrint('Errore durante inizializzazione: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore caricamento dati: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _testWordPressAPI() async {
    try {
      debugPrint('Test API WordPress 6.8.2...');

      // Test endpoint base
      final response = await http.get(
        Uri.parse('$urlSito/wp-json/wp/v2/'),
        headers: {
          'User-Agent': 'Flutter App/1.0',
          'Accept': 'application/json',
        },
      );

      debugPrint('WordPress API Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('WordPress API disponibile: ${data['name']}');
        debugPrint('WordPress versione: ${data['version']}');

        // Test se ci sono post disponibili
        await _testPostsAvailability();
      } else {
        debugPrint('WordPress API non accessibile: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Errore test WordPress API: $e');
    }
  }

  Future<void> _testPostsAvailability() async {
    try {
      debugPrint('Test disponibilità post...');

      // Test endpoint post base
      final response = await http.get(
        Uri.parse('$urlSito/wp-json/wp/v2/posts?per_page=5'),
        headers: {
          'User-Agent': 'Flutter App/1.0',
          'Accept': 'application/json',
        },
      );

      debugPrint('Test post status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        debugPrint('Post disponibili (test): ${data.length}');

        if (data.isNotEmpty) {
          debugPrint('Primo post: ${data[0]['title']['rendered']}');
          debugPrint('Status primo post: ${data[0]['status']}');
        }
      } else {
        debugPrint('Errore test post: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
      }
    } catch (e) {
      debugPrint('Errore test disponibilità post: $e');
    }
  }

  void startTokenRefreshTimer() {
    Timer.periodic(const Duration(minutes: 30), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (jwtToken != null && !jwtToken!.contains('wordpress_logged_in')) {
        debugPrint('Cookie di sessione scaduto, rigenerazione automatica');
        await regenerateToken();
      }
    });
  }

  // ------- fetchWpMenu / fetchPosts / helper: invariati dal tuo codice -------

  Future<void> fetchWpMenu() async {
    try {
      final response = await http.get(
        Uri.parse('$urlSito/wp-json/wp/v2/menu-items'),
        headers: {
          'Authorization': createBasicAuth('condominio', appPassword),
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> menuData = json.decode(response.body);
        setState(() {
          wpMenuItems = menuData;
          isLoadingMenu = false;
        });
      } else {
        setState(() {
          isLoadingMenu = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoadingMenu = false;
      });
    }
  }

  Future<void> fetchPosts() async {
    try {
      debugPrint('=== INIZIO DOWNLOAD POST ===');
      debugPrint(
          'JWT Token disponibile: ${jwtToken != null && jwtToken!.isNotEmpty}');

      // Prima verifica che l'API REST sia accessibile
      await _testWordPressAPI();

      // Usa sempre l'autenticazione se disponibile
      if (jwtToken != null && jwtToken!.isNotEmpty) {
        debugPrint(
            'Caricamento post con autenticazione utente per WordPress 6.8.2');
        await _tryFetchUserSpecificPosts();
      } else {
        debugPrint(
            'Nessun token di autenticazione disponibile - prova senza auth');
        await _tryFetchPostsWithoutAuth();
      }

      debugPrint('Post scaricati dopo primo tentativo: ${posts.length}');

      // Se non ha funzionato, prova endpoint alternativi
      if (posts.isEmpty) {
        debugPrint('Nessun post trovato, provo endpoint alternativi...');
        await _tryFetchPostsAlternative();
        debugPrint('Post scaricati dopo endpoint alternativi: ${posts.length}');
      }

      debugPrint('=== FINE DOWNLOAD POST: ${posts.length} post trovati ===');
      
      // Traduci i post se la lingua non è italiano (2 alla volta)
      if (currentLanguage != 'it' && posts.isNotEmpty) {
        debugPrint('🏠 Home: Traduco ${posts.length} post all\'avvio in $currentLanguage (2 alla volta)');
        final translated = <dynamic>[];
        
        for (int i = 0; i < posts.length; i += 2) {
          final batch = <Future<Map<String, dynamic>>>[];
          
          // Primo post del batch
          batch.add(translatePost(posts[i], currentLanguage));
          
          // Secondo post del batch (se esiste)
          if (i + 1 < posts.length) {
            batch.add(translatePost(posts[i + 1], currentLanguage));
          }
          
          // Attendi che entrambi i post siano tradotti
          final results = await Future.wait(batch);
          translated.addAll(results);
          
          debugPrint('📝 Home: Tradotti ${translated.length}/${posts.length} post all\'avvio');
        }
        
        if (mounted) {
          setState(() {
            translatedPosts = translated;
          });
        }
        debugPrint('✅ Home: ${translatedPosts.length} post tradotti all\'avvio');
      } else {
        translatedPosts = posts;
      }
    } catch (e) {
      debugPrint('Errore caricamento post: $e');
      await _fetchPostsAlternative();
    }
  }

  Future<void> _tryFetchPostsWithoutAuth() async {
    try {
      debugPrint('Tentativo 1: Caricamento post senza autenticazione');

      final response = await http.get(
        Uri.parse('$urlSito/wp-json/wp/v2/posts?per_page=20&status=publish'),
      );

      debugPrint('Status code (no auth): ${response.statusCode}');
      debugPrint('Response body (no auth): ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        debugPrint('Post ricevuti (no auth): ${data.length}');

        if (data.isNotEmpty) {
          _processPosts(data);
          return;
        }
      }
    } catch (e) {
      debugPrint('Errore caricamento senza auth: $e');
    }
  }

  Future<void> _tryFetchUserSpecificPosts() async {
    try {
      debugPrint('Caricamento post specifici per utente con Basic Auth');

      // Prima prova con Basic Auth
      await _tryFetchPostsWithBasicAuth();

      // Se non funziona, prova con l'approccio precedente
      if (posts.isEmpty) {
        debugPrint('Basic Auth fallito, provo approccio precedente...');
        await _verifyAuthentication();
        final userId = await _getCurrentUserId();
        await _tryFetchPostsViaAdminAjax();

        if (posts.isEmpty) {
          await _tryFetchPostsViaREST(userId);
        }
      }

      debugPrint('Post scaricati dopo primo tentativo: ${posts.length}');
    } catch (e) {
      debugPrint('Errore caricamento post specifici utente: $e');
    }
  }

  Future<void> _tryFetchPostsWithBasicAuth() async {
    try {
      debugPrint('=== TENTATIVO CON BASIC AUTH ===');

      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username');

      if (username == null) {
        debugPrint('Username non trovato per Basic Auth');
        return;
      }

      final basicAuth = createBasicAuth(username, appPassword);
      debugPrint('Basic Auth creata per utente: $username');

      // Lista di endpoint da provare con Basic Auth
      final endpoints = [
        '$urlSito/wp-json/wp/v2/posts?per_page=20&status=publish,private&_embed=wp:term,wp:featuredmedia&orderby=date&order=desc',
        '$urlSito/wp-json/wp/v2/posts?per_page=20&status=publish&_embed=wp:term&orderby=date&order=desc',
        '$urlSito/wp-json/wp/v2/posts?per_page=20&_embed=wp:term&orderby=date&order=desc',
        '$urlSito/wp-json/wp/v2/posts?per_page=20&orderby=date&order=desc',
        '$urlSito/wp-json/wp/v2/posts?per_page=20',
      ];

      for (final endpoint in endpoints) {
        try {
          debugPrint('Provando Basic Auth con endpoint: $endpoint');

          final response = await http.get(
            Uri.parse(endpoint),
            headers: {
              'Authorization': basicAuth,
              'Content-Type': 'application/json',
              'User-Agent': 'Flutter App/1.0',
              'Accept': 'application/json',
            },
          );

          debugPrint('Basic Auth status code: ${response.statusCode}');
          debugPrint('Basic Auth response body: ${response.body}');

          if (response.statusCode == 200) {
            final List<dynamic> data = json.decode(response.body);
            debugPrint('Post ricevuti con Basic Auth: ${data.length}');

            if (data.isNotEmpty) {
              _processPosts(data);
              debugPrint('SUCCESS: Post caricati con Basic Auth!');
              return;
            }
          } else if (response.statusCode == 401) {
            debugPrint('Basic Auth fallita (401) - credenziali non valide');
          } else if (response.statusCode == 403) {
            debugPrint('Basic Auth fallita (403) - permessi insufficienti');
          }
        } catch (e) {
          debugPrint('Errore Basic Auth con endpoint $endpoint: $e');
        }
      }
    } catch (e) {
      debugPrint('Errore generale Basic Auth: $e');
    }
  }

  Future<void> fetchUserPostsByCategory(int categoryId) async {
    try {
      debugPrint('Caricamento post utente per categoria: $categoryId');

      if (jwtToken == null || jwtToken!.isEmpty) {
        debugPrint('Nessun token disponibile per caricamento post categoria');
        return;
      }

      // Prima ottieni l'ID dell'utente corrente
      final userId = await _getCurrentUserId();

      final endpoints = [
        '$urlSito/wp-json/wp/v2/posts?author=$userId&categories=$categoryId&per_page=20&_embed=wp:term,wp:featuredmedia&orderby=date&order=desc',
        '$urlSito/wp-json/wp/v2/posts?categories=$categoryId&per_page=20&_embed=wp:term,wp:featuredmedia&orderby=date&order=desc',
        '$urlSito/wp-json/wp/v2/posts?author=$userId&categories=$categoryId&per_page=20&_embed=wp:term&orderby=date&order=desc',
        '$urlSito/wp-json/wp/v2/posts?categories=$categoryId&per_page=20&_embed=wp:term&orderby=date&order=desc',
      ];

      for (final endpoint in endpoints) {
        try {
          debugPrint('Provando endpoint categoria: $endpoint');

          final response = await http.get(
            Uri.parse(endpoint),
            headers: {
              'Cookie': jwtToken!,
              'Content-Type': 'application/json',
              'User-Agent': 'Flutter App/1.0',
              'Accept': 'application/json',
            },
          );

          debugPrint('Status code (categoria): ${response.statusCode}');

          if (response.statusCode == 200) {
            final List<dynamic> data = json.decode(response.body);
            debugPrint('Post categoria ricevuti: ${data.length}');

            if (data.isNotEmpty) {
              _processPosts(data);
              return;
            }
          }
        } catch (e) {
          debugPrint('Errore con endpoint categoria $endpoint: $e');
        }
      }
    } catch (e) {
      debugPrint('Errore caricamento post categoria: $e');
    }
  }

  Future<void> _tryFetchPostsViaAdminAjax() async {
    try {
      debugPrint('Tentativo di recupero post via wp-admin-ajax...');

      final response = await http.post(
        Uri.parse('$urlSito/wp-admin/admin-ajax.php'),
        headers: {
          'Cookie': jwtToken!,
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Referer': '$urlSito/wp-admin/',
        },
        body:
            'action=query_posts&post_type=post&post_status=publish,private&posts_per_page=20&orderby=date&order=desc',
      );

      debugPrint('Admin-ajax response status: ${response.statusCode}');
      debugPrint('Admin-ajax response body: ${response.body}');

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        try {
          final data = json.decode(response.body);
          if (data is List && data.isNotEmpty) {
            debugPrint('Post trovati via admin-ajax: ${data.length}');
            _processPosts(data);
          }
        } catch (e) {
          debugPrint('Errore parsing admin-ajax response: $e');
        }
      }
    } catch (e) {
      debugPrint('Errore admin-ajax: $e');
    }
  }

  Future<void> _tryFetchPostsViaREST(int? userId) async {
    // Endpoint per post specifici dell'utente con autenticazione
    List<String> endpoints = [];

    if (userId != null) {
      // Se abbiamo l'ID utente, prova prima i post specifici dell'utente
      endpoints.addAll([
        '$urlSito/wp-json/wp/v2/posts?author=$userId&per_page=20&_embed=wp:term,wp:featuredmedia&orderby=date&order=desc',
        '$urlSito/wp-json/wp/v2/posts?author=$userId&per_page=20&_embed=wp:term&orderby=date&order=desc',
        '$urlSito/wp-json/wp/v2/posts?author=$userId&per_page=20&orderby=date&order=desc',
      ]);
    }

    // Poi prova endpoint generali con autenticazione
    endpoints.addAll([
      '$urlSito/wp-json/wp/v2/posts?per_page=20&status=publish,private&_embed=wp:term,wp:featuredmedia&orderby=date&order=desc',
      '$urlSito/wp-json/wp/v2/posts?per_page=20&status=publish&_embed=wp:term&orderby=date&order=desc',
      '$urlSito/wp-json/wp/v2/posts?per_page=20&_embed=wp:term&orderby=date&order=desc',
      '$urlSito/wp-json/wp/v2/posts?per_page=20&orderby=date&order=desc',
      '$urlSito/wp-json/wp/v2/posts?per_page=20',
    ]);

    for (final endpoint in endpoints) {
      try {
        debugPrint('Provando endpoint specifico utente: $endpoint');

        final response = await http.get(
          Uri.parse(endpoint),
          headers: {
            'Cookie': jwtToken!,
            'Content-Type': 'application/json',
            'User-Agent': 'Flutter App/1.0',
            'Accept': 'application/json',
            'X-WP-Nonce': '', // Per WordPress 6.8.2
          },
        );

        debugPrint('Status code (user specific): ${response.statusCode}');
        debugPrint('Response body (user specific): ${response.body}');

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          debugPrint('Post ricevuti (user specific): ${data.length}');

          if (data.isNotEmpty) {
            _processPosts(data);
            return;
          }
        } else if (response.statusCode == 401) {
          debugPrint(
              'Errore 401: Token di autenticazione non valido per post utente');
          // Prova a rigenerare il token
          await regenerateToken();
          continue;
        }
      } catch (e) {
        debugPrint('Errore con endpoint utente $endpoint: $e');
      }
    }
  }

  Future<void> _verifyAuthentication() async {
    try {
      debugPrint('Verifica autenticazione...');

      if (jwtToken == null || jwtToken!.isEmpty) {
        debugPrint('Nessun token disponibile per verifica autenticazione');
        return;
      }

      // Prova a verificare l'autenticazione con diversi endpoint
      final endpoints = [
        '$urlSito/wp-json/wp/v2/users/me',
        '$urlSito/wp-admin/admin-ajax.php?action=heartbeat',
        '$urlSito/wp-json/wp/v2/',
      ];

      for (final endpoint in endpoints) {
        try {
          debugPrint('Test autenticazione con: $endpoint');

          final response = await http.get(
            Uri.parse(endpoint),
            headers: {
              'Cookie': jwtToken!,
              'Content-Type': 'application/json',
              'User-Agent': 'Flutter App/1.0',
              'Accept': 'application/json',
            },
          );

          debugPrint('Auth test status: ${response.statusCode}');

          if (response.statusCode == 200) {
            debugPrint('Autenticazione verificata con successo');
            return;
          } else if (response.statusCode == 401) {
            debugPrint('Autenticazione fallita (401) - token non valido');
          } else if (response.statusCode == 403) {
            debugPrint('Accesso negato (403) - permessi insufficienti');
          }
        } catch (e) {
          debugPrint('Errore test autenticazione $endpoint: $e');
        }
      }

      debugPrint(
          'Autenticazione non verificata - tentativo di rigenerazione token');
      await regenerateToken();
    } catch (e) {
      debugPrint('Errore verifica autenticazione: $e');
    }
  }

  Future<int?> _getCurrentUserId() async {
    try {
      debugPrint('Recupero ID utente corrente...');

      if (jwtToken == null || jwtToken!.isEmpty) {
        debugPrint('Nessun token disponibile per recupero ID utente');
        return null;
      }

      // Endpoint per ottenere l'utente corrente
      final response = await http.get(
        Uri.parse('$urlSito/wp-json/wp/v2/users/me'),
        headers: {
          'Cookie': jwtToken!,
          'Content-Type': 'application/json',
          'User-Agent': 'Flutter App/1.0',
          'Accept': 'application/json',
        },
      );

      debugPrint('User me response status: ${response.statusCode}');
      debugPrint('User me response body: ${response.body}');

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        final userId = userData['id'];
        debugPrint('ID utente recuperato: $userId');
        return userId;
      } else if (response.statusCode == 401) {
        debugPrint(
            'Token non valido per recupero ID utente - tentativo rigenerazione');
        await regenerateToken();
        return null;
      } else {
        debugPrint('Errore recupero ID utente: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Errore recupero ID utente: $e');
      return null;
    }
  }

  Future<void> _tryFetchPostsAlternative() async {
    try {
      debugPrint('Tentativo 3: Endpoint alternativi');

      // Prova endpoint diversi
      final endpoints = [
        '$urlSito/wp-json/wp/v2/posts',
      ];

      for (final endpoint in endpoints) {
        try {
          debugPrint('Provando endpoint: $endpoint');

          final response = await http.get(Uri.parse(endpoint));
          debugPrint('Status code per $endpoint: ${response.statusCode}');

          if (response.statusCode == 200) {
            final List<dynamic> data = json.decode(response.body);
            debugPrint('Post ricevuti da $endpoint: ${data.length}');

            if (data.isNotEmpty) {
              _processPosts(data);
              return;
            }
          }
        } catch (e) {
          debugPrint('Errore con endpoint $endpoint: $e');
        }
      }
    } catch (e) {
      debugPrint('Errore endpoint alternativi: $e');
    }
  }

  void _processPosts(List<dynamic> data) {
    debugPrint('=== PROCESSAMENTO POST ===');
    debugPrint('Post ricevuti da processare: ${data.length}');

    if (data.isEmpty) {
      debugPrint('Nessun post da processare');
      return;
    }

    // Log di tutti i post ricevuti
    for (int i = 0; i < data.length; i++) {
      final post = data[i];
      debugPrint(
          'Post $i: "${post['title']['rendered']}" - Status: ${post['status']} - Author: ${post['author']}');
    }

    // Con autenticazione, accetta tutti i post (pubblici e privati)
    final filtered = data.where((post) {
      final title = post['title']['rendered']?.toLowerCase() ?? '';
      final content = post['content']['rendered'] ?? '';
      final excerpt = post['excerpt']['rendered'] ?? '';
      final status = post['status'] ?? '';
      final authorId = post['author'] ?? 0;

      // Escludi solo post con contenuto completamente vuoto o con errori
      final hasEmptyContent = content.trim().isEmpty && excerpt.trim().isEmpty;
      final hasErrorContent =
          content.contains('error') || excerpt.contains('error');
      final hasRestrictedTitle = title.contains('restricted');

      final isValid =
          !hasEmptyContent && !hasErrorContent && !hasRestrictedTitle;

      if (!isValid) {
        debugPrint(
            'Post filtrato: "${post['title']['rendered']}" - Empty: $hasEmptyContent, Error: $hasErrorContent, Restricted: $hasRestrictedTitle');
      }

      return isValid;
    }).toList();

    debugPrint('Post filtrati: ${filtered.length}');

    // Log dettagliato dei post che verranno mostrati
    for (int i = 0; i < filtered.length && i < 5; i++) {
      final post = filtered[i];
      debugPrint(
          'Post finale ${i + 1}: "${post['title']['rendered']}" (${post['status']}) - Author: ${post['author']}');
    }

    if (mounted) {
      setState(() {
        posts = filtered;
      });
      debugPrint('=== POST AGGIORNATI NELLO STATE: ${posts.length} ===');
    } else {
      debugPrint('Widget non mounted, non aggiorno lo state');
    }
  }

  Future<void> _fetchPostsAlternative() async {
    try {
      debugPrint('Tentativo caricamento post alternativo...');

      // Prova a caricare i post direttamente dalla pagina principale
      final response = await http.get(
        Uri.parse('$urlSito/'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; Flutter App)',
        },
      );

      if (response.statusCode == 200) {
        // Non creare post di esempio, lascia la lista vuota
        if (mounted) {
          setState(() {
            posts = [];
          });
        }
        debugPrint('Nessun post disponibile, lista vuota');
      }
    } catch (e) {
      debugPrint('Errore caricamento post alternativo: $e');
      if (mounted) {
        setState(() {
          posts = [];
        });
      }
    }
  }

  // ---------------------------------------------------------------------------

  Widget _getBody() {
    switch (_selectedIndex) {
      case 0:
        return _homeContent();
      case 1:
        return ContactOptionsScreen(
          userName: userData?['name'] ?? '',
          userEmail: userData?['email'] ?? '',
        );
      case 2:
        return posts.isNotEmpty
            ? ModernArticlesScreen(
                posts: translatedPosts.isNotEmpty ? translatedPosts : posts,
                userName: userData?['name'] ?? '',
                userEmail: userData?['email'] ?? '',
              )
            : const NoAccessMessage();
      case 3:
        return const WebcamScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingUserData) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final String displayName =
        (userData?['name'] as String?)?.trim().isNotEmpty == true
            ? userData!['name'] as String
            : 'Utente';

    return Scaffold(
      endDrawer: Drawer(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.2), width: 1),
                        ),
                        child: Image.asset('assets/logo.png', height: 60),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context).portoBello,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          displayName,
                          style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),

                // Menu scrollabile
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildModernMenuItem(
                            context,
                            icon: Icons.link,
                            title: AppLocalizations.of(context).usefulSections,
                            subtitle:
                                AppLocalizations.of(context).linksAndResources,
                            color: const Color(0xFF4CAF50),
                            onTap: () {
                              Navigator.pop(context);
                              _showUsefulSections(context);
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildModernMenuItem(
                            context,
                            icon: Icons.contact_mail,
                            title: AppLocalizations.of(context).contacts,
                            subtitle:
                                AppLocalizations.of(context).contactThePort,
                            color: const Color(0xFF2196F3),
                            onTap: () {
                              Navigator.pop(context);
                              _openInAppBrowser(
                                  'https://www.new.portobellodigallura.it/numeri-util/');
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildModernMenuItem(
                            context,
                            icon: Icons.person,
                            title: AppLocalizations.of(context).account,
                            subtitle:
                                AppLocalizations.of(context).manageYourAccount,
                            color: const Color(0xFF9C27B0),
                            onTap: () {
                              Navigator.pop(context);
                              _showAccountInfo(context);
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildModernMenuItem(
                            context,
                            icon: Icons.info_outline,
                            title: AppLocalizations.of(context).appInfo,
                            subtitle:
                                AppLocalizations.of(context).versionAndDetails,
                            color: const Color(0xFFFF9800),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const AppInfoScreen()),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildModernMenuItem(
                            context,
                            icon: Icons.language,
                            title: AppLocalizations.of(context).language,
                            subtitle:
                                AppLocalizations.of(context).chooseLanguage,
                            color: const Color(0xFF00BCD4),
                            onTap: () {
                              Navigator.pop(context);
                              _showLanguageDialog(context);
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),

                // Logout
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFE91E63), Color(0xFFF06292)]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE91E63).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.logout,
                          color: Colors.white, size: 24),
                      title: Text(
                        AppLocalizations.of(context).logout,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                      onTap: () async {
                        await clearLoginData();
                        if (context.mounted) {
                          Navigator.pop(context);
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const MyApp()),
                          );
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Builder(
          builder: (ctx) => AppBar(
            backgroundColor: const Color(0xFFFFC107),
            elevation: 8,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            title: Row(
              children: [
                const SizedBox(width: 12),
                Image.asset('assets/logo.png', height: 40),
                const SizedBox(width: 12),
                Text(
                  AppLocalizations.of(context).portoDiGallura,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                tooltip: 'Menu',
              ),
            ],
          ),
        ),
      ),
      body: _getBody(),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFFFFC107),
        selectedItemColor: const Color(0xFF1565C0),
        unselectedItemColor: Colors.black54,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          BottomNavigationBarItem(
              icon: const Icon(Icons.home),
              label: AppLocalizations.of(context).home),
          BottomNavigationBarItem(
              icon: const Icon(Icons.contact_mail),
              label: AppLocalizations.of(context).services),
          BottomNavigationBarItem(
              icon: const Icon(Icons.room_service),
              label: AppLocalizations.of(context).articles),
          const BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt), label: 'WebCam'),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UTIL
  String _removeHtmlTags(String htmlText) {
    if (htmlText.isEmpty) return htmlText;
    final decodedText = decodeHtmlEntities(htmlText);
    final regex = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true);
    return decodedText.replaceAll(regex, '');
  }

  bool _isUrgent(dynamic post) {
    final categories = post['_embedded']?['wp:term']?[0];
    if (categories == null) return false;
    if (categories is! List) return false;
    return categories.any((c) =>
        (c['name'] as String?)?.toLowerCase().contains('urgenti') ?? false);
  }

  // ---------------------------------------------------------------------------
  // HOME CONTENT
  Widget _homeContent() {
    // Mostra indicatore di caricamento se i post sono vuoti e stiamo ancora caricando
    if (posts.isEmpty && isLoadingUserData) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFC107)),
            ),
            SizedBox(height: 16),
            Text(
              'Caricamento post...',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF666666),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final visiblePosts = posts.where((post) {
      final title =
          decodeHtmlEntities(post['title']?['rendered'] ?? '').toLowerCase();
      final content = decodeHtmlEntities(post['content']?['rendered'] ?? '');
      final excerpt = decodeHtmlEntities(post['excerpt']?['rendered'] ?? '');

      final hasRestrictedTitle = title.contains('restricted');
      final hasRestrictedContent = content.contains('effettuare il login') ||
          excerpt.contains('effettuare il login') ||
          excerpt.contains('devi essere loggato') ||
          content.trim().isEmpty;

      return !hasRestrictedTitle && !hasRestrictedContent;
    }).toList();

    // Urgenti in alto
    visiblePosts.sort((a, b) {
      final aUrg = _isUrgent(a) ? 1 : 0;
      final bUrg = _isUrgent(b) ? 1 : 0;
      return bUrg.compareTo(aUrg);
    });

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF81D4FA), Color(0xFFE1F5FE)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (visiblePosts.isNotEmpty)
                ...visiblePosts.map((post) {
                  final categories = post['_embedded']?['wp:term']?[0];
                  final categoryNames =
                      (categories is List && categories.isNotEmpty)
                          ? categories
                              .map<String>((c) => (c['name'] ?? '') as String)
                              .join(', ')
                          : 'Senza categoria';

                  final imageUrl =
                      post['_embedded']?['wp:featuredmedia']?[0]?['source_url'];
                  final isUrgente = _isUrgent(post);
                  final url = post['link'];
                  final authorId = post['author'] ?? 0;
                  final status = post['status'] ?? '';

                  final Color badgeColor = isUrgente
                      ? const Color(0xFFE53935)
                      : (status == 'private'
                          ? const Color(0xFFFF9800)
                          : const Color(0xFF2196F3));

                  return Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: Material(
                        borderRadius: BorderRadius.circular(24),
                        elevation: 0,
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PostDetailScreen(
                                  post: post,
                                  userName: userData?['name'] ?? 'Utente',
                                  userEmail: userData?['email'] ?? '',
                                ),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: isUrgente
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFFFFEBEE),
                                        Color(0xFFFFCDD2)
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : status == 'private'
                                      ? const LinearGradient(
                                          colors: [
                                            Color(0xFFFFF3E0),
                                            Color(0xFFFFE0B2)
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : const LinearGradient(
                                          colors: [
                                            Colors.white,
                                            Color(0xFFFAFAFA)
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                              border: isUrgente
                                  ? Border.all(
                                      color: const Color(0xFFE53935)
                                          .withOpacity(0.3),
                                      width: 2)
                                  : (status == 'private'
                                      ? Border.all(
                                          color: const Color(0xFFFF9800)
                                              .withOpacity(0.3),
                                          width: 1.5)
                                      : null),
                              boxShadow: [
                                BoxShadow(
                                  color: isUrgente
                                      ? Colors.red.withOpacity(0.2)
                                      : Colors.black.withOpacity(0.08),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (imageUrl != null)
                                    Stack(
                                      children: [
                                        Image.network(
                                          imageUrl,
                                          height: 180,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                        Positioned.fill(
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.transparent,
                                                  Colors.black.withOpacity(0.3)
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (isUrgente)
                                          Positioned(
                                            top: 12,
                                            left: 12,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE53935),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                      Icons
                                                          .priority_high_rounded,
                                                      color: Colors.white,
                                                      size: 16),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'URGENTE',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        if (status == 'private')
                                          Positioned(
                                            top: 12,
                                            right: 12,
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFF9800),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: const Icon(
                                                  Icons.lock_rounded,
                                                  color: Colors.white,
                                                  size: 16),
                                            ),
                                          ),
                                      ],
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color:
                                                    badgeColor.withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Icon(
                                                isUrgente
                                                    ? Icons
                                                        .priority_high_rounded
                                                    : (status == 'private'
                                                        ? Icons.lock_rounded
                                                        : Icons
                                                            .article_rounded),
                                                color: badgeColor,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                decodeHtmlEntities(post['title']
                                                        ?['rendered'] ??
                                                    ''),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: isUrgente
                                                      ? const Color(0xFFC62828)
                                                      : (status == 'private'
                                                          ? const Color(
                                                              0xFFE65100)
                                                          : const Color(
                                                              0xFF2C3E50)),
                                                  height: 1.3,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2196F3)
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          child: Text(
                                            categoryNames,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1976D2),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isUrgente
                                                    ? const Color(0xFFE53935)
                                                        .withOpacity(0.1)
                                                    : (status == 'private'
                                                        ? const Color(
                                                                0xFFFF9800)
                                                            .withOpacity(0.1)
                                                        : const Color(
                                                                0xFF4CAF50)
                                                            .withOpacity(0.1)),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                isUrgente
                                                    ? 'Urgente'
                                                    : (status == 'private'
                                                        ? 'Privato'
                                                        : 'Pubblico'),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isUrgente
                                                      ? const Color(0xFFE53935)
                                                      : (status == 'private'
                                                          ? const Color(
                                                              0xFFFF9800)
                                                          : const Color(
                                                              0xFF4CAF50)),
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            if (authorId is int && authorId > 0)
                                              const Text(
                                                'Autore',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          _removeHtmlTags(post['excerpt']
                                                  ?['rendered'] ??
                                              ''),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            color: Color(0xFF555555),
                                            height: 1.5,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        ElevatedButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    PostDetailScreen(
                                                  post: post,
                                                  userName: userData?['name'] ??
                                                      'Utente',
                                                  userEmail:
                                                      userData?['email'] ?? '',
                                                ),
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: badgeColor,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 24, vertical: 12),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16)),
                                            elevation: 4,
                                            shadowColor:
                                                badgeColor.withOpacity(0.3),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text('Leggi tutto',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 14)),
                                              SizedBox(width: 8),
                                              Icon(Icons.arrow_forward_rounded,
                                                  size: 16),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ));
                }).toList(),
              if (visiblePosts.isEmpty)
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.inbox_outlined,
                        size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Nessun articolo disponibile',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await fetchPosts();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Ricarica'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC107),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- i builder di item/menu/account restano invariati dal tuo codice originale ---
  Widget _buildModernMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.link, color: Colors.white, size: 24),
        ),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios,
            color: Colors.white70, size: 16),
        onTap: onTap,
      ),
    );
  }

  void _showUsefulSections(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Sezioni Utili',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF01579B)),
              ),
            ),
            _buildUsefulSectionItem(
              context,
              'Identità',
              'Dove siamo e chi siamo',
              Icons.location_on,
              () => _openInAppBrowser(
                  'https://www.new.portobellodigallura.it/dove-siamo/'),
            ),
            _buildUsefulSectionItem(
              context,
              'Numeri Utili',
              'Contatti e informazioni',
              Icons.phone,
              () => _openInAppBrowser(
                  'https://www.new.portobellodigallura.it/numeri-util/'),
            ),
            _buildUsefulSectionItem(
              context,
              'Servizi',
              'Tutti i nostri servizi',
              Icons.room_service,
              () => _openInAppBrowser(
                  'https://www.new.portobellodigallura.it/servizi/'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildUsefulSectionItem(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF0277BD).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF0277BD), size: 20),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _showAccountInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAccountInfoRow('Nome', userData?['name'] ?? 'N/A'),
            _buildAccountInfoRow('Email', userData?['email'] ?? 'N/A'),
            _buildAccountInfoRow('ID', userData?['id']?.toString() ?? 'N/A'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Icon(Icons.security, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Autenticazione attiva',
                      style: TextStyle(
                          color: Colors.blue, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Chiudi')),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final languages = [
      {'code': 'it', 'name': l10n.italian, 'flag': '🇮🇹'},
      {'code': 'en', 'name': l10n.english, 'flag': '🇬🇧'},
      {'code': 'fr', 'name': l10n.french, 'flag': '🇫🇷'},
      {'code': 'zh', 'name': l10n.chinese, 'flag': '🇨🇳'},
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00BCD4).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.language, color: Color(0xFF00BCD4)),
            ),
            const SizedBox(width: 12),
            Text(l10n.chooseLanguage),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: languages.map((lang) {
            final isSelected =
                languageProvider.locale.languageCode == lang['code'];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      isSelected ? const Color(0xFF00BCD4) : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
                color: isSelected
                    ? const Color(0xFF00BCD4).withOpacity(0.05)
                    : Colors.white,
              ),
              child: ListTile(
                leading: Text(
                  lang['flag']!,
                  style: const TextStyle(fontSize: 32),
                ),
                title: Text(
                  lang['name']!,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color:
                        isSelected ? const Color(0xFF00BCD4) : Colors.black87,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Color(0xFF00BCD4))
                    : null,
                onTap: () {
                  languageProvider.setLocale(Locale(lang['code']!));
                  Navigator.pop(context);
                },
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

class TabScreen extends StatelessWidget {
  final List<dynamic> posts;
  final String userName;
  final String userEmail;

  const TabScreen({
    super.key,
    required this.posts,
    required this.userName,
    required this.userEmail,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Porto di Gallura',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFFFFC107), // Giallo sole
          centerTitle: true,
          elevation: 6,
        ),
        backgroundColor: const Color(0xFFFFF8E1), // Sabbia chiara
        body: TabBarView(
          children: [
            posts.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : PostTab(posts: posts),
            EmailFormTab(
              userName: userName,
              userEmail: userEmail,
              subject: "Contatti",
            ),
          ],
        ),
        bottomNavigationBar: Container(
          color: const Color(0xFFFFC107), // Giallo sole
          child: const TabBar(
            indicatorColor: Color(0xFF1565C0),
            // Blu mare
            indicatorWeight: 4,
            labelColor: Colors.black,
            // Testo attivo
            unselectedLabelColor: Colors.black54,
            // Testo non attivo
            labelStyle: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            tabs: [
              Tab(icon: Icon(Icons.article), text: 'Home'),
              Tab(icon: Icon(Icons.email), text: 'Contatti'),
            ],
          ),
        ),
      ),
    );
  }
}

class AppInfoScreen extends StatelessWidget {
  const AppInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F7FA),
      appBar: AppBar(
        title: const Text('Informazioni App'),
        backgroundColor: const Color(0xFFFFC107),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Image.asset('assets/logo.png', height: 60),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Porto Bello di Gallura',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF01579B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'App Condominio',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0277BD),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Benvenuto nell\'applicazione ufficiale del Porto Bello di Gallura. '
                      'Questa app ti permette di rimanere sempre aggiornato sulle novità '
                      'del condominio e di accedere rapidamente ai servizi disponibili.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF37474F),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Funzionalità principali:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0277BD),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem('🏠 Home',
                        'Visualizza le ultime comunicazioni e novità'),
                    _buildFeatureItem('📞 Servizi',
                        'Contatta facilmente i servizi del porto'),
                    _buildFeatureItem(
                        '📰 Articoli', 'Naviga tra le categorie di articoli'),
                    _buildFeatureItem(
                        '📹 Webcam', 'Visualizza le webcam in tempo reale'),
                    const SizedBox(height: 20),
                    const Text(
                      'Informazioni tecniche:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0277BD),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                        '🔐 Sicurezza', 'Autenticazione JWT sicura'),
                    _buildFeatureItem(
                        '🔄 Sincronizzazione', 'Aggiornamenti automatici'),
                    _buildFeatureItem(
                        '📱 Multi-piattaforma', 'Disponibile su Android e iOS'),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFC107)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📞 Supporto',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF57C00),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Per assistenza tecnica o segnalazioni, contatta l\'amministrazione '
                            'del condominio attraverso la sezione "Servizi" dell\'app.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF37474F),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF01579B),
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF37474F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NoAccessMessage extends StatefulWidget {
  const NoAccessMessage({super.key});

  @override
  State<NoAccessMessage> createState() => _NoAccessMessageState();
}

class _NoAccessMessageState extends State<NoAccessMessage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, color: Color(0xFF1ABC9C), size: 40),
              SizedBox(height: 12),
              Text(
                'Non hai accesso a questi post',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  color: Color(0xFF2C3E50),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Contatta l’amministratore per ottenere i permessi necessari.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PostTab extends StatelessWidget {
  final List<dynamic> posts;

  const PostTab({super.key, required this.posts});

  String _removeHtmlTags(String htmlText) {
    if (htmlText.isEmpty) return htmlText;

    // Prima decodifica le entità HTML
    final decodedText = decodeHtmlEntities(htmlText);

    // Poi rimuovi i tag HTML rimanenti
    final regex = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true);
    return decodedText.replaceAll(regex, '');
  }

  @override
  Widget build(BuildContext context) {
    final visiblePosts = posts.where((post) {
      final title =
          decodeHtmlEntities(post['title']['rendered'] ?? '').toLowerCase();
      return !title.contains('restricted');
    }).toList();

    if (visiblePosts.isEmpty) {
      return const NoAccessMessage();
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF81D4FA), // Azzurro mare
            Color(0xFFE1F5FE), // Celeste chiaro
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        itemCount: visiblePosts.length,
        itemBuilder: (context, index) {
          final post = visiblePosts[index];
          final imageUrl =
              post['_embedded']?['wp:featuredmedia']?[0]?['source_url'];

          return Container(
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrl != null)
                    Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: 160,
                      fit: BoxFit.cover,
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                decodeHtmlEntities(
                                    post['title']['rendered'] ?? ''),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF01579B),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _removeHtmlTags(
                                  post['excerpt']['rendered'] ?? '',
                                ),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF37474F),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: Color(0xFF1ABC9C),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class ContactOptionsScreen extends StatelessWidget {
  final String userName;
  final String userEmail;

  const ContactOptionsScreen({
    super.key,
    required this.userName,
    required this.userEmail,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F7FA), // Azzurro mare
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).contactPort),
        backgroundColor: const Color(0xFFFFC107),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFE0F7FA), // Azzurro mare
              Color(0xFFF0F8FF), // Bianco azzurro
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppLocalizations.of(context).selectService,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF01579B),
                  ),
                ),
                const SizedBox(height: 30),
                _buildButton(context, AppLocalizations.of(context).gasCylinders, Icons.local_gas_station),
                _buildButton(context, AppLocalizations.of(context).waste, Icons.delete),
                _buildButton(context, AppLocalizations.of(context).malfunction, Icons.build),
                _buildButton(context, AppLocalizations.of(context).port, Icons.anchor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context, String label, IconData icon) {
    // Colori specifici per ogni servizio
    Color primaryColor;
    Color secondaryColor;
    final l10n = AppLocalizations.of(context);

    if (label == l10n.gasCylinders) {
      primaryColor = const Color(0xFFE91E63); // Rosa vibrante
      secondaryColor = const Color(0xFFF06292);
    } else if (label == l10n.waste) {
      primaryColor = const Color(0xFF4CAF50); // Verde natura
      secondaryColor = const Color(0xFF81C784);
    } else if (label == l10n.malfunction) {
      primaryColor = const Color(0xFFFF5722); // Arancione emergenza
      secondaryColor = const Color(0xFFFF8A65);
    } else if (label == l10n.port) {
      primaryColor = const Color(0xFF2196F3); // Blu oceano
      secondaryColor = const Color(0xFF64B5F6);
    } else {
      primaryColor = const Color(0xFF9C27B0); // Viola default
      secondaryColor = const Color(0xFFBA68C8);
    }

    return Container(
      width: double.infinity,
      height: 70,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white, size: 28),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EmailFormTab(
                userName: userName,
                userEmail: userEmail,
                subject: label,
              ),
            ),
          );
        },
      ),
    );
  }
}

class EmailFormTab extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String subject;

  const EmailFormTab({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.subject,
  });

  @override
  State<EmailFormTab> createState() => _EmailFormTabState();
}

class _EmailFormTabState extends State<EmailFormTab> {
  late final TextEditingController _emailController;
  late final TextEditingController _nameController;
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.userEmail);
    _nameController = TextEditingController(text: widget.userName);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    final email = _emailController.text.trim();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final messageText = _messageController.text.trim();

    if (email.isEmpty || messageText.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).fillRequiredFields)),
      );
      return;
    }

    try {
      // Prepara il corpo dell'email
      final emailBody = '''
Nome: $name
Email: $email
Telefono: ${phone.isNotEmpty ? phone : 'Non fornito'}
Oggetto: ${widget.subject}

Messaggio:
$messageText

---
Inviato dall'app Porto Bello di Gallura
      ''';

      // Apri l'app email del dispositivo
      await sendEmail(
        to: 'webmaster@portobellodigallura.it',
        subject: '${widget.subject} - $name',
        body: emailBody,
      );

      // Mostra messaggio di successo
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('App email aperta con successo!'),
            backgroundColor: Colors.green,
          ),
        );

        // Pulisci i campi
        _emailController.clear();
        _nameController.clear();
        _phoneController.clear();
        _messageController.clear();
      }
    } catch (e) {
      // Mostra messaggio di errore
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nell\'apertura dell\'app email: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F7FA),
      appBar: AppBar(
        title: Text(widget.subject),
        backgroundColor: const Color(0xFFFFC107),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueGrey.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(28.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.contact_mail,
                    size: 48, color: Color(0xFF0288D1)),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context).sendMessage,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF01579B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _nameController,
                  label: AppLocalizations.of(context).nameRequired,
                  icon: Icons.person,
                ),
                const SizedBox(height: 15),
                _buildTextField(
                  controller: _emailController,
                  label: AppLocalizations.of(context).emailRequired,
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 15),
                _buildTextField(
                  controller: _phoneController,
                  label: AppLocalizations.of(context).phoneOptional,
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 15),
                _buildTextField(
                  controller: _messageController,
                  label: AppLocalizations.of(context).messageRequired,
                  icon: Icons.message,
                  maxLines: 4,
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  icon: const Icon(Icons.send, color: Colors.white),
                  label: Text(AppLocalizations.of(context).send),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD54F),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 4,
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: _submitForm,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        filled: true,
        fillColor: Colors.grey[100],
      ),
    );
  }
}

class PostDetailScreen extends StatelessWidget {
  final Map<String, dynamic> post;
  final String userName;
  final String userEmail;

  const PostDetailScreen({
    super.key,
    required this.post,
    required this.userName,
    required this.userEmail,
  });

  String _removeHtmlTags(String htmlText) {
    if (htmlText.isEmpty) return htmlText;

    // Prima decodifica le entità HTML
    final decodedText = decodeHtmlEntities(htmlText);

    // Poi rimuovi i tag HTML rimanenti
    final regex = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true);
    return decodedText.replaceAll(regex, '');
  }

  @override
  Widget build(BuildContext context) {
    final title = decodeHtmlEntities(
        post['title']?['rendered'] ?? 'Titolo non disponibile');
    final content = _removeHtmlTags(
        post['content']?['rendered'] ?? 'Contenuto non disponibile');
    final excerpt = _removeHtmlTags(post['excerpt']?['rendered'] ?? '');
    final authorId = post['author'] ?? 0;
    final status = post['status'] ?? '';
    final date = post['date'] ?? '';
    final categories = post['_embedded']?['wp:term']?[0];
    final categoryNames = (categories != null && categories.isNotEmpty)
        ? categories.map<String>((c) => (c['name'] ?? '') as String).join(', ')
        : 'Senza categoria';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dettaglio Post'),
        backgroundColor: const Color(0xFF01579B),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titolo
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF01579B),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),

            // Informazioni del post
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        status == 'private' ? Icons.lock : Icons.public,
                        size: 16,
                        color:
                            status == 'private' ? Colors.orange : Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        status == 'private' ? 'Privato' : 'Pubblico',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: status == 'private'
                              ? Colors.orange
                              : Colors.green,
                        ),
                      ),
                      const Spacer(),
                      if (authorId > 0)
                        Text(
                          'Autore: $authorId',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Categorie: $categoryNames',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  if (date.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Data: ${DateTime.tryParse(date)?.toString().split(' ')[0] ?? date}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Excerpt se disponibile
            if (excerpt.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF2196F3).withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Anteprima:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1976D2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      excerpt,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF424242),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Contenuto principale
            const Text(
              'Contenuto:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF01579B),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                content,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF424242),
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
