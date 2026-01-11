import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

/// Servizio di debug per controllare lo stato del plugin API
class DebugApiService {
  static const String debugEndpoint = '${ApiService.apiBaseUrl}/debug';

  /// Test il plugin API e ritorna informazioni di debug
  static Future<Map<String, dynamic>?> testPluginAPI() async {
    try {
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('🔍 INIZIO TEST PLUGIN API');
      debugPrint('═══════════════════════════════════════════════════');
      
      final apiService = ApiService();
      final token = apiService.token;
      
      debugPrint('📋 Informazioni:');
      debugPrint('  Endpoint: $debugEndpoint');
      debugPrint('  Token disponibile: ${token != null}');
      debugPrint('  Token valido: ${apiService.isAuthenticated}');
      
      if (!apiService.isAuthenticated) {
        debugPrint('❌ ERRORE: Token non valido o scaduto');
        debugPrint('═══════════════════════════════════════════════════');
        return null;
      }

      final response = await http.get(
        Uri.parse(debugEndpoint),
        headers: {
          ApiService.apiKeyHeaderName: ApiService.apiKey,
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('───────────────────────────────────────────────────');
      debugPrint('📡 RISPOSTA RICEVUTA');
      debugPrint('───────────────────────────────────────────────────');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        debugPrint('───────────────────────────────────────────────────');
        debugPrint('✅ PARSING RISPOSTA');
        debugPrint('───────────────────────────────────────────────────');
        
        // User info
        final user = data['user'] as Map<String, dynamic>?;
        if (user != null) {
          debugPrint('👤 Utente:');
          debugPrint('  ID: ${user['id']}');
          debugPrint('  Login: ${user['login']}');
          debugPrint('  Nome: ${user['display_name']}');
          debugPrint('  Ruoli: ${user['roles']}');
        }
        
        // Posts info
        debugPrint('📰 Post:');
        debugPrint('  Totali trovati: ${data['posts_found']}');
        debugPrint('  Leggibili: ${data['readable_posts_count']}');
        debugPrint('  Percentuale leggibilità: ${(data['readable_posts_count'] as int) > 0 ? (((data['readable_posts_count'] as int) / (data['posts_found'] as int) * 100).toStringAsFixed(1)) : '0'}%');
        
        // Sample posts
        final samplePosts = data['sample_posts'] as List<dynamic>? ?? [];
        if (samplePosts.isNotEmpty) {
          debugPrint('───────────────────────────────────────────────────');
          debugPrint('📋 CAMPIONE POST (primi ${samplePosts.length}):');
          debugPrint('───────────────────────────────────────────────────');
          
          for (int i = 0; i < samplePosts.length; i++) {
            final post = samplePosts[i] as Map<String, dynamic>;
            final readable = post['user_can_read'] as bool? ?? false;
            debugPrint('${i + 1}. "${post['title']}" (ID: ${post['id']}, Status: ${post['status']})');
            debugPrint('   Leggibile: ${readable ? '✅ SÌ' : '❌ NO'}');
          }
        } else {
          debugPrint('⚠️ Nessun post trovato nel database');
        }
        
        debugPrint('───────────────────────────────────────────────────');
        debugPrint('✅ TEST COMPLETATO CON SUCCESSO');
        debugPrint('═══════════════════════════════════════════════════');
        
        return data;
      } else {
        debugPrint('───────────────────────────────────────────────────');
        debugPrint('❌ ERRORE ${response.statusCode}');
        debugPrint('───────────────────────────────────────────────────');
        debugPrint('Risposta: ${response.body}');
        debugPrint('═══════════════════════════════════════════════════');
        return null;
      }
    } catch (e) {
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('❌ ECCEZIONE DURANTE TEST');
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('Errore: $e');
      debugPrint('═══════════════════════════════════════════════════');
      return null;
    }
  }

  /// Analizza il risultato del test e fornisce consigli
  static void analyzeTestResults(Map<String, dynamic>? results) {
    if (results == null) {
      debugPrint('❌ Test fallito - impossibile connettere al plugin');
      debugPrint('🔧 Controlla:');
      debugPrint('  1. Il plugin sia installato e attivato');
      debugPrint('  2. La API Key sia corretta in wp-config.php');
      debugPrint('  3. Il token JWT sia valido');
      return;
    }

    final status = results['status'] as String?;
    final postsFound = results['posts_found'] as int? ?? 0;
    final readable = results['readable_posts_count'] as int? ?? 0;

    debugPrint('═══════════════════════════════════════════════════');
    debugPrint('📊 ANALISI RISULTATI');
    debugPrint('═══════════════════════════════════════════════════');

    if (status != 'ok') {
      debugPrint('❌ Plugin API non risponde correttamente');
      return;
    }

    if (postsFound == 0) {
      debugPrint('⚠️ ATTENZIONE: Nessun post trovato nel database');
      debugPrint('🔧 Azioni consigliate:');
      debugPrint('  1. Accedi a WordPress admin');
      debugPrint('  2. Crea almeno un post di test');
      debugPrint('  3. Pubblica il post');
      debugPrint('  4. Riprova il test');
      return;
    }

    if (readable == 0) {
      debugPrint('⚠️ ATTENZIONE: L\'utente NON può leggere nessun post');
      debugPrint('🔧 Azioni consigliate:');
      debugPrint('  1. Accedi a WordPress admin');
      debugPrint('  2. Vai a Users → PdGadmin');
      debugPrint('  3. Verifica i permessi PublishPress');
      debugPrint('  4. Assicurati che l\'utente abbia accesso alle categorie');
      debugPrint('  5. Controlla che i post siano in categorie assegnate all\'utente');
      return;
    }

    final readablePercentage = (readable / postsFound * 100).toStringAsFixed(1);
    debugPrint('✅ SUCCESSO: Utente può leggere $readable/$postsFound post ($readablePercentage%)');
    debugPrint('═══════════════════════════════════════════════════');
  }
}
