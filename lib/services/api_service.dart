import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Servizio API per l'autenticazione e le richieste al plugin PdG App API
class ApiService {
  static final ApiService _instance = ApiService._internal();

  factory ApiService() {
    return _instance;
  }

  ApiService._internal();

  // Costanti
  static const String apiBaseUrl = 'https://www.portobellodigallura.it/wp-json/pdg-app/v1';
  static const String apiKeyHeaderName = 'x-pdg-api-key';
  
  // ⚠️ CAMBIA QUESTA CHIAVE IN wp-config.php
  static const String apiKey = 'Tz7Wq8GlWVlVhZg3sGQgRrSn7lOc8AHe';

  // Variabili di stato
  String? _token;
  DateTime? _tokenExpiry;

  // Getter per il token
  String? get token => _token;
  bool get isAuthenticated => _token != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!);

  /// Carica il token dalle SharedPreferences
  Future<void> loadToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('pdg_app_token');
      final expiryTimestamp = prefs.getInt('pdg_app_token_expiry');
      
      if (_token != null && expiryTimestamp != null) {
        // Backward compat:
        // - prima salvavamo l'expiry in secondi (timestamp Unix)
        // - ora lo salviamo in millisecondi
        final expiryMs = expiryTimestamp < 1000000000000 ? (expiryTimestamp * 1000) : expiryTimestamp;
        _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(expiryMs);
        debugPrint('✅ Token caricato dalle SharedPreferences, scade il: $_tokenExpiry');
      } else {
        debugPrint('⚠️ Token non trovato nelle SharedPreferences');
        _token = null;
        _tokenExpiry = null;
      }
    } catch (e) {
      debugPrint('❌ Errore nel caricamento del token: $e');
      _token = null;
      _tokenExpiry = null;
    }
  }

  /// Autentica l'utente e ottiene il token
  Future<bool> login(String username, String password) async {
    try {
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('🔐 INIZIO LOGIN');
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('📧 Username: $username');
      debugPrint('🔑 Password: ${password.replaceAll(RegExp(r'.'), '*')} (${password.length} char)');
      debugPrint('🌐 Endpoint: $apiBaseUrl/auth');
      debugPrint('🔐 API Key: ${apiKey.substring(0, 10)}...${apiKey.substring(apiKey.length - 10)}');

      final response = await http.post(
        Uri.parse('$apiBaseUrl/auth'),
        headers: {
          apiKeyHeaderName: apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 15));

      debugPrint('───────────────────────────────────────────────────');
      debugPrint('📡 RISPOSTA RICEVUTA');
      debugPrint('───────────────────────────────────────────────────');
      debugPrint('📊 HTTP Status Code: ${response.statusCode}');
      debugPrint('📏 Content-Length: ${response.body.length} bytes');
      debugPrint('📝 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        debugPrint('───────────────────────────────────────────────────');
        debugPrint('✅ PARSING RISPOSTA');
        debugPrint('───────────────────────────────────────────────────');
        debugPrint('🎯 success: ${data['success']}');
        debugPrint('👤 user.id: ${data['user']?['id']}');
        debugPrint('👤 user.username: ${data['user']?['username']}');
        debugPrint('👤 user.display_name: ${data['user']?['display_name']}');
        debugPrint('🔐 token: ${data['token']?.substring(0, 20)}...${data['token']?.substring(data['token'].length - 10) ?? ''}');
        debugPrint('⏰ expiry (timestamp): ${data['expiry']}');
        
        if (data['success'] == true && data['token'] != null) {
          _token = data['token'];
          final int expirySeconds = (data['expiry'] as num).toInt();
          final int expiryMs = expirySeconds * 1000;
          _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(expiryMs);
          
          debugPrint('───────────────────────────────────────────────────');
          debugPrint('💾 SALVATAGGIO TOKEN');
          debugPrint('───────────────────────────────────────────────────');
          debugPrint('🔐 Token salvato: ${_token!.substring(0, 20)}...');
          debugPrint('⏰ Scadenza: $_tokenExpiry');
          debugPrint('⏱️ Giorni rimanenti: ${_tokenExpiry!.difference(DateTime.now()).inDays}');
          
          // Salva nelle SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          // 🧹 Pulisci cache locale ad ogni nuovo login riuscito
          await _clearCachesOnNewLogin(prefs);
          await prefs.setString('pdg_app_token', _token!);
          await prefs.setInt('pdg_app_token_expiry', expiryMs);
          
          debugPrint('───────────────────────────────────────────────────');
          debugPrint('✅ LOGIN COMPLETATO CON SUCCESSO!');
          debugPrint('═══════════════════════════════════════════════════');
          return true;
        } else {
          debugPrint('⚠️ Risposta ok ma success=false oppure token mancante');
          debugPrint('success: ${data['success']}');
          debugPrint('token: ${data['token']}');
        }
      } else if (response.statusCode == 401) {
        debugPrint('───────────────────────────────────────────────────');
        debugPrint('❌ ERRORE 401: CREDENZIALI NON VALIDE');
        debugPrint('───────────────────────────────────────────────────');
        debugPrint('Username o password errati');
        debugPrint('Response: ${response.body}');
      } else if (response.statusCode == 403) {
        debugPrint('───────────────────────────────────────────────────');
        debugPrint('❌ ERRORE 403: ACCESSO NEGATO');
        debugPrint('───────────────────────────────────────────────────');
        debugPrint('Verifica API Key in wp-config.php');
        debugPrint('Response: ${response.body}');
      } else if (response.statusCode == 429) {
        debugPrint('───────────────────────────────────────────────────');
        debugPrint('❌ ERRORE 429: TROPPI TENTATIVI');
        debugPrint('───────────────────────────────────────────────────');
        debugPrint('Troppi login falliti dall\'IP');
        debugPrint('Aspetta 15 minuti');
        debugPrint('Response: ${response.body}');
      } else {
        debugPrint('───────────────────────────────────────────────────');
        debugPrint('❌ ERRORE ${response.statusCode}');
        debugPrint('───────────────────────────────────────────────────');
        debugPrint('Corpo risposta: ${response.body}');
      }
      
      debugPrint('═══════════════════════════════════════════════════');
      return false;
    } catch (e) {
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('❌ ECCEZIONE DURANTE LOGIN');
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('Errore: $e');
      debugPrint('═══════════════════════════════════════════════════');
      return false;
    }
  }

  /// Effettua una richiesta GET autenticata
  Future<http.Response> get(String endpoint, {Map<String, String>? queryParams}) async {
    if (!isAuthenticated) {
      throw Exception('Token non valido o scaduto');
    }

    final uri = Uri.parse('$apiBaseUrl$endpoint');
    final uriWithParams = queryParams != null ? uri.replace(queryParameters: queryParams) : uri;

    return http.get(
      uriWithParams,
      headers: _getAuthHeaders(),
    ).timeout(const Duration(seconds: 30));
  }

  /// Effettua una richiesta POST autenticata
  Future<http.Response> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    if (!isAuthenticated) {
      throw Exception('Token non valido o scaduto');
    }

    final uri = Uri.parse('$apiBaseUrl$endpoint');
    final uriWithParams = queryParams != null ? uri.replace(queryParameters: queryParams) : uri;

    return http.post(
      uriWithParams,
      headers: _getAuthHeaders(),
      body: body != null ? jsonEncode(body) : null,
    ).timeout(const Duration(seconds: 30));
  }

  /// Pulisce cache persistenti + cache immagini in memoria ad ogni nuovo login.
  /// NON cancella credenziali/setting: rimuove solo chiavi legate a "cache".
  Future<void> _clearCachesOnNewLogin(SharedPreferences prefs) async {
    try {
      // In-memory image cache (utile se cambiano utenti/contenuti)
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      // Cache persistenti (es. in main.dart: cached_posts, cache_timestamp, notified_urgent_posts)
      final keys = prefs.getKeys().toList();
      for (final k in keys) {
        final lower = k.toLowerCase();
        final isCacheKey =
            lower.contains('cache') || lower.startsWith('cached_') || lower.startsWith('notified_');
        if (isCacheKey) {
          await prefs.remove(k);
        }
      }

      debugPrint('🧹 Cache pulita (SharedPreferences + image cache) per nuovo login');
    } catch (e) {
      debugPrint('❌ Errore pulizia cache nuovo login: $e');
    }
  }

  /// Ritorna gli header di autenticazione
  Map<String, String> _getAuthHeaders() {
    return {
      apiKeyHeaderName: apiKey,
      'Authorization': 'Bearer $_token',
      // Fallback per hosting che non inoltrano l'header Authorization
      'x-pdg-token': '$_token',
      'Content-Type': 'application/json',
    };
  }

  /// Ricarica il token se scaduto (utile per logout)
  Future<void> logout() async {
    _token = null;
    _tokenExpiry = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pdg_app_token');
    await prefs.remove('pdg_app_token_expiry');
    
    debugPrint('🔓 Logout completato');
  }

  /// Ottiene i post leggibili per l'utente autenticato
  Future<List<Map<String, dynamic>>> fetchPosts({
    int page = 1,
    int perPage = 60,
    String orderBy = 'date',
    String order = 'DESC',
    int? category,
  }) async {
    try {
      debugPrint('───────────────────────────────────────────────────');
      debugPrint('📥 CARICAMENTO POST');
      debugPrint('───────────────────────────────────────────────────');
      debugPrint('📄 Pagina: $page');
      debugPrint('📊 Per pagina: $perPage');
      debugPrint('🔤 Ordina per: $orderBy ($order)');
      if (category != null) debugPrint('📁 Categoria: $category');

      final queryParams = {
        'page': page.toString(),
        'per_page': perPage.toString(),
        'orderby': orderBy,
        'order': order,
      };

      if (category != null) {
        queryParams['category'] = category.toString();
      }

      final response = await get('/posts', queryParams: queryParams);

      debugPrint('📡 Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final posts = (data['posts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        
        debugPrint('───────────────────────────────────────────────────');
        debugPrint('✅ SUCCESSO');
        debugPrint('───────────────────────────────────────────────────');
        debugPrint('📦 Post caricati: ${posts.length}');
        debugPrint('📄 Pagina attuale: ${data['current_page']}');
        debugPrint('📝 Nota: ${data['note']}');
        
        if (posts.isNotEmpty) {
          debugPrint('───────────────────────────────────────────────────');
          debugPrint('📋 DETTAGLI POST');
          debugPrint('───────────────────────────────────────────────────');
          for (int i = 0; i < (posts.length > 3 ? 3 : posts.length); i++) {
            final post = posts[i];
            final title = post['title']['rendered'] as String? ?? 'Senza titolo';
            final titlePreview = title.length > 50 ? title.substring(0, 50) : title;
            debugPrint('Post ${i + 1}:');
            debugPrint('  ID: ${post['id']}');
            debugPrint('  Titolo: $titlePreview${title.length > 50 ? '...' : ''}');
            debugPrint('  Data: ${post['date']}');
            debugPrint('  Status: ${post['status']}');
          }
          if (posts.length > 3) {
            debugPrint('... e altri ${posts.length - 3} post');
          }
        }
        
        return posts;
      }

      debugPrint('───────────────────────────────────────────────────');
      debugPrint('❌ ERRORE ${response.statusCode}');
      debugPrint('───────────────────────────────────────────────────');
      debugPrint('Response: ${response.body}');
      return [];
    } catch (e) {
      debugPrint('───────────────────────────────────────────────────');
      debugPrint('❌ ECCEZIONE');
      debugPrint('───────────────────────────────────────────────────');
      debugPrint('Errore: $e');
      return [];
    }
  }

  /// Ottiene un singolo post
  Future<Map<String, dynamic>?> fetchPost(int postId) async {
    try {
      final response = await get('/posts/$postId');

      if (response.statusCode == 200) {
        final post = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('✅ Post $postId caricato');
        return post;
      }

      debugPrint('❌ Errore nel caricamento del post $postId: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('❌ Errore durante la richiesta del post $postId: $e');
      return null;
    }
  }

  /// Ottiene le categorie leggibili per l'utente autenticato
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    try {
      final response = await get('/categories');

      if (response.statusCode == 200) {
        final categories = (jsonDecode(response.body) as List?)?.cast<Map<String, dynamic>>() ?? [];
        debugPrint('✅ Caricate ${categories.length} categorie');
        return categories;
      }

      debugPrint('❌ Errore nel caricamento delle categorie: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('❌ Errore durante la richiesta delle categorie: $e');
      return [];
    }
  }

  /// 🔥 Ottiene le informazioni dell'utente e i suoi ruoli
  Future<Map<String, dynamic>?> fetchUserPermissions() async {
    try {
      final response = await get('/debug/permissions');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('✅ Info utente caricate');
        
        // Salva i ruoli nelle SharedPreferences per uso offline
        final roles = (data['user']?['roles'] as List?)?.cast<String>() ?? [];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('user_roles', roles);
        debugPrint('👤 Ruoli utente: $roles');
        
        return data;
      }

      debugPrint('❌ Errore nel caricamento info utente: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('❌ Errore durante la richiesta info utente: $e');
      return null;
    }
  }

  /// 🔥 Ottiene i ruoli dell'utente (da cache o API)
  Future<List<String>> getUserRoles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedRoles = prefs.getStringList('user_roles');
      
      if (cachedRoles != null && cachedRoles.isNotEmpty) {
        debugPrint('👤 Ruoli utente (cache): $cachedRoles');
        return cachedRoles;
      }
      
      // Se non in cache, carica dall'API
      if (isAuthenticated) {
        final permissions = await fetchUserPermissions();
        if (permissions != null) {
          final roles = (permissions['user']?['roles'] as List?)?.cast<String>() ?? [];
          return roles;
        }
      }
      
      return [];
    } catch (e) {
      debugPrint('❌ Errore recupero ruoli utente: $e');
      return [];
    }
  }

  /// 🔥 Verifica se l'utente ha un ruolo specifico
  Future<bool> hasRole(String role) async {
    final roles = await getUserRoles();
    return roles.contains(role);
  }

  /// 🔥 Verifica se l'utente è un proprietario (um_proprietari)
  Future<bool> isProprietario() async {
    return await hasRole('um_proprietari');
  }
}

/// Istanza globale del servizio API
final apiService = ApiService();
