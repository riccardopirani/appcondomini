import 'dart:convert';

import 'package:condominio/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiService.login', () {
    final api = ApiService();

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await api.logout();
    });

    tearDown(() async {
      await api.logout();
    });

    test('success: salva token ed expiry in SharedPreferences', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          '${ApiService.apiBaseUrl}/auth',
        );
        final body =
            jsonDecode(request.body as String) as Map<String, dynamic>;
        expect(body['username'], 'testuser');
        expect(body['password'], 'secret');
        return http.Response(
          jsonEncode({
            'success': true,
            'token': 'jwt-token-ok',
            'expiry': 2524608000,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final ok =
          await api.login('testuser', 'secret', httpClient: mock);
      expect(ok, isTrue);
      expect(api.token, 'jwt-token-ok');
      expect(api.isAuthenticated, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pdg_app_token'), 'jwt-token-ok');
      expect(prefs.getInt('pdg_app_token_expiry'), isNotNull);
      expect(
        prefs.getInt('pdg_app_token_expiry'),
        2524608000 * 1000,
      );
    });

    test('401: non autentica', () async {
      final mock = MockClient(
        (_) async => http.Response('Unauthorized', 401),
      );

      final ok =
          await api.login('u', 'p', httpClient: mock);
      expect(ok, isFalse);
      expect(api.token, isNull);
      expect(api.isAuthenticated, isFalse);
    });

    test('200 ma success false: non autentica', () async {
      final mock = MockClient(
        (_) async => http.Response(
          jsonEncode({'success': false}),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );

      expect(await api.login('u', 'p', httpClient: mock), isFalse);
      expect(api.isAuthenticated, isFalse);
    });
  });
}
