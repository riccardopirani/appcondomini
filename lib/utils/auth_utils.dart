import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:condominio/config/constants.dart' show AppConstants, jwtToken;

var jwtToken;
/// Crea l'autenticazione Basic Auth
String createBasicAuth(String username, String password) {
  final credentials = '$username:$password';
  final encoded = base64Encode(utf8.encode(credentials));
  return 'Basic $encoded';
}

/// Ricarica il token dalle SharedPreferences
Future<void> reloadTokenFromStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('jwtToken');
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

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

/// Rigenera il token WordPress
Future<void> regenerateToken() async {
  final prefs = await SharedPreferences.getInstance();
  final username = prefs.getString('username');
  final password = prefs.getString('password');

  if (username != null && password != null) {
    debugPrint('Rigenerazione cookie per: $username');
    try {
      // Prima ottieni il nonce necessario per il login
      final nonceResponse = await http.get(
        Uri.parse('${AppConstants.urlSito}/wp-login.php'),
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
        Uri.parse('${AppConstants.urlSito}/wp-login.php'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Referer': '${AppConstants.urlSito}/wp-login.php',
        },
        body: nonce.isNotEmpty
            ? 'log=$username&pwd=$password&wp-submit=Log+In&redirect_to=${AppConstants.urlSito}/wp-admin/&testcookie=1&_wpnonce=$nonce'
            : 'log=$username&pwd=$password&wp-submit=Log+In&redirect_to=${AppConstants.urlSito}/wp-admin/&testcookie=1',
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

/// Verifica il successo del login
Future<void> _verifyLoginSuccess() async {
  try {
    debugPrint('Verifica successo login...');

    // Prova ad accedere a wp-admin per verificare il login
    final adminResponse = await http.get(
      Uri.parse('${AppConstants.urlSito}/wp-admin/'),
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

/// Cancella tutti i dati di login
Future<void> clearLoginData() async {
  debugPrint('🔓 Logout - cancellazione dati utente');
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('jwtToken');
  await prefs.remove('username');
  await prefs.remove('password');
  await prefs.remove('originalUsername');
  await prefs.remove('originalEmail');
  await prefs.setBool('isLoggedIn', false);
  jwtToken = null;
  debugPrint('✅ Tutti i dati utente cancellati');
}
