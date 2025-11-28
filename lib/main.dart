import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:condominio/app_theme.dart';
import 'package:condominio/l10n/app_localizations.dart';
import 'package:condominio/language_provider.dart';
import 'package:condominio/setttings.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart';
import 'package:webview_flutter/webview_flutter.dart';

// Cache per le traduzioni
final Map<String, Map<String, String>> _translationCache = {};

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
    final uri =
        Uri.parse(AppSettings.translationApiUrl).replace(queryParameters: {
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

      if (statusOk &&
          data['responseData'] != null &&
          data['responseData']['translatedText'] != null) {
        final translatedText = data['responseData']['translatedText'] as String;

        // Debug per verificare la traduzione
        debugPrint(
            'Tradotto: "${text.substring(0, text.length > 50 ? 50 : text.length)}" → "${translatedText.substring(0, translatedText.length > 50 ? 50 : translatedText.length)}"');

        // Salva in cache
        if (!_translationCache.containsKey(targetLanguage)) {
          _translationCache[targetLanguage] = {};
        }
        _translationCache[targetLanguage]![text] = translatedText;

        return translatedText;
      } else {
        debugPrint(
            'Errore traduzione MyMemory: status=$responseStatus, details=${data['responseDetails']}');
        return text;
      }
    } else {
      debugPrint(
          'Errore API MyMemory: ${response.statusCode} - ${response.body}');
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
  String? replyTo,
}) async {
  // SMTP Configuration
  const smtpServer = 'pro.eu.turbo-smtp.com';
  const smtpPort = 25;
  const smtpUsername = 'webmaster@portobellodigallura.it';
  const smtpPassword = 'FwPDvGt9';

  try {
    // Configurazione del server SMTP
    final smtpServerConfig = SmtpServer(
      smtpServer,
      port: smtpPort,
      username: smtpUsername,
      password: smtpPassword,
      ignoreBadCertificate: true,
      allowInsecure: true,
    );

    // Crea il messaggio
    final message = mailer.Message()
      ..from = const mailer.Address(smtpUsername, 'Portobello di Gallura')
      ..recipients.add(to)
      ..subject = subject ?? 'Messaggio dall\'app Portobello'
      ..text = body ?? '';

    // Aggiungi reply-to se fornito
    if (replyTo != null && replyTo.isNotEmpty) {
      message.headers['Reply-To'] = replyTo;
    }

    // Invia l'email
    final sendReport = await mailer.send(message, smtpServerConfig);
    debugPrint('Email inviata con successo via SMTP: ${sendReport.toString()}');
  } catch (e) {
    debugPrint('Errore invio email via SMTP: $e');
    // Fallback: prova ad aprire il client email locale
    final uri = Uri(
      scheme: 'mailto',
      path: to,
      queryParameters: {
        if (subject != null) 'subject': subject,
        if (body != null) 'body': body,
      },
    );

    try {
      final canLaunch = await canLaunchUrl(uri).timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );

      if (canLaunch) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw Exception('Impossibile inviare email');
      }
    } catch (fallbackError) {
      debugPrint('Errore anche con fallback email client: $fallbackError');
      throw Exception('Errore invio email: $e');
    }
  }
}

// Funzione per creare l'autenticazione Basic Auth
String createBasicAuth(String username, String password) {
  print(password);
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
      appSettings.setToken(savedToken);
      debugPrint('Token ricaricato dalle SharedPreferences');
      debugPrint(
          'Token valido: ${appSettings.jwtToken?.contains('wordpress_logged_in')}');
    } else {
      appSettings.clearToken();
      debugPrint('Nessun token valido trovato nelle SharedPreferences');
      if (savedToken == null) debugPrint('Motivo: Token null');
      if (savedToken != null && savedToken.isEmpty)
        debugPrint('Motivo: Token vuoto');
      if (!isLoggedIn) debugPrint('Motivo: isLoggedIn = false');
    }
  } catch (e) {
    debugPrint('Errore ricaricamento token: $e');
    appSettings.clearToken();
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
        Uri.parse('${appSettings.urlLogin}'),
        headers: {
          'User-Agent': AppSettings.userAgent,
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
        Uri.parse(appSettings.urlLogin),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': AppSettings.userAgent,
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Referer': appSettings.urlLogin,
        },
        body: nonce.isNotEmpty
            ? 'log=$username&pwd=$password&wp-submit=Log+In&redirect_to=${appSettings.urlAdmin}&testcookie=1&_wpnonce=$nonce'
            : 'log=$username&pwd=$password&wp-submit=Log+In&redirect_to=${appSettings.urlAdmin}&testcookie=1',
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
          appSettings.setToken(cookies);
          await prefs.setString('jwtToken', appSettings.jwtToken!);
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
      Uri.parse(appSettings.urlAdmin),
      headers: {
        'Cookie': appSettings.jwtToken!,
        'User-Agent': AppSettings.userAgent,
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
  debugPrint('🔓 Logout - cancellazione dati utente');
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('jwtToken');
  await prefs.remove('username');
  await prefs.remove('password');
  await prefs.remove('originalUsername');
  await prefs.remove('originalEmail');
  await prefs.setBool('isLoggedIn', false);
  appSettings.clearToken();
  debugPrint('✅ Tutti i dati utente cancellati');
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
final GlobalKey<_MyHomePageState> homePageKey = GlobalKey<_MyHomePageState>();

// Variabile per gestire la navigazione dalle notifiche
int? _pendingNotificationPostId;

// Inizializzazione plugin notifiche locali
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

bool _notificationsPermissionGranted = false;
bool _hasRequestedNotificationPermissions = false;
bool _hasShownNotificationPermissionWarning = false;
bool _androidNotificationsGranted = false;
bool _iosNotificationsGranted = false;

Future<bool> _updateNotificationPermissionStatus(
    {bool requestUserPermission = false}) async {
  bool androidGranted = _androidNotificationsGranted;
  bool iosGranted = _iosNotificationsGranted;

  if (Platform.isAndroid) {
    final androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      if (requestUserPermission || !_hasRequestedNotificationPermissions) {
        final bool? permissionResult =
            await androidImplementation.requestNotificationsPermission();
        if (permissionResult != null) {
          androidGranted = permissionResult;
        }
      }

      final bool? areEnabled =
          await androidImplementation.areNotificationsEnabled();
      if (areEnabled != null) {
        androidGranted = areEnabled;
      }
    } else {
      androidGranted = true;
    }
  } else {
    androidGranted = true;
  }

  if (Platform.isIOS) {
    final iosImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    if (iosImplementation != null) {
      if (requestUserPermission || !_hasRequestedNotificationPermissions) {
        final bool? permissionResult =
            await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        if (permissionResult != null) {
          iosGranted = permissionResult;
        }
      }
    } else {
      iosGranted = true;
    }
  } else {
    iosGranted = true;
  }

  _androidNotificationsGranted = androidGranted;
  _iosNotificationsGranted = iosGranted;
  _notificationsPermissionGranted = androidGranted && iosGranted;
  debugPrint(
      '🔐 Stato permessi notifiche -> Android: $androidGranted, iOS: $iosGranted, Totale: $_notificationsPermissionGranted');
  return _notificationsPermissionGranted;
}

// Funzione per inizializzare le notifiche locali
Future<void> initializeNotifications() async {
  // Configurazione Android
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  // Configurazione iOS
  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  // Configurazione completa
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  final NotificationAppLaunchDetails? launchDetails =
      await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();

  if (launchDetails?.didNotificationLaunchApp ?? false) {
    final payload = launchDetails?.notificationResponse?.payload;
    if (payload != null && payload.isNotEmpty) {
      final launchedPostId = int.tryParse(payload);
      if (launchedPostId != null) {
        _pendingNotificationPostId = launchedPostId;
      }
    }
  }

  // Inizializza il plugin
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      debugPrint('Notifica tappata: ${response.payload}');
      // Naviga al post quando viene tappata la notifica
      if (response.payload != null && response.payload!.isNotEmpty) {
        final postId = int.tryParse(response.payload!);
        if (postId != null) {
          _pendingNotificationPostId = postId;
          final homeState = homePageKey.currentState;
          if (homeState != null) {
            unawaited(homeState.openPostFromNotification(postId));
          } else {
            navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const SplashScreen(),
              ),
              (route) => false,
            );
          }
        }
      }
    },
  );

  // ANDROID: Crea il canale notifiche per Android 8.0+ (Oreo)
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'urgent_channel', // ID canale (deve corrispondere a quello usato nelle notifiche)
    'Comunicazioni Urgenti', // Nome canale
    description: 'Notifiche per comunicazioni urgenti del condominio',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  _notificationsPermissionGranted =
      await _updateNotificationPermissionStatus(requestUserPermission: true);
  _hasRequestedNotificationPermissions = true;

  if (_notificationsPermissionGranted) {
    debugPrint('✅ Sistema notifiche inizializzato con permessi concessi');
  } else {
    debugPrint('⚠️ Sistema notifiche inizializzato ma permessi non concessi');
  }
}

// Funzione per mostrare una notifica locale
Future<void> showLocalNotification({
  required int id,
  required String title,
  required String body,
  String? payload,
}) async {
  // Configurazione Android
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'urgent_channel', // ID canale
    'Comunicazioni Urgenti', // Nome canale
    channelDescription: 'Notifiche per comunicazioni urgenti del condominio',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
    icon: '@mipmap/ic_launcher',
  );

  // Configurazione iOS
  const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  // Configurazione completa
  const NotificationDetails notificationDetails = NotificationDetails(
    android: androidDetails,
    iOS: iosDetails,
  );

  if (!_notificationsPermissionGranted) {
    await _updateNotificationPermissionStatus(
      requestUserPermission: !_hasRequestedNotificationPermissions,
    );
    _hasRequestedNotificationPermissions = true;

    if (!_notificationsPermissionGranted) {
      final context = navigatorKey.currentContext;
      if (context != null &&
          context.mounted &&
          !_hasShownNotificationPermissionWarning) {
        _hasShownNotificationPermissionWarning = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Abilita le notifiche dalle impostazioni per ricevere gli avvisi urgenti.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      debugPrint(
          '❌ Notifica locale non mostrata: permessi notifiche non concessi');
      return;
    }
  }

  // Mostra la notifica
  await flutterLocalNotificationsPlugin.show(
    id,
    title,
    body,
    notificationDetails,
    payload: payload,
  );

  debugPrint('📱 Notifica locale mostrata: $title - $body');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inizializza le notifiche locali
  await initializeNotifications();

  runApp(const MyApp());
}

class ModernArticlesScreen extends StatefulWidget {
  final List<dynamic> posts;
  final String userName;
  final String userEmail;
  final bool
      showDirectList; // true = mostra lista post, false = mostra categorie

  const ModernArticlesScreen({
    super.key,
    required this.posts,
    required this.userName,
    required this.userEmail,
    this.showDirectList = false, // default: mostra categorie
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

    // 🔥 Se showDirectList = true, mostra direttamente i post (non le categorie)
    if (widget.showDirectList) {
      showCategories = false;
      currentCategory = 'Tutti i post';
    }

    if (currentLanguage != 'it') {
      _translatePostsOnInit();
    } else {
      _buildCategoryMap();
      filteredPosts = widget.posts;
    }

    languageProvider.addListener(_onLanguageChanged);
  }

  Future<void> _translatePostsOnInit() async {
    debugPrint(
        '🌍 Inizio traduzione ${widget.posts.length} post in $currentLanguage');
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

      debugPrint(
          '🌍 Inizio traduzione ${widget.posts.length} post in $newLanguage');

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

    // Recupera la localizzazione in modo sicuro
    String withoutCategoryText = 'Senza categoria';
    try {
      final localizations = AppLocalizations.of(context);
      withoutCategoryText = localizations.withoutCategory;
    } catch (e) {
      debugPrint(
          '⚠️ Errore caricamento localizzazioni in _buildCategoryMap: $e');
    }

    for (final post in translatedPosts) {
      final categories = post['_embedded']?['wp:term']?[0];
      final names = (categories != null && categories.isNotEmpty)
          ? categories.map<String>((c) => c['name'] as String).toList()
          : [withoutCategoryText];

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

        // Ordina i post per data (più recente prima)
        filteredPosts.sort((a, b) {
          try {
            final dateA = DateTime.parse(a['date'] ?? '');
            final dateB = DateTime.parse(b['date'] ?? '');
            return dateB
                .compareTo(dateA); // Ordine decrescente (più recente prima)
          } catch (e) {
            return 0;
          }
        });
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
    // Recupera la localizzazione in modo sicuro
    String allText = 'Tutti';
    try {
      final localizations = AppLocalizations.of(context);
      allText = localizations.all;
    } catch (e) {
      debugPrint(
          '⚠️ Errore caricamento localizzazioni in _getAvailableCategories: $e');
    }

    final Set<String> categories = {allText};
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
                          color: AppColors.secondaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.folder_outlined,
                          color: AppColors.secondaryBlue,
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
                            Builder(
                              builder: (ctx) {
                                String articlesText = 'articoli';
                                try {
                                  final localizations =
                                      AppLocalizations.of(ctx);
                                  articlesText =
                                      localizations.articles.toLowerCase();
                                } catch (e) {
                                  debugPrint(
                                      '⚠️ Errore caricamento localizzazioni: $e');
                                }
                                return Text(
                                  '$postCount $articlesText',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                );
                              },
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
        // Pulsante Back per tornare alle categorie (solo se NON showDirectList)
        if (!widget.showDirectList)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.primary),
                  onPressed: _goBackToCategories,
                  tooltip: 'Torna alle categorie',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    currentCategory,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        // Barra di ricerca espandibile
        if (isSearchExpanded)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Builder(
                  builder: (ctx) {
                    String searchHint = 'Cerca articoli...';
                    try {
                      final localizations = AppLocalizations.of(ctx);
                      searchHint = localizations.searchArticles;
                    } catch (e) {
                      debugPrint('⚠️ Errore caricamento localizzazioni: $e');
                    }
                    return TextField(
                      decoration: InputDecoration(
                        hintText: searchHint,
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
                    );
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
                    foregroundColor: AppColors.primary,
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
                  : widget.showDirectList
                      ? ListView.builder(
                          // NEWS: niente pull-to-refresh
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredPosts.length,
                          itemBuilder: (context, index) {
                            if (index >= filteredPosts.length) {
                              return const SizedBox.shrink();
                            }
                            return _buildArticleCard(filteredPosts[index]);
                          },
                        )
                      : RefreshIndicator(
                          // ARTICOLI: con pull-to-refresh
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
    // Controllo di sicurezza per evitare errori se il context non è disponibile
    String noArticlesText = 'Nessun articolo trovato';
    String tryModifyText = 'Prova a modificare i filtri di ricerca';

    try {
      final localizations = AppLocalizations.of(context);
      noArticlesText = localizations.noArticlesFound;
      tryModifyText = localizations.tryModifyFilters;
    } catch (e) {
      debugPrint(
          '⚠️ Errore caricamento localizzazioni in _buildEmptyState: $e');
    }

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
            noArticlesText,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tryModifyText,
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
      final bool isUrgente = _isPostUrgent(post);

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
              color: isUrgente
                  ? const Color(0xFFE53935).withOpacity(0.3)
                  : Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: isUrgente
                  ? const Color(0xFFE53935).withOpacity(0.15)
                  : Colors.black.withOpacity(0.04),
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
                color: isUrgente ? const Color(0xFFFFEBEE) : null,
                gradient: isUrgente
                    ? null
                    : (status == 'private'
                        ? const LinearGradient(
                            colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : const LinearGradient(
                            colors: [Colors.white, Color(0xFFFAFAFA)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )),
                border: isUrgente
                    ? Border.all(
                        color: const Color(0xFFE53935),
                        width: 3,
                      )
                    : (status == 'private'
                        ? Border.all(
                            color: const Color(0xFFFF9800).withOpacity(0.3),
                            width: 1.5,
                          )
                        : null),
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
                                : AppColors.secondaryBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            status == 'private'
                                ? Icons.lock_rounded
                                : Icons.article_rounded,
                            color: status == 'private'
                                ? const Color(0xFFFF9800)
                                : AppColors.secondaryBlue,
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
                            color: isUrgente
                                ? const Color(0xFFE53935).withOpacity(0.1)
                                : (status == 'private'
                                    ? const Color(0xFFFF9800).withOpacity(0.1)
                                    : const Color(0xFF4CAF50).withOpacity(0.1)),
                            borderRadius: BorderRadius.circular(12),
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
                                      ? const Color(0xFFFF9800)
                                      : const Color(0xFF4CAF50)),
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
                        const Spacer(),
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
        .replaceAll('::', '')
        .replaceAll(RegExp(r'/\d+'), '') // Rimuove /2, /3, /4, etc.
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }

  bool _isPostUrgent(Map<String, dynamic> post) {
    final categories = post['_embedded']?['wp:term']?[0];
    if (categories == null) return false;
    if (categories is! List) return false;
    return categories.any((c) {
      final name = (c['name'] as String?)?.toLowerCase() ?? '';
      return name
          .contains('urgent'); // copre: urgente, urgenti, urgent, urgency
    });
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
        title: Text(
          widget.category,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.secondary,
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
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CustomWebViewScreen(
                                  url: url,
                                  title: title,
                                ),
                              ),
                            );
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
                                            : AppColors.secondaryBlue
                                                .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        status == 'private'
                                            ? Icons.lock_rounded
                                            : Icons.article_rounded,
                                        color: status == 'private'
                                            ? const Color(0xFFFF9800)
                                            : AppColors.secondaryBlue,
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
    return decodedText
        .replaceAll(regex, '')
        .replaceAll('::', '')
        .replaceAll(RegExp(r'/\d+'), ''); // Rimuove /2, /3, /4, etc.
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

// Schermata WebView personalizzata con pulsante di back
class CustomWebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const CustomWebViewScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<CustomWebViewScreen> createState() => _CustomWebViewScreenState();
}

class _CustomWebViewScreenState extends State<CustomWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _canGoBack = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            _checkCanGoBack();
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _checkCanGoBack() async {
    final canGoBack = await _controller.canGoBack();
    if (mounted) {
      setState(() {
        _canGoBack = canGoBack;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_canGoBack) {
              _controller.goBack();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(widget.title),
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

class WebcamScreen extends StatelessWidget {
  const WebcamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Container(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: ListView(
              children: [
                const SizedBox(height: 20),
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CustomWebViewScreen(
                          url: AppSettings.webcamPorto,
                          title: AppLocalizations.of(context).portWebcam,
                        ),
                      ),
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CustomWebViewScreen(
                          url: AppSettings.webcamPanoramica,
                          title: AppLocalizations.of(context).panoramicWebcam,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                _buildWebcamCard(
                  context,
                  icon: Icons.wb_sunny_rounded,
                  title: AppLocalizations.of(context).weatherStation,
                  subtitle: AppLocalizations.of(context).weatherData,
                  description:
                      AppLocalizations.of(context).checkWeatherConditions,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE67E22), Color(0xFFD35400)],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CustomWebViewScreen(
                          url: AppSettings.stazioneMeteo,
                          title: AppLocalizations.of(context).weatherStation,
                        ),
                      ),
                    );
                  },
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.8),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
      theme: AppTheme.theme,
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
                  children: List.generate(2, (index) {
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
                      'Ricevi le comunicazioni\n relative al condominio e richiedi\n i nostri servizi',
                      'Gestisci facilmente tutte le informazioni relative al tuo condominio in modo semplice e intuitivo.',
                      const Color(0xFF3498DB),
                    ),
                    _buildOnboardingPage(
                      Icons.notifications_rounded,
                      'Rimani sempre aggiornato!',
                      'Visualizza le ultime novità, comunicazioni e aggiornamenti riguardanti il tuo condominio.',
                      const Color(0xFFE74C3C),
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
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.black,
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
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
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
        Uri.parse('${appSettings.urlLogin}'),
        headers: {
          'User-Agent': AppSettings.userAgent,
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
        Uri.parse('${appSettings.urlLogin}'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': AppSettings.userAgent,
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Referer': '${appSettings.urlLogin}',
        },
        body: nonce.isNotEmpty
            ? 'log=$username&pwd=$password&wp-submit=Log+In&redirect_to=${appSettings.urlAdmin}&testcookie=1&_wpnonce=$nonce'
            : 'log=$username&pwd=$password&wp-submit=Log+In&redirect_to=${appSettings.urlAdmin}&testcookie=1',
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
          appSettings.setToken(cookies);

          // Salva le credenziali e i cookie
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwtToken', appSettings.jwtToken!);
          await prefs.setString('username', username);
          await prefs.setString('password', password);
          await prefs.setBool('isLoggedIn', true);

          // Salva i dati dell'utente originale per la visualizzazione nell'app
          await prefs.setString('originalUsername', username);
          await prefs.setString('originalEmail', username);

          debugPrint('Login successful, cookies saved');
          debugPrint('Dati utente originale salvati: $username');

          if (context.mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => MyHomePage(
                  key: homePageKey,
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
                                    color: AppColors.secondaryBlue
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.person_rounded,
                                    color: AppColors.secondaryBlue,
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
                                    color: AppColors.secondaryBlue
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.lock_rounded,
                                    color: AppColors.secondaryBlue,
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
                                        print(password);
                                        handleLogin(username, password);
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                foregroundColor: Colors.black,
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
                                        color: Colors.black,
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
                                      '${appSettings.urlLogin}?action=register'));
                                },
                                child: const Text(
                                  'Registrati',
                                  style: TextStyle(
                                    color: AppColors.secondaryBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  launchUrl(Uri.parse(
                                      '${appSettings.urlLogin}?action=lostpassword'));
                                },
                                child: const Text(
                                  'Password\ndimenticata?',
                                  style: TextStyle(
                                    color: AppColors.secondaryBlue,
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
                  color: AppColors.secondaryBlue,
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
    debugPrint('🔑 Check login user');
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('jwtToken');
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final username = prefs.getString('username');
    final password = prefs.getString('password');

    debugPrint('📊 Dati salvati:');
    debugPrint(
        '- Token: ${savedToken != null ? "Presente (${savedToken.length} chars)" : "Assente"}');
    debugPrint('- isLoggedIn: $isLoggedIn');
    debugPrint('- Username: ${username != null ? "Presente" : "Assente"}');
    debugPrint('- Password: ${password != null ? "Presente" : "Assente"}');

    // Se l'utente ha fatto login almeno una volta, mantienilo loggato
    if (isLoggedIn && username != null && password != null) {
      debugPrint('✅ Utente precedentemente loggato, mantengo la sessione');

      // Carica il token se presente
      if (savedToken != null && savedToken.isNotEmpty) {
        appSettings.setToken(savedToken);
        debugPrint('🔐 Token caricato dalla memoria');
      } else {
        debugPrint('⚠️ Token mancante, genero nuovo token...');
      }

      // Vai alla home - la home gestirà eventuali problemi di sessione
      if (context.mounted) {
        debugPrint('🏠 Navigo alla home page');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MyHomePage(
              key: homePageKey,
              title: '',
              userEmail: '',
              userName: '',
            ),
          ),
        );
      }
    } else {
      debugPrint('❌ Nessun login precedente, mostra onboarding');
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
        Uri.parse('${appSettings.urlApi}users/me'),
        headers: {
          'Cookie': appSettings.jwtToken!,
          'User-Agent': AppSettings.userAgent,
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
        Uri.parse('${appSettings.urlLogin}'),
        headers: {
          'User-Agent': AppSettings.userAgent,
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
        Uri.parse('${appSettings.urlLogin}'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': AppSettings.userAgent,
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Referer': '${appSettings.urlLogin}',
        },
        body: nonce.isNotEmpty
            ? 'log=$username&pwd=$password&wp-submit=Log+In&redirect_to=${appSettings.urlAdmin}&testcookie=1&_wpnonce=$nonce'
            : 'log=$username&pwd=$password&wp-submit=Log+In&redirect_to=${appSettings.urlAdmin}&testcookie=1',
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
          appSettings.setToken(cookies);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwtToken', appSettings.jwtToken!);
          await prefs.setString('username', username);
          await prefs.setString('password', password);
          await prefs.setBool('isLoggedIn', true);

          // Salva i dati dell'utente originale per la visualizzazione nell'app
          await prefs.setString('originalUsername', username);
          await prefs.setString('originalEmail', username);

          debugPrint('Riautenticazione automatica riuscita');
          debugPrint('Dati utente originale salvati: $username');

          if (context.mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => MyHomePage(
                  key: homePageKey,
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
  late List<dynamic> posts = []; // Tutti i post
  late List<dynamic> urgentPosts = []; // Solo post URGENTI per Home (max 5)
  late List<dynamic> translatedPosts = []; // Post tradotti
  String currentLanguage = 'it';
  bool isLoggedIn = false;
  int _selectedIndex = 0;
  Map<String, dynamic>? userData;
  bool isLoadingUserData = true;
  bool isLoadingPosts = true;
  bool _isRendering = false;
  final Set<int> _notifiedUrgentPostIds = {};
  DateTime? _watcherStartTime; // Timestamp di quando parte il watcher
  Timer? _notificationTimer;
  Timer? _loadingTimeoutTimer;
  Timer? _postsRefreshTimer;
  bool _isHandlingPendingNotification = false;

  // Cache locale
  DateTime? lastCacheUpdate;
  static const String CACHE_KEY_POSTS = 'cached_posts';
  static const String CACHE_KEY_TIMESTAMP = 'cache_timestamp';
  static const String CACHE_KEY_NOTIFIED = 'notified_urgent_posts';

  List<dynamic> wpMenuItems = [];
  bool isLoadingMenu = true;

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  void startUrgentNotificationWatcher(
      BuildContext context, List<dynamic> initialPosts) {
    // Cancella il timer precedente per evitare duplicati
    if (_notificationTimer != null && _notificationTimer!.isActive) {
      debugPrint('⚠️ Cancello timer precedente ancora attivo');
      _notificationTimer?.cancel();
    }

    // Salva il timestamp di avvio - ora serve solo come backup
    _watcherStartTime = DateTime.now();
    debugPrint('🔔 BACKUP WATCHER: Avvio come backup con ${posts.length} post');
    debugPrint(
        '📢 Popup primari ora vengono mostrati durante il download dei post');

    // RIDOTTO: Controlla ogni 30 secondi solo come backup
    debugPrint('⏰ Creo timer periodic BACKUP (ogni 30 secondi)...');
    _notificationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!mounted) {
        debugPrint('❌ Widget non mounted, cancello timer backup');
        timer.cancel();
        return;
      }
      debugPrint('🔔 BACKUP: Controllo post urgenti come backup...');
      _checkForUrgentPosts();
    });

    debugPrint('✅ Timer backup creato con successo');
  }

  void _checkForUrgentPosts() {
    debugPrint(
        '🔔 BACKUP: Controllo post urgenti... (posts totali: ${posts.length})');
    debugPrint('🔔 BACKUP: Post già notificati: $_notifiedUrgentPostIds');

    // USA SEMPRE I POST AGGIORNATI DALLO STATO (posts variabile di stato)
    // NON i post passati come parametro che potrebbero essere vecchi
    final currentPosts = posts; // Usa i post dallo stato attuale

    // Filtra SOLO i post urgenti NON ancora notificati
    final urgentPosts = currentPosts.where((post) {
      final isUrgente = _isUrgent(post);
      final id = post['id'];

      // PRIMA verifica se già notificato - STOP se sì
      if (_notifiedUrgentPostIds.contains(id)) {
        debugPrint('🔔 BACKUP: SKIP post ID=$id - già notificato');
        return false;
      }

      // Verifica se è urgente
      if (!isUrgente) {
        return false;
      }

      // BACKUP: Il watcher ora serve solo come backup
      // I popup primari vengono mostrati durante il download in _processPosts()
      if (_watcherStartTime != null) {
        try {
          final dateString = post['date_gmt'] ?? post['date'];
          if (dateString != null) {
            final postDate = DateTime.parse(dateString);
            final isNewPost = postDate.isAfter(_watcherStartTime!);

            if (isNewPost) {
              final dynamic titleData = post['title'];
              final String title = titleData != null && titleData is Map
                  ? (titleData['rendered'] ?? 'Post #$id')
                  : 'Post #$id';

              debugPrint(
                  '🔔 BACKUP: POST URGENTE NUOVO RILEVATO: ID=$id - "$title"');
              debugPrint(
                  '   📅 Pubblicato: $postDate (${DateTime.now().difference(postDate).inSeconds}s fa)');
              debugPrint('   🚀 Watcher backup avviato: $_watcherStartTime');
              return true;
            } else {
              // Post pubblicato prima dell'avvio del watcher - non mostrare popup
              return false;
            }
          }
        } catch (e) {
          debugPrint('⚠️ Errore parsing data per post ID=$id: $e');
        }
      }

      return false;
    }).toList();

    if (urgentPosts.isNotEmpty) {
      debugPrint(
          '🔔 BACKUP WATCHER: TROVATI ${urgentPosts.length} POST URGENTI DA BACKUP! 🔔');

      // Ordina i post urgenti per data (dal più recente)
      urgentPosts.sort((a, b) {
        try {
          final dateA = DateTime.parse(a['date_gmt'] ?? a['date']);
          final dateB = DateTime.parse(b['date_gmt'] ?? b['date']);
          return dateB
              .compareTo(dateA); // Ordine decrescente (più recente prima)
        } catch (e) {
          return 0;
        }
      });

      // Prendi solo l'ultimo (più recente) post urgente
      final post = urgentPosts.first;
      debugPrint(
          '🔔 BACKUP: Mostro popup per l\'ultimo post urgente (più recente) perso dal download primario...');
      final id = post['id'];

      // DOPPIO CONTROLLO: Se è già notificato, STOP
      if (_notifiedUrgentPostIds.contains(id)) {
        debugPrint('🔔 BACKUP: ABORT - Post ID=$id trovato ma già notificato!');
        return;
      }

      // Aggiungi SUBITO alla lista notificati per evitare duplicati
      _notifiedUrgentPostIds.add(id);
      debugPrint(
          '🔔 BACKUP: Aggiunto ID=$id alla lista notificati: $_notifiedUrgentPostIds');

      // Salva la lista aggiornata in cache persistente
      _saveNotifiedPostsToCache();

      // Estrai il titolo del post
      final dynamic titleData = post['title'];
      final String title = titleData != null && titleData is Map
          ? (titleData['rendered'] ?? 'Comunicazione urgente')
          : 'Comunicazione urgente';
      // Rimuovi i tag HTML dal titolo
      final cleanTitle = title.replaceAll(RegExp(r'<[^>]*>'), '');
      final notificationBody = _buildNotificationBody(post);

      final currentContext = navigatorKey.currentContext;
      debugPrint('🔍🔍🔍 DEBUG POPUP DETTAGLIATO 🔍🔍🔍');
      debugPrint(
          '📍 navigatorKey.currentContext != null: ${currentContext != null}');
      debugPrint('📍 currentContext?.mounted: ${currentContext?.mounted}');
      debugPrint('📍 this.mounted: $mounted');
      debugPrint('📍 Post ID da mostrare: $id');
      debugPrint('📍 Titolo da mostrare: "$cleanTitle"');
      debugPrint('📍 _notifiedUrgentPostIds: $_notifiedUrgentPostIds');

      if (currentContext != null && currentContext.mounted) {
        debugPrint(
            '✅ TUTTE LE CONDIZIONI OK - MOSTRO POPUP ROSSO URGENTE ID=$id...');

        unawaited(showLocalNotification(
          id: id,
          title: cleanTitle,
          body: notificationBody,
          payload: id.toString(),
        ));

        // Mostra SUBITO il popup rosso
        debugPrint('⏰ Chiamo Future.microtask per mostrare popup...');
        Future.microtask(() {
          debugPrint('🎯 DENTRO Future.microtask - mounted=$mounted');
          if (!mounted) {
            debugPrint('❌ Widget non mounted dentro microtask');
            return;
          }

          final ctx = navigatorKey.currentContext;
          debugPrint(
              '🎯 navigatorKey.currentContext dentro microtask: ${ctx != null}');
          debugPrint('🎯 ctx?.mounted dentro microtask: ${ctx?.mounted}');

          if (ctx != null && ctx.mounted) {
            try {
              debugPrint(
                  '🚀🚀🚀 CHIAMANDO _showUrgentNotificationDialog per ID=$id 🚀🚀🚀');
              _showUrgentNotificationDialog(ctx, cleanTitle, id);
              debugPrint('✅✅✅ POPUP ROSSO CHIAMATO CON SUCCESSO! ✅✅✅');
            } catch (e) {
              debugPrint('❌❌❌ ERRORE CRITICO nel mostrare il popup: $e');
              debugPrint('❌ Stack trace: ${e.toString()}');
            }
          } else {
            debugPrint(
                '❌❌❌ Context non valido dentro microtask - ctx=$ctx, mounted=${ctx?.mounted}');
          }
        });

        debugPrint('⏰ Future.microtask schedulato con successo');

        debugPrint(
            '🔔 BACKUP: Popup urgente backup mostrato: ID=$id, Titolo="$cleanTitle"');
        debugPrint('   📍 Popup backup mostrato ovunque nell\'app ci si trovi');
      } else {
        debugPrint(
            '⚠️ Context non valido per popup backup ID=$id - currentContext=$currentContext, mounted=${currentContext?.mounted}');
        debugPrint(
            '🔔 BACKUP: Context non valido ma post rimane notificato per evitare loop');
        // NON rimuovere da notificati - altrimenti causa loop infiniti!
      }

      // Se ci sono altri post urgenti, saranno mostrati nei prossimi cicli backup
      if (urgentPosts.length > 1) {
        debugPrint(
            '⏳ Altri ${urgentPosts.length - 1} post urgenti backup in coda, saranno mostrati nei prossimi cicli (ogni 30 secondi)');
      }
    } else {
      debugPrint('🔔 BACKUP: Nessun post urgente nuovo da mostrare nel backup');
    }
  }

  void _showUrgentNotificationDialog(
      BuildContext context, String title, int postId) {
    debugPrint('🎬🎬🎬 INIZIO _showUrgentNotificationDialog 🎬🎬🎬');
    debugPrint('🎬 Context ricevuto: $context');
    debugPrint('🎬 Context.mounted: ${context.mounted}');
    debugPrint('🎬 Titolo: "$title"');
    debugPrint('🎬 Post ID: $postId');
    debugPrint('🎬 Posts disponibili: ${posts.length}');

    // Trova il post completo per ottenere il contenuto
    Map<String, dynamic>? currentPost;
    for (final post in posts) {
      if (post['id'] == postId) {
        currentPost = post;
        break;
      }
    }

    debugPrint('🎬 Post trovato per ID $postId: ${currentPost != null}');
    if (currentPost != null) {
      final content = currentPost['content']?['rendered'] ?? '';
      final hasVideoContent = content.toLowerCase().contains('iframe') ||
          content.toLowerCase().contains('<video') ||
          content.toLowerCase().contains('youtube') ||
          content.toLowerCase().contains('embed');
      debugPrint('🎬 Post ha contenuto video: $hasVideoContent');
    }

    try {
      debugPrint('🎬 Chiamo showDialog...');
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Text(
                  '🚨',
                  style: TextStyle(fontSize: 24),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Comunicazione Urgente',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE74C3C),
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  if (currentPost != null) ...[
                    const SizedBox(height: 16),
                    _buildUrgentContentWidget(currentPost),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text(
                  'Chiudi',
                  style: TextStyle(
                    color: AppColors.secondaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  // Naviga al dettaglio del post nell'app
                  if (currentPost != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PostDetailScreen(
                          post: currentPost!,
                          userName: widget.userName,
                          userEmail: widget.userEmail,
                        ),
                      ),
                    );
                  } else {
                    // Fallback: vai alla schermata Home
                    setState(() {
                      _selectedIndex = 0;
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE74C3C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Visualizza completo',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        },
      );
      debugPrint(
          '✅✅✅ showDialog() completato con successo! Dialog dovrebbe essere visibile ora! ✅✅✅');
    } catch (e) {
      debugPrint('❌❌❌ ERRORE CRITICO in showDialog(): $e');
      debugPrint('❌ Stack trace completo: $e');
      rethrow;
    }
  }

  Widget _buildUrgentContentWidget(Map<String, dynamic> post) {
    final content = post['content']?['rendered'] ?? '';
    final excerpt = post['excerpt']?['rendered'] ?? '';

    // Controlla se il contenuto contiene video/iframe
    final hasVideo = content.toLowerCase().contains('iframe') ||
        content.toLowerCase().contains('<video') ||
        content.toLowerCase().contains('youtube') ||
        content.toLowerCase().contains('embed');

    if (hasVideo) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE74C3C).withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.play_circle_outline,
                    color: Color(0xFFE74C3C), size: 20),
                SizedBox(width: 8),
                Text(
                  'Contenuto Video Rilevato',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE74C3C),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Questo post contiene contenuti video. Tocca "Visualizza Completo" per vedere i video nel browser.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
            if (excerpt.isNotEmpty && excerpt != content) ...[
              const SizedBox(height: 12),
              Text(
                _removeHtmlTags(excerpt),
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF2C3E50),
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      );
    } else {
      // Nessun video, mostra il contenuto normale
      final displayText = excerpt.isNotEmpty ? excerpt : content;
      return Container(
        constraints: const BoxConstraints(maxHeight: 200),
        child: SingleChildScrollView(
          child: Text(
            _removeHtmlTags(displayText),
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF2C3E50),
            ),
          ),
        ),
      );
    }
  }

  void _testUrgentPopup() {
    debugPrint('🧪🧪🧪 TEST POPUP URGENTE MANUALE 🧪🧪🧪');

    // Trova il primo post urgente
    final urgentPost = posts.firstWhere(
      (post) => _isUrgent(post),
      orElse: () => null,
    );

    if (urgentPost != null) {
      final id = urgentPost['id'];
      final dynamic titleData = urgentPost['title'];
      final String title = titleData != null && titleData is Map
          ? (titleData['rendered'] ?? 'Test Comunicazione Urgente')
          : 'Test Comunicazione Urgente';
      final cleanTitle = title.replaceAll(RegExp(r'<[^>]*>'), '');
      final notificationBody = _buildNotificationBody(urgentPost);

      debugPrint(
          '🧪 Trovato post urgente per test: ID=$id, Titolo="$cleanTitle"');
      debugPrint(
          '🧪 Post già notificato? ${_notifiedUrgentPostIds.contains(id)}');

      // Se già notificato, informa e chiedi conferma per ripetere
      if (_notifiedUrgentPostIds.contains(id)) {
        debugPrint(
            '⚠️ Post ID=$id già notificato. Lo mostro lo stesso per test...');
      }

      // Aggiungi alla lista notificati per evitare duplicati futuri
      _notifiedUrgentPostIds.add(id);
      _saveNotifiedPostsToCache();
      debugPrint(
          '🧪 Aggiunto ID=$id alla lista notificati: $_notifiedUrgentPostIds');

      final currentContext = navigatorKey.currentContext;
      debugPrint('🧪 currentContext: $currentContext');
      debugPrint('🧪 currentContext?.mounted: ${currentContext?.mounted}');
      debugPrint('🧪 this.mounted: $mounted');

      if (currentContext != null && currentContext.mounted) {
        debugPrint('🧪 Mostro popup di test...');
        try {
          unawaited(showLocalNotification(
            id: id,
            title: cleanTitle,
            body: notificationBody,
            payload: id.toString(),
          ));
          _showUrgentNotificationDialog(currentContext, cleanTitle, id);
          debugPrint('✅ POPUP DI TEST MOSTRATO CON SUCCESSO!');
        } catch (e) {
          debugPrint('❌ Errore nel test popup: $e');
        }
      } else {
        debugPrint('❌ Context non valido per test popup');

        // Prova con il context del widget corrente
        try {
          unawaited(showLocalNotification(
            id: id,
            title: cleanTitle,
            body: notificationBody,
            payload: id.toString(),
          ));
          _showUrgentNotificationDialog(context, cleanTitle, id);
          debugPrint('✅ POPUP DI TEST MOSTRATO CON CONTEXT WIDGET!');
        } catch (e) {
          debugPrint('❌ Errore anche con context widget: $e');
        }
      }
    } else {
      debugPrint('❌ Nessun post urgente trovato per il test');

      // Crea un popup di test con dati fittizi
      final currentContext = navigatorKey.currentContext;
      if (currentContext != null && currentContext.mounted) {
        debugPrint('🧪 Mostro popup di test con dati fittizi...');
        try {
          _showUrgentNotificationDialog(
              currentContext, 'Test Comunicazione Urgente', 99999);
          debugPrint('✅ POPUP DI TEST FITTIZIO MOSTRATO CON SUCCESSO!');
        } catch (e) {
          debugPrint('❌ Errore nel test popup fittizio: $e');
        }
      } else {
        debugPrint('❌ Impossibile mostrare popup di test - context non valido');
      }
    }
  }

  Future<void> fetchUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('jwtToken');

    final originalUsername = prefs.getString('originalUsername');
    final originalEmail = prefs.getString('originalEmail');

    if (savedToken != null && savedToken.isNotEmpty) {
      appSettings.setToken(savedToken);
      isLoggedIn = true;
    }

    Map<String, dynamic>? apiUserData;

    if (savedToken != null && savedToken.isNotEmpty) {
      try {
        final response = await http.get(
          Uri.parse('${appSettings.urlApi}users/me'),
          headers: {
            'Cookie': savedToken,
            'User-Agent': AppSettings.userAgent,
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          apiUserData = json.decode(response.body) as Map<String, dynamic>;
          debugPrint('✅ Dati utente recuperati da /users/me');
        } else {
          debugPrint(
              '⚠️ Impossibile recuperare dati utente (status: ${response.statusCode})');
        }
      } catch (e) {
        debugPrint('❌ Errore recupero dati utente da API: $e');
      }
    }

    final displayName = _computeDisplayName(
      apiDisplayName: _asString(apiUserData?['name']),
      firstName: _asString(apiUserData?['first_name']),
      lastName: _asString(apiUserData?['last_name']),
      username: originalUsername,
      email: originalEmail,
    );

    final resolvedEmail = _resolveEmail(
      apiEmail: _asString(apiUserData?['email']),
      storedEmail: originalEmail,
      username: originalUsername,
    );

    final resolvedId = _resolveUserId(apiUserData?['id']);

    if (!mounted) return;

    setState(() {
      userData = {
        'name': displayName,
        'email': resolvedEmail,
        'id': resolvedId,
      };
      isLoadingUserData = false;
    });
  }

  String _computeDisplayName({
    String? apiDisplayName,
    String? firstName,
    String? lastName,
    String? username,
    String? email,
  }) {
    final candidates = <String?>[
      _cleanAndCapitalizeName(apiDisplayName),
      _combineNameParts(firstName, lastName),
      _formatIdentifierName(username),
      _formatIdentifierName(email),
    ];

    for (final candidate in candidates) {
      if (candidate != null && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return 'Utente';
  }

  String? _combineNameParts(String? firstName, String? lastName) {
    final cleanedFirst = _cleanAndCapitalizeName(firstName);
    final cleanedLast = _cleanAndCapitalizeName(lastName);
    final parts = <String>[
      if (cleanedFirst != null && cleanedFirst.isNotEmpty) cleanedFirst,
      if (cleanedLast != null && cleanedLast.isNotEmpty) cleanedLast,
    ];
    if (parts.isEmpty) return null;
    return parts.join(' ');
  }

  String? _cleanAndCapitalizeName(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final normalizedWhitespace = trimmed.replaceAll(RegExp(r'\s+'), ' ');
    final segments = normalizedWhitespace.split(' ');
    return segments.map(_capitalizeWord).join(' ');
  }

  String? _formatIdentifierName(String? identifier) {
    if (identifier == null) return null;
    final trimmed = identifier.trim();
    if (trimmed.isEmpty) return null;
    final base = trimmed.contains('@') ? trimmed.split('@').first : trimmed;
    final sanitized =
        base.replaceAll(RegExp(r'[^A-Za-z\u00C0-\u017F\s._-]'), ' ');
    final segments = sanitized
        .split(RegExp(r'[._\-\s]+'))
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.isEmpty) {
      return _capitalizeWord(base);
    }
    return segments.map(_capitalizeWord).join(' ');
  }

  String _capitalizeWord(String value) {
    if (value.isEmpty) return value;
    final lower = value.toLowerCase();
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }

  String _resolveEmail({
    String? apiEmail,
    String? storedEmail,
    String? username,
  }) {
    final candidates = <String?>[
      apiEmail?.trim(),
      storedEmail?.trim(),
      username != null && username.contains('@') ? username.trim() : null,
    ];

    for (final candidate in candidates) {
      if (candidate != null && candidate.isNotEmpty) {
        return candidate;
      }
    }
    return 'user@example.com';
  }

  int _resolveUserId(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? 1;
    }
    return 1;
  }

  String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map && value['rendered'] is String) {
      return value['rendered'] as String;
    }
    return value.toString();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    currentLanguage = languageProvider.locale.languageCode;
    languageProvider.addListener(_onLanguageChanged);

    // Inizializza translatedPosts con i post originali se la lingua è italiana
    if (currentLanguage == 'it') {
      translatedPosts = posts;
    }

    _loadNotifiedPostsFromCache();
    _initializeWithTokenReload();
    _startPeriodicPostsRefresh();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _schedulePendingNotificationNavigation();
    });
  }

  Future<void> openPostFromNotification(int postId) async {
    _pendingNotificationPostId = postId;
    _schedulePendingNotificationNavigation();
  }

  void _schedulePendingNotificationNavigation() {
    if (!mounted || _pendingNotificationPostId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_openPendingNotificationPostIfAvailable());
    });
  }

  Future<void> _openPendingNotificationPostIfAvailable() async {
    if (_isHandlingPendingNotification) return;

    final int? pendingId = _pendingNotificationPostId;
    if (pendingId == null) return;

    Map<String, dynamic>? targetPost = _findPostById(posts, pendingId) ??
        _findPostById(translatedPosts, pendingId);

    targetPost ??= await _fetchPostById(pendingId);

    if (targetPost == null) {
      debugPrint(
          '⚠️ Post ID=$pendingId non trovato per apertura da notifica (verrà ritentato)');
      return;
    }

    _isHandlingPendingNotification = true;
    _pendingNotificationPostId = null;

    final Map<String, dynamic> postToOpen =
        Map<String, dynamic>.from(targetPost);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _isHandlingPendingNotification = false;
        return;
      }
      try {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(
              post: postToOpen,
              userName: widget.userName,
              userEmail: widget.userEmail,
            ),
          ),
        ).then((_) {
          _isHandlingPendingNotification = false;
        });
      } catch (e) {
        _isHandlingPendingNotification = false;
        debugPrint('❌ Errore apertura post da notifica: $e');
      }
    });
  }

  Map<String, dynamic>? _findPostById(List<dynamic> source, int postId) {
    for (final item in source) {
      if (item is Map<String, dynamic> && item['id'] == postId) {
        return item;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> _fetchPostById(int postId) async {
    try {
      final uri = Uri.parse(
          '${appSettings.urlPosts}/$postId?_embed=wp:term,wp:featuredmedia');
      final headers = <String, String>{
        'User-Agent': AppSettings.userAgent,
        if (appSettings.jwtToken != null && appSettings.jwtToken!.isNotEmpty)
          'Cookie': appSettings.jwtToken!,
      };

      final response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
          debugPrint('✅ Post ID=$postId scaricato da API per notifica');
          return data;
        }
      } else {
        debugPrint(
            '⚠️ Errore ${response.statusCode} scaricando post ID=$postId per notifica');
      }
    } catch (e) {
      debugPrint('❌ Errore fetch post ID=$postId per notifica: $e');
    }
    return null;
  }

  Future<void> _onLanguageChanged() async {
    final newLanguage = languageProvider.locale.languageCode;
    debugPrint('🏠 Home: Cambio lingua da $currentLanguage a $newLanguage');

    if (newLanguage != currentLanguage && posts.isNotEmpty) {
      currentLanguage = newLanguage;

      if (newLanguage == 'it') {
        // Se la nuova lingua è italiana, usa i post originali senza traduzione
        debugPrint(
            '🏠 Home: Lingua cambiata a italiano - nessuna traduzione necessaria');
        if (mounted) {
          setState(() {
            translatedPosts = posts;
          });
        }
      } else {
        debugPrint(
            '🏠 Home: Traduco ${posts.length} post in $newLanguage (2 alla volta)');

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

          debugPrint(
              '📝 Home: Tradotti ${translated.length}/${posts.length} post');
        }

        debugPrint(
            '✅ Home: Traduzione completata! ${translated.length} post tradotti');

        if (mounted) {
          setState(() {
            translatedPosts = translated;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    languageProvider.removeListener(_onLanguageChanged);
    WidgetsBinding.instance.removeObserver(this);
    _notificationTimer?.cancel();
    _loadingTimeoutTimer?.cancel();
    _postsRefreshTimer?.cancel();
    _isRendering = false;
    super.dispose();
  }

  Future<void> _initializeWithTokenReload() async {
    debugPrint('=== INIZIALIZZAZIONE CON RICARICA TOKEN ===');

    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final username = prefs.getString('username');
    final password = prefs.getString('password');

    debugPrint('🔐 isLoggedIn: $isLoggedIn, username: $username');

    // Se l'utente è loggato, assicurati che abbia un token valido
    if (isLoggedIn && username != null && password != null) {
      await reloadTokenFromStorage();

      debugPrint(
          'Token dopo ricarica: ${appSettings.jwtToken != null ? "Presente" : "Mancante"}');
      if (appSettings.jwtToken != null) {
        debugPrint(
            'Token contiene wordpress_logged_in: ${appSettings.jwtToken!.contains('wordpress_logged_in')}');
        debugPrint('Token length: ${appSettings.jwtToken!.length}');
      }

      // Se il token è mancante o non valido, rigeneralo
      if (appSettings.jwtToken == null ||
          !appSettings.jwtToken!.contains('wordpress_logged_in')) {
        debugPrint(
            '⚠️ Token mancante o non valido, rigenerazione automatica...');
        await regenerateToken();
        await reloadTokenFromStorage();
        debugPrint(
            '✅ Token dopo rigenerazione: ${appSettings.jwtToken != null ? "Presente" : "Mancante"}');
      }
    } else {
      debugPrint('❌ Utente non loggato o credenziali mancanti');
    }

    await _initializeData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      debugPrint('App riattivata dalla pausa, verifica sessione...');
      _checkSessionAndReauth();
      _schedulePendingNotificationNavigation();
    }
  }

  Future<bool> _isDeviceOnline() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) return false;
      return true;
    } catch (e) {
      debugPrint('Errore controllo connettività: $e');
      return false;
    }
  }

  void _startPeriodicPostsRefresh() {
    _postsRefreshTimer?.cancel();
    // Controlla ogni 3 secondi per rilevare rapidamente nuovi post urgenti
    _postsRefreshTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final online = await _isDeviceOnline();
      if (!online) {
        debugPrint('⏱️ Skip refresh post: dispositivo offline');
        return;
      }
      debugPrint(
          '⏱️ Refresh periodico post (ogni 3 secondi per rilevare urgenti)');
      try {
        await fetchPosts();
      } catch (e) {
        debugPrint('Errore nel refresh periodico dei post: $e');
      }
    });
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
        Uri.parse('${appSettings.urlLogin}'),
        headers: {
          'User-Agent': AppSettings.userAgent,
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
        Uri.parse('${appSettings.urlLogin}'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': AppSettings.userAgent,
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Referer': '${appSettings.urlLogin}',
        },
        body: nonce.isNotEmpty
            ? 'log=$username&pwd=$password&wp-submit=Log+In&redirect_to=${appSettings.urlAdmin}&testcookie=1&_wpnonce=$nonce'
            : 'log=$username&pwd=$password&wp-submit=Log+In&redirect_to=${appSettings.urlAdmin}&testcookie=1',
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
          appSettings.setToken(cookies);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwtToken', appSettings.jwtToken!);
          await prefs.setString('username', username);
          await prefs.setString('password', password);
          await prefs.setBool('isLoggedIn', true);

          // Salva i dati dell'utente originale per la visualizzazione nell'app
          await prefs.setString('originalUsername', username);
          await prefs.setString('originalEmail', username);

          debugPrint('Riautenticazione automatica dalla home riuscita');
          debugPrint('Dati utente originale preservati: $username');
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
      // Esegui le operazioni in sequenza per evitare che un errore blocchi tutto
      await _initializeWithTimeout(() => fetchUserData(), 'fetchUserData', 15);

      // Ora che i dati utente sono caricati, mostra l'UI
      if (mounted) {
        setState(() {
          isLoadingUserData = false;
        });
      }

      // Carica i post e il menu in background
      _initializeWithTimeout(() => fetchPosts(), 'fetchPosts', 60).then((_) {
        // Fallback: assicurati che isLoadingPosts sia false dopo il caricamento
        if (mounted && isLoadingPosts) {
          debugPrint('Fallback: imposto isLoadingPosts = false');
          setState(() {
            isLoadingPosts = false;
          });
        }
        _loadingTimeoutTimer?.cancel();
      }).catchError((e) {
        debugPrint('Errore caricamento post: $e');
        if (mounted) {
          setState(() {
            isLoadingPosts = false;
          });
        }
        _loadingTimeoutTimer?.cancel();
      });

      // Timer di sicurezza: se dopo 30 secondi i post non sono ancora caricati, forza il caricamento
      _loadingTimeoutTimer = Timer(const Duration(seconds: 30), () {
        if (mounted && isLoadingPosts) {
          debugPrint('Timeout sicurezza: forzo isLoadingPosts = false');
          setState(() {
            isLoadingPosts = false;
          });
        }
      });

      _initializeWithTimeout(() => fetchWpMenu(), 'fetchWpMenu', 30)
          .catchError((e) {
        debugPrint('Errore caricamento menu: $e');
      });

      if (mounted) {
        // Avvia il watcher DOPO che i post sono stati caricati
        // Il watcher verrà riavviato automaticamente ad ogni aggiornamento dei post
        startTokenRefreshTimer();
      }

      debugPrint('Inizializzazione completata');
    } catch (e) {
      debugPrint('Errore durante inizializzazione: $e');
      if (mounted) {
        setState(() {
          isLoadingUserData = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore caricamento dati: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Riprova',
              onPressed: () {
                setState(() {
                  isLoadingUserData = true;
                });
                _initializeData();
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _initializeWithTimeout(Future<void> Function() operation,
      String operationName, int timeoutSeconds) async {
    try {
      debugPrint('=== INIZIO $operationName (timeout: ${timeoutSeconds}s) ===');
      await operation().timeout(
        Duration(seconds: timeoutSeconds),
        onTimeout: () {
          debugPrint('=== TIMEOUT $operationName dopo ${timeoutSeconds}s ===');
          throw TimeoutException(
              '$operationName timeout dopo ${timeoutSeconds}s',
              Duration(seconds: timeoutSeconds));
        },
      );
      debugPrint('=== COMPLETATO $operationName ===');
    } catch (e) {
      print("Error: ${e.toString()}");
    }
  }

  Future<void> _testWordPressAPI() async {
    try {
      debugPrint('Test API WordPress 6.8.2...');

      // Test endpoint base
      final response = await http.get(
        Uri.parse('${appSettings.urlApi}'),
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
        Uri.parse('${appSettings.urlApi}posts?per_page=5'),
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
      if (appSettings.jwtToken != null &&
          !appSettings.jwtToken!.contains('wordpress_logged_in')) {
        debugPrint('Cookie di sessione scaduto, rigenerazione automatica');
        await regenerateToken();
      }
    });
  }

  // ------- fetchWpMenu / fetchPosts / helper: invariati dal tuo codice -------

  Future<bool> _autoLoginWithFallbackCredentials() async {
    try {
      debugPrint('=== TENTATIVO LOGIN AUTOMATICO IN BACKGROUND ===');
      const fallbackUsername = 'riccardo@marconisoftware.com';
      const fallbackPassword = '4817Riccardo*';

      // Salva i dati dell'utente originale prima del login automatico
      final prefs = await SharedPreferences.getInstance();

      // Se non esistono ancora dati originali, salva quelli attuali
      String? originalUsername = prefs.getString('originalUsername');
      String? originalEmail = prefs.getString('originalEmail');

      if (originalUsername == null || originalEmail == null) {
        // Salva l'utente corrente come originale
        final currentUsername = prefs.getString('username');
        if (currentUsername != null) {
          await prefs.setString('originalUsername', currentUsername);
          await prefs.setString('originalEmail', currentUsername);
          originalUsername = currentUsername;
          originalEmail = currentUsername;
          debugPrint(
              '✅ Salvati dati utente corrente come originali: $currentUsername');
        }
      }

      debugPrint(
          'Utente originale che verrà mostrato nella UI: $originalUsername ($originalEmail)');

      // Step 1: Ottieni il nonce necessario per il login
      final nonceResponse = await http.get(
        Uri.parse('${appSettings.urlLogin}'),
        headers: {
          'User-Agent': AppSettings.userAgent,
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      );

      debugPrint(
          'Auto-login nonce response status: ${nonceResponse.statusCode}');

      // Estrai il nonce dalla risposta HTML
      String nonce = '';
      final nonceMatch = RegExp(r'name="_wpnonce" value="([^"]+)"')
          .firstMatch(nonceResponse.body);
      if (nonceMatch != null) {
        nonce = nonceMatch.group(1)!;
        debugPrint('Auto-login nonce estratto: $nonce');
      }

      // Step 2: Effettua login con il nonce
      final loginResponse = await http.post(
        Uri.parse('${appSettings.urlLogin}'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': AppSettings.userAgent,
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Referer': '${appSettings.urlLogin}',
        },
        body: nonce.isNotEmpty
            ? 'log=$fallbackUsername&pwd=$fallbackPassword&wp-submit=Log+In&redirect_to=${appSettings.urlAdmin}&testcookie=1&_wpnonce=$nonce'
            : 'log=$fallbackUsername&pwd=$fallbackPassword&wp-submit=Log+In&redirect_to=${appSettings.urlAdmin}&testcookie=1',
      );

      debugPrint('Auto-login response status: ${loginResponse.statusCode}');

      // Step 3: Verifica se il login è riuscito controllando i cookie
      if (loginResponse.headers['set-cookie'] != null) {
        final cookies = loginResponse.headers['set-cookie']!;
        debugPrint('Auto-login cookies ricevuti: $cookies');

        // Verifica il login
        if (loginResponse.statusCode == 302 ||
            loginResponse.headers['location']?.contains('wp-admin') == true ||
            loginResponse.body.contains('wp-admin') ||
            cookies.contains('wordpress_logged_in')) {
          // Login riuscito - salva i cookie
          appSettings.setToken(cookies);

          // Salva solo le credenziali per l'autenticazione, NON sovrascrivere i dati originali dell'utente
          await prefs.setString('jwtToken', appSettings.jwtToken!);
          await prefs.setString('username', fallbackUsername);
          await prefs.setString('password', fallbackPassword);
          await prefs.setBool('isLoggedIn', true);

          // IMPORTANTE: Mantieni sempre i dati dell'utente originale per la visualizzazione
          if (originalUsername != null && originalEmail != null) {
            await prefs.setString('originalUsername', originalUsername);
            await prefs.setString('originalEmail', originalEmail);
            debugPrint(
                '✅ Dati utente originale preservati per la UI: $originalUsername');
            debugPrint(
                '   (Credenziali fallback usate solo per scaricare i post)');

            // Aggiorna userData per mostrare l'utente originale nella UI
            if (mounted) {
              setState(() {
                userData = {
                  'name': originalUsername,
                  'email': originalEmail,
                  'id': 1,
                };
              });
              debugPrint('✅ UI aggiornata con dati utente originale');
            }
          }

          debugPrint('✅ Auto-login completato con successo, cookies salvati');
          return true;
        } else {
          debugPrint('❌ Auto-login fallito - login non riuscito');
          return false;
        }
      } else {
        debugPrint('❌ Auto-login fallito - nessun cookie ricevuto');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Errore durante auto-login: $e');
      return false;
    }
  }

  Future<void> fetchWpMenu() async {
    try {
      final response = await http.get(
        Uri.parse('${appSettings.urlApi}menu-items'),
        headers: {
          'Authorization':
              createBasicAuth('condominio', AppSettings.appPassword),
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

  /// Carica post dalla cache locale
  Future<List<dynamic>> _loadPostsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(CACHE_KEY_POSTS);
      final timestamp = prefs.getInt(CACHE_KEY_TIMESTAMP);

      if (cachedJson != null && timestamp != null) {
        lastCacheUpdate = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final List<dynamic> cachedPosts = json.decode(cachedJson);

        // Conta urgenti vs normali
        int urgenti = cachedPosts.where((p) => _isUrgent(p)).length;
        int normali = cachedPosts.length - urgenti;
        debugPrint(
            '📦 Cache caricata: ${cachedPosts.length} post ($urgenti urgenti + $normali normali) - Ultimo aggiornamento: $lastCacheUpdate');
        return cachedPosts;
      }
    } catch (e) {
      debugPrint('❌ Errore caricamento cache: $e');
    }
    return [];
  }

  /// Salva post nella cache locale
  Future<void> _savePostsToCache(List<dynamic> postsToCache) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(postsToCache);
      await prefs.setString(CACHE_KEY_POSTS, jsonString);
      await prefs.setInt(
          CACHE_KEY_TIMESTAMP, DateTime.now().millisecondsSinceEpoch);
      lastCacheUpdate = DateTime.now();

      // Conta urgenti vs normali
      int urgenti = postsToCache.where((p) => _isUrgent(p)).length;
      int normali = postsToCache.length - urgenti;
      debugPrint(
          '💾 Cache salvata: ${postsToCache.length} post ($urgenti urgenti + $normali normali)');
    } catch (e) {
      debugPrint('❌ Errore salvataggio cache: $e');
    }
  }

  /// Cancella la cache dei post
  Future<void> _clearPostsCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(CACHE_KEY_POSTS);
      await prefs.remove(CACHE_KEY_TIMESTAMP);
      debugPrint(
          '🗑️ Cache cancellata - verrà scaricata nuovamente dal server');
    } catch (e) {
      debugPrint('❌ Errore cancellazione cache: $e');
    }
  }

  /// Carica la lista dei post urgenti già notificati dalla cache
  Future<void> _loadNotifiedPostsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notifiedList = prefs.getStringList(CACHE_KEY_NOTIFIED);

      if (notifiedList != null) {
        _notifiedUrgentPostIds.clear();
        _notifiedUrgentPostIds.addAll(notifiedList.map((id) => int.parse(id)));
        debugPrint(
            '📦 Caricati ${_notifiedUrgentPostIds.length} post urgenti già notificati: $_notifiedUrgentPostIds');
      } else {
        debugPrint('📦 Nessun post notificato salvato in cache');
      }
    } catch (e) {
      debugPrint('❌ Errore caricamento post notificati: $e');
      _notifiedUrgentPostIds.clear();
    }
  }

  /// Salva la lista dei post urgenti notificati nella cache
  Future<void> _saveNotifiedPostsToCache() async {
    try {
      // Limita la lista a massimo 50 post notificati per evitare accumulo eccessivo
      final limitedList = _notifiedUrgentPostIds.toList();
      if (limitedList.length > 50) {
        limitedList.removeRange(0, limitedList.length - 50);
        _notifiedUrgentPostIds.clear();
        _notifiedUrgentPostIds.addAll(limitedList);
        debugPrint(
            '🧹 Lista notificati limitata a ${_notifiedUrgentPostIds.length} elementi');
      }

      final prefs = await SharedPreferences.getInstance();
      final notifiedList =
          _notifiedUrgentPostIds.map((id) => id.toString()).toList();
      await prefs.setStringList(CACHE_KEY_NOTIFIED, notifiedList);
      debugPrint(
          '💾 Salvati ${_notifiedUrgentPostIds.length} post notificati in cache: $_notifiedUrgentPostIds');
    } catch (e) {
      debugPrint('❌ Errore salvataggio post notificati: $e');
    }
  }

  /// SOLO PER DEBUG: Reset della lista post notificati
  Future<void> _resetNotifiedPostsForDebug() async {
    debugPrint('🔄 RESET DEBUG: Cancello tutti i post notificati per test...');
    _notifiedUrgentPostIds.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(CACHE_KEY_NOTIFIED);
    debugPrint('✅ Lista post notificati resettata completamente');
  }

  /// Pulisce la lista dei post notificati rimuovendo quelli che non esistono più
  void _cleanNotifiedPostsList() {
    final currentPostIds = posts.map((p) => p['id']).toSet();
    final toRemove = _notifiedUrgentPostIds
        .where((id) => !currentPostIds.contains(id))
        .toList();

    if (toRemove.isNotEmpty) {
      _notifiedUrgentPostIds.removeAll(toRemove);
      debugPrint(
          '🧹 Rimossi ${toRemove.length} post notificati non più esistenti: $toRemove');
      debugPrint('🧹 Lista notificati pulita: $_notifiedUrgentPostIds');
      _saveNotifiedPostsToCache();
    }
  }

  /// Estrae solo i post URGENTI (ultimi 5)
  List<dynamic> _extractUrgentPosts(List<dynamic> allPosts) {
    final urgent = allPosts.where((post) => _isUrgent(post)).toList();

    // Ordina per data (più recenti prima)
    urgent.sort((a, b) {
      final dateA =
          DateTime.parse(a['date'] ?? DateTime.now().toIso8601String());
      final dateB =
          DateTime.parse(b['date'] ?? DateTime.now().toIso8601String());
      return dateB.compareTo(dateA); // Decrescente
    });

    // Prendi solo i primi 5
    final top5 = urgent.take(5).toList();
    debugPrint(
        '🚨 Post URGENTI trovati: ${urgent.length}, mostrati in Home: ${top5.length}');
    return top5;
  }

  /// Aggiorna la cache solo con nuovi post
  Future<void> _updateCacheWithNewPosts(List<dynamic> newPosts) async {
    if (newPosts.isEmpty) return;

    // Carica cache esistente
    final cachedPosts = await _loadPostsFromCache();

    // Crea mappa ID → Post per confronto veloce
    final cachedIds = cachedPosts.map((p) => p['id']).toSet();

    // Trova solo post veramente nuovi
    final reallyNewPosts =
        newPosts.where((p) => !cachedIds.contains(p['id'])).toList();

    if (reallyNewPosts.isNotEmpty) {
      debugPrint(
          '✨ Trovati ${reallyNewPosts.length} nuovi post da aggiungere alla cache');

      // Unisci: nuovi post + vecchi post
      final updatedCache = [...newPosts, ...cachedPosts];

      // Rimuovi duplicati (mantieni il più recente)
      final Map<int, dynamic> uniquePosts = {};
      for (var post in updatedCache) {
        uniquePosts[post['id']] = post;
      }

      // Salva cache aggiornata
      await _savePostsToCache(uniquePosts.values.toList());
    } else {
      debugPrint('📦 Nessun nuovo post, cache già aggiornata');
    }
  }

  Future<void> fetchPosts() async {
    try {
      debugPrint('=== INIZIO DOWNLOAD POST CON CACHE ===');

      // 🎯 STEP 1: Carica dalla cache locale (immediato)
      final cachedPosts = await _loadPostsFromCache();
      if (cachedPosts.isNotEmpty) {
        debugPrint('✅ Cache trovata: ${cachedPosts.length} post');
        setState(() {
          posts = cachedPosts;
          urgentPosts = _extractUrgentPosts(cachedPosts);
          translatedPosts = cachedPosts;
          isLoadingPosts = false;
        });

        // Avvia il watcher anche quando si carica dalla cache
        final currentContext = navigatorKey.currentContext;
        if (currentContext != null) {
          startUrgentNotificationWatcher(currentContext, cachedPosts);
          debugPrint('🔔 Watcher popup avviato dopo caricamento da cache');
        }
      } else {
        debugPrint('📭 Nessuna cache trovata, scarico dal server...');
      }

      // 🌐 STEP 2: Prova a scaricare nuovi post dal server (in background)
      debugPrint(
          'JWT Token disponibile: ${appSettings.jwtToken != null && appSettings.jwtToken!.isNotEmpty}');

      // Salva i post precedenti per confronto
      final previousPostIds = posts.map((p) => p['id']).toSet();
      final tempPosts = <dynamic>[];

      // Prima verifica che l'API REST sia accessibile
      await _testWordPressAPI();

      // Usa sempre l'autenticazione se disponibile
      if (appSettings.jwtToken != null && appSettings.jwtToken!.isNotEmpty) {
        debugPrint('Caricamento post con autenticazione...');
        await _tryFetchUserSpecificPosts();
        tempPosts.addAll(posts);
      } else {
        debugPrint('Caricamento post senza autenticazione...');
        await _tryFetchPostsWithoutAuth();
        tempPosts.addAll(posts);
      }

      // Se non ha funzionato, prova endpoint alternativi
      if (tempPosts.isEmpty) {
        debugPrint('Provo endpoint alternativi...');
        await _tryFetchPostsAlternative();
        tempPosts.addAll(posts);
      }

      // Se ancora non ci sono post, prova login automatico
      if (tempPosts.isEmpty && cachedPosts.isEmpty) {
        debugPrint('⚠️ Tentativo login automatico...');
        final loginSuccess = await _autoLoginWithFallbackCredentials();
        if (loginSuccess && appSettings.jwtToken != null) {
          await _tryFetchUserSpecificPosts();
          tempPosts.addAll(posts);
          if (tempPosts.isEmpty) {
            await _tryFetchPostsAlternative();
            tempPosts.addAll(posts);
          }
        }
      }

      // 🔄 STEP 3: Aggiorna cache solo se ci sono nuovi post
      if (tempPosts.isNotEmpty) {
        final newPostIds = tempPosts.map((p) => p['id']).toSet();
        final hasNewPosts =
            !newPostIds.every((id) => previousPostIds.contains(id));

        if (hasNewPosts || cachedPosts.isEmpty) {
          debugPrint('✨ Aggiornamento cache con nuovi post...');
          await _updateCacheWithNewPosts(tempPosts);

          // Ricarica dalla cache aggiornata
          final updatedCache = await _loadPostsFromCache();
          setState(() {
            posts = updatedCache;
            urgentPosts = _extractUrgentPosts(updatedCache);
          });

          // Riavvia il watcher con i nuovi post
          if (updatedCache.isNotEmpty) {
            final currentContext = navigatorKey.currentContext;
            if (currentContext != null) {
              startUrgentNotificationWatcher(currentContext, updatedCache);
              debugPrint('🔔 Watcher popup riavviato dopo aggiornamento cache');
            }
          }
        } else {
          debugPrint('📦 Nessun nuovo post, uso cache esistente');
        }
      } else if (cachedPosts.isNotEmpty) {
        debugPrint('⚠️ Server non risponde, uso cache offline');
      }

      debugPrint(
          '=== FINE DOWNLOAD POST: ${posts.length} totali, ${urgentPosts.length} urgenti per Home ===');

      // Traduci i post se la lingua non è italiano (2 alla volta)
      if (currentLanguage != 'it' && posts.isNotEmpty) {
        debugPrint(
            '🏠 Home: Traduco ${posts.length} post all\'avvio in $currentLanguage (2 alla volta)');
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

          debugPrint(
              '📝 Home: Tradotti ${translated.length}/${posts.length} post all\'avvio');
        }

        if (mounted) {
          setState(() {
            translatedPosts = translated;
          });
        }
        debugPrint(
            '✅ Home: ${translatedPosts.length} post tradotti all\'avvio');
      } else {
        // Se la lingua è italiana o non ci sono post, usa i post originali
        debugPrint(
            '🏠 Home: Lingua italiana ($currentLanguage) - nessuna traduzione necessaria');
        debugPrint(
            '🏠 Home: Prima setState - isLoadingPosts: $isLoadingPosts, posts: ${posts.length}');
        if (mounted) {
          setState(() {
            translatedPosts = posts;
            isLoadingPosts = false;
          });
          debugPrint(
              '🏠 Home: Dopo setState - isLoadingPosts: $isLoadingPosts');
        } else {
          debugPrint('🏠 Home: Widget non mounted, non aggiorno lo state');
        }
      }
    } catch (e) {
      debugPrint('Errore caricamento post: $e');
      await _fetchPostsAlternative();
    } finally {
      _schedulePendingNotificationNavigation();
    }
  }

  Future<void> _tryFetchPostsWithoutAuth() async {
    try {
      debugPrint('Tentativo 1: Caricamento post senza autenticazione');

      final response = await http.get(
        Uri.parse('${appSettings.urlApi}posts?per_page=20&status=publish'),
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
      debugPrint(
          '=== TENTATIVO CON BASIC AUTH (ADMIN per scaricare TUTTI i post) ===');

      // 🔥 USA CREDENZIALI ADMIN per scaricare TUTTI i post del condominio
      final basicAuth = createBasicAuth(
          AppSettings.adminUsername, AppSettings.adminAppPassword);
      debugPrint(
          'Basic Auth creata per ADMIN: $AppSettings.adminUsername (scarica TUTTI i post)');

      // 🔥 Lista di endpoint che scaricano TUTTI i post del condominio (non filtrati per author)
      final endpoints = [
        '${appSettings.urlApi}posts?per_page=100&status=publish,private&_embed=wp:term,wp:featuredmedia&orderby=date&order=desc',
        '${appSettings.urlApi}posts?per_page=100&status=publish&_embed=wp:term&orderby=date&order=desc',
        '${appSettings.urlApi}posts?per_page=100&_embed=wp:term&orderby=date&order=desc',
        '${appSettings.urlApi}posts?per_page=100&orderby=date&order=desc',
        '${appSettings.urlApi}posts?per_page=100',
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

      if (appSettings.jwtToken == null || appSettings.jwtToken!.isEmpty) {
        debugPrint('Nessun token disponibile per caricamento post categoria');
        return;
      }

      // Prima ottieni l'ID dell'utente corrente
      final userId = await _getCurrentUserId();

      final endpoints = [
        '${appSettings.urlApi}posts?author=$userId&categories=$categoryId&per_page=20&_embed=wp:term,wp:featuredmedia&orderby=date&order=desc',
        '${appSettings.urlApi}posts?categories=$categoryId&per_page=20&_embed=wp:term,wp:featuredmedia&orderby=date&order=desc',
        '${appSettings.urlApi}posts?author=$userId&categories=$categoryId&per_page=20&_embed=wp:term&orderby=date&order=desc',
        '${appSettings.urlApi}posts?categories=$categoryId&per_page=20&_embed=wp:term&orderby=date&order=desc',
      ];

      for (final endpoint in endpoints) {
        try {
          debugPrint('Provando endpoint categoria: $endpoint');

          final response = await http.get(
            Uri.parse(endpoint),
            headers: {
              'Cookie': appSettings.jwtToken!,
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
        Uri.parse('${appSettings.urlAdmin}admin-ajax.php'),
        headers: {
          'Cookie': appSettings.jwtToken!,
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': AppSettings.userAgent,
          'Referer': '${appSettings.urlAdmin}',
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
    // Endpoint SENZA filtro author per vedere TUTTI i post del condominio
    List<String> endpoints = [];

    // 🔥 SCARICA TUTTI I POST DEL CONDOMINIO (SENZA filtro author)
    endpoints.addAll([
      '${appSettings.urlApi}posts?per_page=100&status=publish,private&_embed=wp:term,wp:featuredmedia&orderby=date&order=desc',
      '${appSettings.urlApi}posts?per_page=100&status=publish&_embed=wp:term&orderby=date&order=desc',
      '${appSettings.urlApi}posts?per_page=100&_embed=wp:term&orderby=date&order=desc',
      '${appSettings.urlApi}posts?per_page=100&orderby=date&order=desc',
      '${appSettings.urlApi}posts?per_page=100',
    ]);

    for (final endpoint in endpoints) {
      try {
        debugPrint('Provando endpoint specifico utente: $endpoint');

        final response = await http.get(
          Uri.parse(endpoint),
          headers: {
            'Cookie': appSettings.jwtToken!,
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

      if (appSettings.jwtToken == null || appSettings.jwtToken!.isEmpty) {
        debugPrint('Nessun token disponibile per verifica autenticazione');
        return;
      }

      // Prova a verificare l'autenticazione con diversi endpoint
      final endpoints = [
        '${appSettings.urlApi}users/me',
        '${appSettings.urlAdmin}admin-ajax.php?action=heartbeat',
        '${appSettings.urlApi}',
      ];

      for (final endpoint in endpoints) {
        try {
          debugPrint('Test autenticazione con: $endpoint');

          final response = await http.get(
            Uri.parse(endpoint),
            headers: {
              'Cookie': appSettings.jwtToken!,
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

      if (appSettings.jwtToken == null || appSettings.jwtToken!.isEmpty) {
        debugPrint('Nessun token disponibile per recupero ID utente');
        return null;
      }

      // Endpoint per ottenere l'utente corrente
      final response = await http.get(
        Uri.parse('${appSettings.urlApi}users/me'),
        headers: {
          'Cookie': appSettings.jwtToken!,
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
        '${appSettings.urlApi}posts',
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

    // 🔥 STEP 1: Salva i post urgenti correnti per confronto
    final previousUrgentPostIds =
        posts.where((p) => _isUrgent(p)).map((p) => p['id']).toSet();
    debugPrint('🔍 Post urgenti PRIMA del download: $previousUrgentPostIds');

    // Log di tutti i post ricevuti CON INFO URGENZA
    int urgentiCount = 0;
    int normaliCount = 0;
    for (int i = 0; i < data.length; i++) {
      final post = data[i];
      final isUrg = _isUrgent(post);
      if (isUrg)
        urgentiCount++;
      else
        normaliCount++;

      debugPrint(
          'Post $i: "${post['title']['rendered']}" - Status: ${post['status']} - ${isUrg ? "⚠️ URGENTE" : "📰 normale"}');
    }
    debugPrint(
        '⚠️⚠️ DALL\'API: $urgentiCount urgenti + $normaliCount normali = ${data.length} TOTALI');

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

    // Log dettagliato dei post che verranno mostrati CON INFO URGENZA
    int urgentiFiltrati = 0;
    int normaliFiltrati = 0;
    for (int i = 0; i < filtered.length && i < 5; i++) {
      final post = filtered[i];
      final isUrg = _isUrgent(post);
      if (isUrg) {
        urgentiFiltrati++;
      } else {
        normaliFiltrati++;
      }
    }

    if (mounted) {
      setState(() {
        posts = filtered;
        isLoadingPosts = false;
      });
      debugPrint('=== POST AGGIORNATI NELLO STATE: ${posts.length} ===');

      // 🔥 STEP 2: Rileva i NUOVI post urgenti scaricati
      final newUrgentPostIds =
          filtered.where((p) => _isUrgent(p)).map((p) => p['id']).toSet();
      final reallyNewUrgentIds =
          newUrgentPostIds.difference(previousUrgentPostIds);

      debugPrint('🔍 Post urgenti DOPO il download: $newUrgentPostIds');
      debugPrint('🆕 Post urgenti VERAMENTE NUOVI: $reallyNewUrgentIds');

      // 🚨 STEP 3: Mostra popup IMMEDIATAMENTE per ogni nuovo post urgente (NON ancora notificato)
      if (reallyNewUrgentIds.isNotEmpty) {
        debugPrint(
            '🚨🚨🚨 TROVATI ${reallyNewUrgentIds.length} NUOVI POST URGENTI! 🚨🚨🚨');
        debugPrint('🔍 Post già notificati: $_notifiedUrgentPostIds');

        // Filtra SOLO i post urgenti che NON sono già stati notificati
        final unnotifiedNewUrgentIds = reallyNewUrgentIds
            .where((id) => !_notifiedUrgentPostIds.contains(id))
            .toSet();

        debugPrint(
            '🚨 Post urgenti nuovi NON ancora notificati: $unnotifiedNewUrgentIds');

        if (unnotifiedNewUrgentIds.isNotEmpty) {
          debugPrint(
              '🚨 Mostro popup per l\'ultimo post urgente non notificato...');

          // Prendi solo l'ultimo (più recente) post urgente
          final latestUrgentId = unnotifiedNewUrgentIds.last;

          for (final newUrgentId in [latestUrgentId]) {
            // Verifica DOPPIA che non sia già stato notificato
            if (_notifiedUrgentPostIds.contains(newUrgentId)) {
              debugPrint('⚠️ SKIP: Post ID=$newUrgentId già notificato');
              continue;
            }

            // Aggiungi SUBITO alla lista dei notificati per evitare duplicati
            _notifiedUrgentPostIds.add(newUrgentId);
            debugPrint(
                '✅ Aggiunto ID=$newUrgentId alla lista notificati: $_notifiedUrgentPostIds');

            // Salva la lista aggiornata in cache persistente
            _saveNotifiedPostsToCache();

            // Trova il post completo
            final newUrgentPost = filtered.firstWhere(
              (p) => p['id'] == newUrgentId,
              orElse: () => null,
            );

            if (newUrgentPost != null) {
              final dynamic titleData = newUrgentPost['title'];
              final String title = titleData != null && titleData is Map
                  ? (titleData['rendered'] ?? 'Comunicazione urgente')
                  : 'Comunicazione urgente';
              final cleanTitle = title.replaceAll(RegExp(r'<[^>]*>'), '');
              final notificationBody = _buildNotificationBody(newUrgentPost);

              debugPrint(
                  '🆕🚨 NUOVO POST URGENTE SCARICATO: ID=$newUrgentId - "$cleanTitle"');

              unawaited(showLocalNotification(
                id: newUrgentId,
                title: cleanTitle,
                body: notificationBody,
                payload: newUrgentId.toString(),
              ));

              // Mostra popup IMMEDIATAMENTE
              Future.microtask(() {
                if (!mounted) return;
                final ctx = navigatorKey.currentContext;
                if (ctx != null && ctx.mounted) {
                  debugPrint(
                      '🚀 MOSTRO POPUP IMMEDIATO per nuovo post urgente ID=$newUrgentId');
                  try {
                    _showUrgentNotificationDialog(ctx, cleanTitle, newUrgentId);
                    debugPrint(
                        '✅ POPUP NUOVO POST URGENTE MOSTRATO per ID=$newUrgentId!');
                  } catch (e) {
                    debugPrint(
                        '❌ Errore mostrando popup nuovo post urgente ID=$newUrgentId: $e');
                  }
                }
              });
            }
          }
        } else {
          debugPrint('✅ Tutti i nuovi post urgenti sono già stati notificati');
        }
      } else {
        debugPrint('✅ Nessun nuovo post urgente da mostrare via download');
      }

      // 🧹 STEP 4: Pulisci la lista dei post notificati (rimuovi post che non esistono più)
      _cleanNotifiedPostsList();

      // Mantieni il watcher solo come backup per eventuali post persi
      if (posts.isNotEmpty) {
        final currentContext = navigatorKey.currentContext;
        if (currentContext != null) {
          startUrgentNotificationWatcher(currentContext, posts);
          debugPrint('🔔 Watcher popup riavviato come backup');
        }
      }
    } else {
      debugPrint('Widget non mounted, non aggiorno lo state');
    }
  }

  Future<void> _fetchPostsAlternative() async {
    try {
      debugPrint('Tentativo caricamento post alternativo...');

      // Prova a caricare i post direttamente dalla pagina principale
      final response = await http.get(
        Uri.parse(appSettings.urlHome),
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; Flutter App)',
        },
      );

      if (response.statusCode == 200) {
        // Non creare post di esempio, lascia la lista vuota
        if (mounted) {
          setState(() {
            posts = [];
            isLoadingPosts = false;
          });
        }
        debugPrint('Nessun post disponibile, lista vuota');
      }
    } catch (e) {
      debugPrint('Errore caricamento post alternativo: $e');
      if (mounted) {
        setState(() {
          posts = [];
          isLoadingPosts = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------

  Widget _getBody() {
    switch (_selectedIndex) {
      case 0:
        return _homeContent(); // Solo pulsanti servizi
      case 1:
        // 📰 NEWS: Mostra TUTTI i post come lista diretta
        final allPostsNews =
            translatedPosts.isNotEmpty ? translatedPosts : posts;
        debugPrint(
            '📰 NEWS: Mostrando ${allPostsNews.length} post come lista diretta');

        return allPostsNews.isNotEmpty
            ? ModernArticlesScreen(
                posts: allPostsNews,
                userName: userData?['name'] ?? '',
                userEmail: userData?['email'] ?? '',
                showDirectList: true, // 🔥 NEWS: lista diretta di tutti i post
              )
            : const NoAccessMessage();
      case 2:
        return ContactOptionsScreen(
          userName: userData?['name'] ?? '',
          userEmail: userData?['email'] ?? '',
        );
      case 3:
        // 📁 ARTICOLI: Mostra categorie (come prima)
        final allPosts = translatedPosts.isNotEmpty ? translatedPosts : posts;

        debugPrint('🔍🔍🔍 ===== DEBUG NEWS SECTION =====');
        debugPrint('📰 posts.length=${posts.length}');
        debugPrint('📰 translatedPosts.length=${translatedPosts.length}');
        debugPrint('📰 urgentPosts.length=${urgentPosts.length}');
        debugPrint(
            '📰 allPosts.length=${allPosts.length} (questo viene passato a ModernArticlesScreen)');

        // Log TUTTI i titoli dei post in allPosts
        debugPrint('📰 LISTA COMPLETA POST in allPosts:');
        for (int i = 0; i < allPosts.length; i++) {
          final title = allPosts[i]['title']?['rendered'] ?? 'Senza titolo';
          final isUrg = _isUrgent(allPosts[i]);
          debugPrint(
              '   ${i + 1}. "$title" - ${isUrg ? "⚠️ URGENTE" : "✅ NORMALE"}');
        }
        debugPrint('🔍🔍🔍 ===== FINE DEBUG NEWS =====');

        // Conta urgenti vs normali
        if (allPosts.isNotEmpty) {
          int urgentCount = allPosts.where((p) => _isUrgent(p)).length;
          int normalCount = allPosts.length - urgentCount;
          debugPrint(
              '📰 NEWS: $urgentCount urgenti + $normalCount normali = ${allPosts.length} totali');

          // Log primi 5 post
          for (int i = 0; i < allPosts.length && i < 5; i++) {
            final post = allPosts[i];
            final title = post['title']?['rendered'] ?? 'Senza titolo';
            final isUrg = _isUrgent(post);
            debugPrint(
                '📰 NEWS: Post ${i + 1}: "$title" (${isUrg ? "URGENTE" : "normale"})');
          }
        }

        return allPosts.isNotEmpty
            ? ModernArticlesScreen(
                posts: allPosts,
                userName: userData?['name'] ?? '',
                userEmail: userData?['email'] ?? '',
                showDirectList:
                    false, // 📁 ARTICOLI: mostra categorie (come prima)
              )
            : const NoAccessMessage();
      case 4:
        return const WebcamScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingUserData) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text(
                'Caricamento dati...',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    isLoadingUserData = false;
                  });
                },
                child: const Text('Salta caricamento'),
              ),
            ],
          ),
        ),
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
              colors: [AppColors.primary, AppColors.secondaryBlue],
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
                      Text(
                        AppLocalizations.of(context).portoBello,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                            onTap: () async {
                              Navigator.pop(context);
                              final Uri uri = Uri.parse(
                                  'https://www.portobellodigallura.it');
                              try {
                                final bool canLaunch = await canLaunchUrl(uri);
                                if (canLaunch) {
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Non è possibile aprire il sito web. Verifica la connessione internet.',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        backgroundColor: Colors.red,
                                        duration: Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Errore nell\'apertura del sito: ${e.toString()}',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      backgroundColor: Colors.red,
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildModernMenuItem(
                            context,
                            icon: Icons.contact_mail,
                            title: AppLocalizations.of(context).contacts,
                            subtitle:
                                AppLocalizations.of(context).contactThePort,
                            color: AppColors.secondaryBlue,
                            onTap: () {
                              Navigator.pop(context);
                              _showContactsDialog(context);
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
                      color: const Color(0xFFE53935),
                      borderRadius: BorderRadius.circular(12),
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
                        Navigator.of(context).pop();

                        // Mostra dialogo di conferma
                        final conferma = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Conferma Logout'),
                              content:
                                  const Text('Sei sicuro di voler uscire?'),
                              actions: <Widget>[
                                TextButton(
                                  child: const Text('Annulla'),
                                  onPressed: () {
                                    Navigator.of(context).pop(false);
                                  },
                                ),
                                TextButton(
                                  child: const Text('Esci'),
                                  onPressed: () {
                                    Navigator.of(context).pop(true);
                                  },
                                ),
                              ],
                            );
                          },
                        );

                        if (conferma == true && context.mounted) {
                          await clearLoginData();

                          // Usa pushAndRemoveUntil per pulire tutto lo stack e tornare alla login
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                  builder: (context) => const LoginScreen()),
                              (Route<dynamic> route) => false,
                            );
                          }
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
            backgroundColor: AppColors.secondary,
            elevation: 8,
            automaticallyImplyLeading: false,
            centerTitle: true,
            title: Image.asset('assets/logo.png', height: 40),
            actions: [
              IconButton(
                icon: const Icon(Icons.menu, color: Colors.blue),
                onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                tooltip: 'Menu',
              ),
            ],
          ),
        ),
      ),
      body: _getBody(),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.secondary,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.black54,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 10, // Ridotto per evitare overflow
        unselectedFontSize: 9, // Ridotto per evitare overflow
        iconSize: 22, // Ridotto leggermente
        items: [
          BottomNavigationBarItem(
              icon: const Icon(Icons.home),
              label: AppLocalizations.of(context).home),
          const BottomNavigationBarItem(
              icon: Icon(Icons.article), label: 'News'),
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
    return decodedText
        .replaceAll(regex, '')
        .replaceAll('::', '')
        .replaceAll(RegExp(r'/\d+'), ''); // Rimuove /2, /3, /4, etc.
  }

  String _buildNotificationBody(Map<String, dynamic> post) {
    final rawExcerpt = post['excerpt']?['rendered'] ?? '';
    final rawContent = post['content']?['rendered'] ?? '';
    final source = rawExcerpt.isNotEmpty ? rawExcerpt : rawContent;

    var cleanText =
        _removeHtmlTags(source).replaceAll(RegExp(r'\s+'), ' ').trim();

    if (cleanText.isEmpty) {
      cleanText = 'Apri l\'app per leggere la comunicazione urgente.';
    }

    if (cleanText.length > 140) {
      cleanText = '${cleanText.substring(0, 137)}...';
    }

    return cleanText;
  }

  bool _isUrgent(dynamic post) {
    final categories = post['_embedded']?['wp:term']?[0];
    if (categories == null) return false;
    if (categories is! List) return false;
    // Cerca sia "urgente" che "urgenti" (singolare e plurale)
    return categories.any((c) {
      final name = (c['name'] as String?)?.toLowerCase() ?? '';
      return name
          .contains('urgent'); // Copre: urgente, urgenti, urgent, urgency
    });
  }

  // ---------------------------------------------------------------------------
  // HOME CONTENT - Pulsanti servizi + Post
  Widget _homeContent() {
    // Mostra indicatore di caricamento se i post urgenti sono vuoti e stiamo ancora caricando
    if (urgentPosts.isEmpty && isLoadingPosts) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFC107)),
            ),
            SizedBox(height: 16),
            Text(
              'Caricamento comunicazioni urgenti...',
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

    final visiblePosts = urgentPosts.where((post) {
      final title =
          decodeHtmlEntities(post['title']?['rendered'] ?? '').toLowerCase();
      final content = decodeHtmlEntities(post['content']?['rendered'] ?? '');
      final excerpt = decodeHtmlEntities(post['excerpt']?['rendered'] ?? '');

      final hasRestrictedTitle = title.contains('restricted');
      final hasRestrictedContent = content.contains('effettuare il login') ||
          excerpt.contains('effettuare il login') ||
          excerpt.contains('devi essere loggato');

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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: visiblePosts.isNotEmpty
              ? CustomScrollView(
                  slivers: [
                    // Pulsanti dei servizi
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          _buildButton(
                              context, "Emergenze", 'assets/emergenza.png'),
                          _buildButton(context, "Assistenza medica",
                              'assets/ritiro_rifiuti.png'),
                          _buildButton(
                              context, "Segnala Guasto", 'assets/guasto.png'),
                          _buildButton(context, "Ritiro rifiuti",
                              'assets/ritiro_rifiuti.png'),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                    // Lista dei post
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final post = visiblePosts[index];
                          final categories = post['_embedded']?['wp:term']?[0];
                          final categoryNames =
                              (categories is List && categories.isNotEmpty)
                                  ? categories
                                      .map<String>(
                                          (c) => (c['name'] ?? '') as String)
                                      .join(', ')
                                  : 'Senza categoria';

                          final imageUrl = post['_embedded']
                              ?['wp:featuredmedia']?[0]?['source_url'];
                          final isUrgente = _isUrgent(post);
                          final url = post['link'];
                          final authorId = post['author'] ?? 0;
                          final status = post['status'] ?? '';

                          final Color badgeColor = isUrgente
                              ? const Color(0xFFE53935)
                              : (status == 'private'
                                  ? const Color(0xFFFF9800)
                                  : AppColors.secondaryBlue);

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
                                          userName:
                                              userData?['name'] ?? 'Utente',
                                          userEmail: userData?['email'] ?? '',
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isUrgente
                                          ? const Color(
                                              0xFFFFEBEE) // Sfondo rosso chiaro per urgenti
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(24),
                                      border: isUrgente
                                          ? Border.all(
                                              color: const Color(
                                                  0xFFE53935), // Bordo rosso per urgenti
                                              width: 3,
                                            )
                                          : null,
                                      boxShadow: [
                                        BoxShadow(
                                          color: isUrgente
                                              ? const Color(0xFFE53935)
                                                  .withOpacity(0.3)
                                              : Colors.black.withOpacity(0.08),
                                          blurRadius: 16,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (imageUrl != null)
                                          ClipRRect(
                                            borderRadius:
                                                const BorderRadius.only(
                                              topLeft: Radius.circular(24),
                                              topRight: Radius.circular(24),
                                            ),
                                            child: Stack(
                                              children: [
                                                Image.network(
                                                  imageUrl,
                                                  width: double.infinity,
                                                  height: 220,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error,
                                                      stackTrace) {
                                                    return Container(
                                                      height: 220,
                                                      color: const Color(
                                                          0xFFE0E0E0),
                                                      child: const Center(
                                                        child: Icon(Icons.image,
                                                            size: 48,
                                                            color: Colors.grey),
                                                      ),
                                                    );
                                                  },
                                                ),
                                                Positioned.fill(
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        begin:
                                                            Alignment.topCenter,
                                                        end: Alignment
                                                            .bottomCenter,
                                                        colors: [
                                                          Colors.transparent,
                                                          Colors.black
                                                              .withOpacity(0.3)
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
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 12,
                                                          vertical: 6),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                            0xFFE53935),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20),
                                                      ),
                                                      child: const Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                              Icons
                                                                  .priority_high_rounded,
                                                              color:
                                                                  Colors.white,
                                                              size: 16),
                                                          SizedBox(width: 4),
                                                          Text(
                                                            'URGENTE',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
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
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 12,
                                                          vertical: 6),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                            0xFFFF9800),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20),
                                                      ),
                                                      child: const Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.lock,
                                                              color:
                                                                  Colors.white,
                                                              size: 14),
                                                          SizedBox(width: 4),
                                                          Text(
                                                            'PRIVATO',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        Padding(
                                          padding: const EdgeInsets.all(20),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                decodeHtmlEntities(post['title']
                                                        ?['rendered'] ??
                                                    ''),
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF212121),
                                                  height: 1.3,
                                                ),
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 12),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 10,
                                                        vertical: 5),
                                                    decoration: BoxDecoration(
                                                      color: isUrgente
                                                          ? const Color(
                                                                  0xFFE53935)
                                                              .withOpacity(0.1)
                                                          : (status == 'private'
                                                              ? const Color(
                                                                      0xFFFF9800)
                                                                  .withOpacity(
                                                                      0.1)
                                                              : const Color(
                                                                      0xFF4CAF50)
                                                                  .withOpacity(
                                                                      0.1)),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    child: Text(
                                                      isUrgente
                                                          ? 'Urgente'
                                                          : (status == 'private'
                                                              ? 'Privato'
                                                              : 'Pubblico'),
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: isUrgente
                                                            ? const Color(
                                                                0xFFE53935)
                                                            : (status ==
                                                                    'private'
                                                                ? const Color(
                                                                    0xFFFF9800)
                                                                : const Color(
                                                                    0xFF4CAF50)),
                                                      ),
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  if (authorId is int &&
                                                      authorId > 0)
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
                                                        userName:
                                                            userData?['name'] ??
                                                                'Utente',
                                                        userEmail: userData?[
                                                                'email'] ??
                                                            '',
                                                      ),
                                                    ),
                                                  );
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: badgeColor,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 24,
                                                      vertical: 12),
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              16)),
                                                  elevation: 4,
                                                  shadowColor: badgeColor
                                                      .withOpacity(0.3),
                                                ),
                                                child: const Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text('Leggi tutto',
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: 14)),
                                                    SizedBox(width: 8),
                                                    Icon(
                                                        Icons
                                                            .arrow_forward_rounded,
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
                              ));
                        },
                        childCount: visiblePosts.length,
                      ),
                    ),
                  ],
                )
              : ListView(
                  children: [
                    const SizedBox(height: 8),
                    _buildButton(context, "Emergenze", 'assets/emergenza.png'),
                    _buildButton(context, "Assistenza medica",
                        'assets/ritiro_rifiuti.png'),
                    _buildButton(
                        context, "Segnala Guasto", 'assets/guasto.png'),
                    _buildButton(
                        context, "Ritiro rifiuti", 'assets/ritiro_rifiuti.png'),
                    const SizedBox(height: 40),
                    const Icon(Icons.inbox_outlined,
                        size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Nessuna comunicazione disponibile',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await fetchPosts();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Ricarica'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // COMUNICAZIONI CONTENT - Post
  Widget _comunicazioniContent() {
    // 🚨 HOME: Mostra solo ultimi 5 post URGENTI

    // Mostra indicatore di caricamento
    if (urgentPosts.isEmpty && isLoadingPosts) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFC107)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Caricamento comunicazioni urgenti...',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF666666),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  isLoadingPosts = false;
                });
              },
              child: const Text('Continua senza post'),
            ),
          ],
        ),
      );
    }

    // Usa solo urgentPosts (max 5, già filtrati e ordinati)
    final visiblePosts = urgentPosts.where((post) {
      final title =
          decodeHtmlEntities(post['title']?['rendered'] ?? '').toLowerCase();
      final content = decodeHtmlEntities(post['content']?['rendered'] ?? '');
      final excerpt = decodeHtmlEntities(post['excerpt']?['rendered'] ?? '');

      final hasRestrictedTitle = title.contains('restricted');
      final hasRestrictedContent = content.contains('effettuare il login') ||
          excerpt.contains('effettuare il login') ||
          excerpt.contains('devi essere loggato');

      final isVisible = !hasRestrictedTitle && !hasRestrictedContent;

      return isVisible;
    }).toList();

    debugPrint(
        '🚨 HOME: urgentPosts=${urgentPosts.length}, visibili=${visiblePosts.length}');

    // Mostra indicatore durante il rendering iniziale se necessario
    if (visiblePosts.isNotEmpty && isLoadingPosts) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Rendering comunicazioni urgenti...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: visiblePosts.isNotEmpty
              ? ListView.builder(
                  itemCount: visiblePosts.length,
                  itemBuilder: (context, index) {
                    final post = visiblePosts[index];
                    final categories = post['_embedded']?['wp:term']?[0];
                    final categoryNames =
                        (categories is List && categories.isNotEmpty)
                            ? categories
                                .map<String>((c) => (c['name'] ?? '') as String)
                                .join(', ')
                            : 'Senza categoria';

                    final imageUrl = post['_embedded']?['wp:featuredmedia']?[0]
                        ?['source_url'];
                    final isUrgente = _isUrgent(post);
                    final url = post['link'];
                    final authorId = post['author'] ?? 0;
                    final status = post['status'] ?? '';

                    final Color badgeColor = isUrgente
                        ? const Color(0xFFE53935)
                        : (status == 'private'
                            ? const Color(0xFFFF9800)
                            : AppColors.secondaryBlue);

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
                                        ? Colors.red.withOpacity(0.15)
                                        : Colors.black.withOpacity(0.06),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
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
                                            loadingBuilder: (context, child,
                                                loadingProgress) {
                                              if (loadingProgress == null)
                                                return child;
                                              return Container(
                                                height: 180,
                                                width: double.infinity,
                                                color: Colors.grey[300],
                                                child: Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                    value: loadingProgress
                                                                .expectedTotalBytes !=
                                                            null
                                                        ? loadingProgress
                                                                .cumulativeBytesLoaded /
                                                            loadingProgress
                                                                .expectedTotalBytes!
                                                        : null,
                                                  ),
                                                ),
                                              );
                                            },
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Container(
                                                height: 180,
                                                width: double.infinity,
                                                color: Colors.grey[300],
                                                child: const Icon(
                                                  Icons.image_not_supported,
                                                  size: 48,
                                                  color: Colors.grey,
                                                ),
                                              );
                                            },
                                          ),
                                          Positioned.fill(
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    Colors.transparent,
                                                    Colors.black
                                                        .withOpacity(0.3)
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
                                                  color:
                                                      const Color(0xFFE53935),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: const Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
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
                                                padding:
                                                    const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFFF9800),
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
                                                padding:
                                                    const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: badgeColor
                                                      .withOpacity(0.1),
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
                                                  decodeHtmlEntities(
                                                      post['title']
                                                              ?['rendered'] ??
                                                          ''),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                    color: isUrgente
                                                        ? const Color(
                                                            0xFFC62828)
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
                                              color: AppColors.secondaryBlue
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
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
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
                                                              .withOpacity(
                                                                  0.1)),
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
                                                        ? const Color(
                                                            0xFFE53935)
                                                        : (status == 'private'
                                                            ? const Color(
                                                                0xFFFF9800)
                                                            : const Color(
                                                                0xFF4CAF50)),
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),
                                              if (authorId is int &&
                                                  authorId > 0)
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
                                                    userName:
                                                        userData?['name'] ??
                                                            'Utente',
                                                    userEmail:
                                                        userData?['email'] ??
                                                            '',
                                                  ),
                                                ),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: badgeColor,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 24,
                                                      vertical: 12),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          16)),
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
                                                Icon(
                                                    Icons.arrow_forward_rounded,
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
                  },
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.inbox_outlined,
                        size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Nessuna comunicazione disponibile',
                      textAlign: TextAlign.center,
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
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // Metodo per mostrare popup emergenze
  void _showEmergencyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.emergency, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text('Numeri di Emergenza',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildEmergencyItem(
                    'Numero unico emergenza (NUE)', 'Tel. 112', null),
                const Divider(),
                _buildEmergencyItem(
                    'Pronto intervento – soccorso sanitario', 'Tel. 118', null),
                const Divider(),
                _buildEmergencyItem(
                    'Carabinieri', 'Tel. 112', 'www.carabinieri.it'),
                const Divider(),
                _buildEmergencyItem(
                    'Polizia di Stato', 'Tel. 113', 'www.poliziadistato.it'),
                const Divider(),
                _buildEmergencyItem(
                    'Vigili del Fuoco', 'Tel. 115', 'www.vigilfuoco.it'),
                const Divider(),
                _buildEmergencyItem(
                    'Guardia di Finanza', 'Tel. 117', 'www.gdf.gov.it'),
                const Divider(),
                _buildEmergencyItem('Guardia Costiera – soccorso in mare',
                    'Tel. 1530', 'www.guardiacostiera.gov.it'),
                const Divider(),
                _buildEmergencyItem(
                    'SOS elettricità (ENEL)', 'Tel. 803 500', 'www.enel.it'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Chiudi', style: TextStyle(fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmergencyItem(String title, String phone, String? website) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          _buildPhoneNumber(phone),
          if (website != null) ...[
            const SizedBox(height: 2),
            Text(website,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }

  // Metodo per mostrare popup servizi sanitari
  void _showMedicalServicesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.local_hospital, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text('Servizi Sanitari',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Guardia medica Portobello',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                const Text('Dott. Luigi Pansini',
                    style:
                        TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
                const SizedBox(height: 8),
                const Text(
                    'Periodo 15 giugno - 15 settembre:\n• Visite: 9.00-11.00 (lun-ven) presso ambulatorio Club\n• Reperibile: 8.00-18.00 (lun-ven) al 335 646 2457\n• Urgenze: 18.00-8.00 (tutti i giorni)',
                    style: TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                _buildPhoneNumber('Cell. +39 327 796 4108'),
                const Divider(height: 24),
                _buildMedicalSection(
                    'ASL Gallura – Ambulatorio continuità assistenziale', [
                  'Vignola Mare, Camping Saragosa\nTel. +39 079 678463',
                  'Santa Teresa di Gallura - Via Carlo Felice\nTel. +39 0789 552 021',
                  'Isola Rossa - Corso Trinità\nTel. +39 079 678 464',
                ]),
                const Divider(height: 24),
                _buildMedicalSection('Guardia medica', [
                  'Arzachena - Via J. di Scanu\nTel. +39 0789 552 600',
                  'Calangianus - via Madrid\nTel. +39 079 660 234',
                  'Luogosanto - Via Trieste\nTel. +39 079 678 404; +39 079 678 403',
                  'Palau - Via degli Achei\nTel. +39 0789 552 809',
                  'Santa Teresa - Via Carlo Felice, 112\nTel. +39 0789 552 867',
                  'Sant\'Antonio di Gallura - Via G. Galilei\nTel. +39 366 812 3023',
                  'Tempio Pausania – Ospedale Paolo Dettori\nTel. +39 079 678 306',
                  'Trinità d\'Agultu - Vicolo Bortigiadas\nTel. +39 079 678 479',
                ]),
                const Divider(height: 24),
                const Text('Ospedale Giovanni Paolo II, Olbia',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                const Text('Via Bazzoni – Sircana, 2/2A',
                    style: TextStyle(fontSize: 13)),
                const SizedBox(height: 4),
                _buildPhoneNumber('Tel. +39 0789 552 200'),
                const Divider(height: 24),
                _buildMedicalSection('Farmacie', [
                  'Farmacia Collu - Via Tempio 12, Aglientu\nTel. +39 079 654 445',
                  'Farmacia Grixoni - Via Al Mare 25, Trinità D\'Agultu\nTel. +39 079 681 214',
                  'Farmacia Orecchioni - Via Vittorio Emanuele 45, Luogosanto\nTel. +39 079 652 029',
                  'Farmacia Bulciolu - Piazza S. Vittorio 2, Santa Teresa\nTel. +39 0789 754 365',
                  'Farmacia Pinna - Via San Paolo 2, Tempio Pausania\nTel. +39 079 631 156',
                  'Farmacia Spano - Piazza Gallura 20, Tempio Pausania\nTel. +39 079 631 254',
                ]),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Chiudi', style: TextStyle(fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMedicalSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        ...items.map((item) {
          // Cerca pattern di numeri di telefono nel testo
          final phonePattern = RegExp(r'(Tel\.\s*\+?\d[\d\s]+)');
          final match = phonePattern.firstMatch(item);

          if (match != null) {
            // Dividi il testo in parti prima e dopo il numero
            final beforePhone = item.substring(0, match.start);
            final phoneText = match.group(0)!;
            final afterPhone = item.substring(match.end);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 13, color: Colors.black),
                  children: [
                    TextSpan(text: beforePhone),
                    WidgetSpan(
                      child: _buildPhoneNumber(phoneText),
                    ),
                    TextSpan(text: afterPhone),
                  ],
                ),
              ),
            );
          } else {
            // Nessun numero trovato, mostra il testo normale
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(item, style: const TextStyle(fontSize: 13)),
            );
          }
        }),
      ],
    );
  }

  Widget _buildPhoneNumber(String phoneNumber) {
    return GestureDetector(
      onTap: () async {
        final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
        final Uri telUri = Uri.parse('tel:$cleanNumber');
        if (await canLaunchUrl(telUri)) {
          await launchUrl(telUri);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.phone,
              size: 14,
              color: AppColors.primary,
            ),
            const SizedBox(width: 4),
            Text(
              phoneNumber,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Metodo per costruire i pulsanti dei servizi
  Widget _buildButton(BuildContext context, String label, String imagePath) {
    // Tutti i servizi usano il colore blu principale
    const Color primaryColor = AppColors.primary;
    const Color secondaryColor = AppColors.secondaryBlue;

    return Container(
      width: double.infinity,
      height: 70,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
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
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
        onPressed: () {
          // Gestisci casi speciali per Emergenze e Assistenza medica
          if (label == "Emergenze") {
            _showEmergencyDialog(context);
          } else if (label == "Assistenza medica" ||
              label == "Servizi sanitari") {
            _showMedicalServicesDialog(context);
          } else {
            // Per gli altri servizi, apri il form email
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EmailFormTab(
                  userName: userData?['name'] ?? 'Utente',
                  userEmail: userData?['email'] ?? '',
                  subject: label,
                ),
              ),
            );
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              imagePath,
              width: 32,
              height: 32,
              color: Colors.white,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.image_not_supported,
                    color: Colors.white, size: 28);
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
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
        title: Text(
          title,
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
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
                'Sito Online',
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
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CustomWebViewScreen(
                    url: appSettings.urlDoveSiamo,
                    title: 'Dove siamo',
                  ),
                ),
              ),
            ),
            _buildUsefulSectionItem(
              context,
              'Numeri Utili',
              'Contatti e informazioni',
              Icons.phone,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CustomWebViewScreen(
                    url: appSettings.urlNumeriUtili,
                    title: 'Numeri Utili',
                  ),
                ),
              ),
            ),
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
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _showContactsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.location_on, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Parco di Portobello'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Parco Residenziale Portobello di Gallura',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text('07020 Aglientu (SS)'),
              const Text('C.F.: 82001540903'),
              const Text('P. IVA: 00348270901'),
              const Text('Lunedì-venerdì 8.30-12.00, 12.30-16.30'),
              const SizedBox(height: 16),
              const Text(
                'Amministratore – Avv. Paolo Orecchioni',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              _buildPhoneNumber('Tel. +39 079 656 718'),
              _buildPhoneNumber('Tel. +39 079 656 766'),
              _buildPhoneNumber('Cell. +39 345 932 9195'),
              const Text('Fax +39 079 656 666'),
              GestureDetector(
                onTap: () async {
                  final Uri emailUri =
                      Uri.parse('mailto:amministratore@portobellodigallura.it');
                  if (await canLaunchUrl(emailUri)) {
                    await launchUrl(emailUri);
                  }
                },
                child: const Text(
                  'amministratore@portobellodigallura.it',
                  style: TextStyle(
                    color: AppColors.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ufficio tecnico – Geom. Michele Cossu',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              _buildPhoneNumber('Tel. +39 079 656 718'),
              const Text('Fax +39 079 656 666'),
              GestureDetector(
                onTap: () async {
                  final Uri emailUri =
                      Uri.parse('mailto:segreteria@portobellodigallura.it');
                  if (await canLaunchUrl(emailUri)) {
                    await launchUrl(emailUri);
                  }
                },
                child: const Text(
                  'segreteria@portobellodigallura.it',
                  style: TextStyle(
                    color: AppColors.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Portineria est',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              _buildPhoneNumber('Cell. +39 389 784 7867'),
              const SizedBox(height: 8),
              const Text(
                'Portineria ovest',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              _buildPhoneNumber('Cell. +39 389 784 8651'),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Chiudi')),
        ],
      ),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
          backgroundColor: AppColors.secondary, // Giallo sole
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
        backgroundColor: AppColors.secondary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Image.asset('assets/logo.png', height: 60),
                        const SizedBox(width: 16),
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
                      'Benvenuto nell\'applicazione ufficiale del Portobello di Gallura. '
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF37474F),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
    return decodedText
        .replaceAll(regex, '')
        .replaceAll('::', '')
        .replaceAll(RegExp(r'/\d+'), ''); // Rimuove /2, /3, /4, etc.
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
      backgroundColor: const Color(0xFFE0F7FA),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFE0F7FA),
              Color(0xFFF0F8FF),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildButton(context, "Bombole Gas", 'assets/bombolegas.png'),
                _buildButton(
                    context, "Ritiro Rifiuti", 'assets/ritiro_rifiuti.png'),
                _buildButton(
                    context, "Segnalazione Guasto", 'assets/guasto.png'),
                _buildButton(context, "Ormeggio", 'assets/ormeggio.png'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneNumber(String phoneNumber) {
    return GestureDetector(
      onTap: () async {
        final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
        final Uri telUri = Uri.parse('tel:$cleanNumber');
        if (await canLaunchUrl(telUri)) {
          await launchUrl(telUri);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.phone,
              size: 14,
              color: AppColors.primary,
            ),
            const SizedBox(width: 4),
            Text(
              phoneNumber,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Metodi helper per i popup (come in _MyHomePageState)
  void _showEmergencyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.emergency, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text('Numeri di Emergenza',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildEmergencyItem(
                    'Numero unico emergenza (NUE)', 'Tel. 112', null),
                const Divider(),
                _buildEmergencyItem(
                    'Pronto intervento – soccorso sanitario', 'Tel. 118', null),
                const Divider(),
                _buildEmergencyItem(
                    'Carabinieri', 'Tel. 112', 'www.carabinieri.it'),
                const Divider(),
                _buildEmergencyItem(
                    'Polizia di Stato', 'Tel. 113', 'www.poliziadistato.it'),
                const Divider(),
                _buildEmergencyItem(
                    'Vigili del Fuoco', 'Tel. 115', 'www.vigilfuoco.it'),
                const Divider(),
                _buildEmergencyItem(
                    'Guardia di Finanza', 'Tel. 117', 'www.gdf.gov.it'),
                const Divider(),
                _buildEmergencyItem('Guardia Costiera – soccorso in mare',
                    'Tel. 1530', 'www.guardiacostiera.gov.it'),
                const Divider(),
                _buildEmergencyItem(
                    'SOS elettricità (ENEL)', 'Tel. 803 500', 'www.enel.it'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Chiudi', style: TextStyle(fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmergencyItem(String title, String phone, String? website) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          _buildPhoneNumber(phone),
          if (website != null) ...[
            const SizedBox(height: 2),
            Text(website,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }

  void _showMedicalServicesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.local_hospital, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text('Servizi Sanitari',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Guardia medica Portobello',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                const Text('Dott. Luigi Pansini',
                    style:
                        TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
                const SizedBox(height: 8),
                const Text(
                    'Periodo 15 giugno - 15 settembre:\n• Visite: 9.00-11.00 (lun-ven) presso ambulatorio Club\n• Reperibile: 8.00-18.00 (lun-ven) al 335 646 2457\n• Urgenze: 18.00-8.00 (tutti i giorni)',
                    style: TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                _buildPhoneNumber('Cell. +39 327 796 4108'),
                const Divider(height: 24),
                _buildMedicalSection(
                    'ASL Gallura – Ambulatorio continuità assistenziale', [
                  'Vignola Mare, Camping Saragosa\nTel. +39 079 678463',
                  'Santa Teresa di Gallura - Via Carlo Felice\nTel. +39 0789 552 021',
                  'Isola Rossa - Corso Trinità\nTel. +39 079 678 464',
                ]),
                const Divider(height: 24),
                _buildMedicalSection('Guardia medica', [
                  'Arzachena - Via J. di Scanu\nTel. +39 0789 552 600',
                  'Calangianus - via Madrid\nTel. +39 079 660 234',
                  'Luogosanto - Via Trieste\nTel. +39 079 678 404; +39 079 678 403',
                  'Palau - Via degli Achei\nTel. +39 0789 552 809',
                  'Santa Teresa - Via Carlo Felice, 112\nTel. +39 0789 552 867',
                  'Sant\'Antonio di Gallura - Via G. Galilei\nTel. +39 366 812 3023',
                  'Tempio Pausania – Ospedale Paolo Dettori\nTel. +39 079 678 306',
                  'Trinità d\'Agultu - Vicolo Bortigiadas\nTel. +39 079 678 479',
                ]),
                const Divider(height: 24),
                const Text('Ospedale Giovanni Paolo II, Olbia',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                const Text('Via Bazzoni – Sircana, 2/2A',
                    style: TextStyle(fontSize: 13)),
                const SizedBox(height: 4),
                _buildPhoneNumber('Tel. +39 0789 552 200'),
                const Divider(height: 24),
                _buildMedicalSection('Farmacie', [
                  'Farmacia Collu - Via Tempio 12, Aglientu\nTel. +39 079 654 445',
                  'Farmacia Grixoni - Via Al Mare 25, Trinità D\'Agultu\nTel. +39 079 681 214',
                  'Farmacia Orecchioni - Via Vittorio Emanuele 45, Luogosanto\nTel. +39 079 652 029',
                  'Farmacia Bulciolu - Piazza S. Vittorio 2, Santa Teresa\nTel. +39 0789 754 365',
                  'Farmacia Pinna - Via San Paolo 2, Tempio Pausania\nTel. +39 079 631 156',
                  'Farmacia Spano - Piazza Gallura 20, Tempio Pausania\nTel. +39 079 631 254',
                ]),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Chiudi', style: TextStyle(fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMedicalSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        ...items.map((item) {
          // Cerca pattern di numeri di telefono nel testo
          final phonePattern = RegExp(r'(Tel\.\s*\+?\d[\d\s]+)');
          final match = phonePattern.firstMatch(item);

          if (match != null) {
            // Dividi il testo in parti prima e dopo il numero
            final beforePhone = item.substring(0, match.start);
            final phoneText = match.group(0)!;
            final afterPhone = item.substring(match.end);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 13, color: Colors.black),
                  children: [
                    TextSpan(text: beforePhone),
                    WidgetSpan(
                      child: _buildPhoneNumber(phoneText),
                    ),
                    TextSpan(text: afterPhone),
                  ],
                ),
              ),
            );
          } else {
            // Nessun numero trovato, mostra il testo normale
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(item, style: const TextStyle(fontSize: 13)),
            );
          }
        }),
      ],
    );
  }

  Widget _buildButton(BuildContext context, String label, String imagePath) {
    // Tutti i servizi usano il colore blu principale
    const Color primaryColor = AppColors.primary;
    const Color secondaryColor = AppColors.secondaryBlue;

    return Container(
      width: double.infinity,
      height: 70,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
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
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
        onPressed: () {
          // Gestisci casi speciali per Emergenze e Assistenza medica
          if (label == "Emergenze") {
            _showEmergencyDialog(context);
          } else if (label == "Assistenza medica" ||
              label == "Servizi sanitari") {
            _showMedicalServicesDialog(context);
          } else {
            // Per gli altri servizi, apri il form email
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
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              imagePath,
              width: 32,
              height: 32,
              color: Colors.white,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.image_not_supported,
                    color: Colors.white, size: 28);
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.userEmail);
    // Estrai nome e cognome dall'email
    final extractedName = _extractNameFromEmail(widget.userEmail);
    _nameController = TextEditingController(text: extractedName);
  }

  // Funzione helper per estrarre nome e cognome dall'email
  String _extractNameFromEmail(String email) {
    if (email.isEmpty) return '';

    // Prendi la parte prima della @
    final atIndex = email.indexOf('@');
    if (atIndex == -1) return email;

    final localPart = email.substring(0, atIndex);

    // Sostituisci . _ - con spazi e capitalizza ogni parola
    final parts = localPart.split(RegExp(r'[._-]'));
    final capitalizedParts = parts.map((part) {
      if (part.isEmpty) return '';
      return part[0].toUpperCase() + part.substring(1).toLowerCase();
    }).where((part) => part.isNotEmpty);

    return capitalizedParts.join(' ');
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
        SnackBar(
            content: Text(AppLocalizations.of(context).fillRequiredFields)),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

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
Inviato dall'app Portobello di Gallura
      ''';

      // Invia email via SMTP
      await sendEmail(
        to: AppSettings.emailWebmaster,
        subject: '${widget.subject} - $name',
        body: emailBody,
        replyTo: email, // Imposta l'email del mittente come reply-to
      );

      // Mostra messaggio di successo
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email inviata con successo!'),
            backgroundColor: Colors.green,
          ),
        );

        // Pulisci i campi
        _phoneController.clear();
        _messageController.clear();

        // Torna alla schermata precedente
        Navigator.pop(context);
      }
    } catch (e) {
      // Mostra messaggio di errore
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nell\'invio dell\'email: $e'),
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
        title: Text(
          widget.subject,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.secondary,
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
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                  label: Text(_isLoading
                      ? 'Invio in corso...'
                      : AppLocalizations.of(context).send),
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
                  onPressed: _isLoading ? null : _submitForm,
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
    return decodedText
        .replaceAll(regex, '')
        .replaceAll('::', '')
        .replaceAll(RegExp(r'/\d+'), ''); // Rimuove /2, /3, /4, etc.
  }

  String _formatItalianDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final months = [
        'gennaio',
        'febbraio',
        'marzo',
        'aprile',
        'maggio',
        'giugno',
        'luglio',
        'agosto',
        'settembre',
        'ottobre',
        'novembre',
        'dicembre'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return dateString;
    }
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
        backgroundColor: AppColors.primary,
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
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
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
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Categorie: $categoryNames',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (date.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Data: ${_formatItalianDate(date)}',
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
