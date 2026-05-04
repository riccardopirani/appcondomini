import 'package:condominio/app_theme.dart';
import 'package:condominio/setttings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSettings URL', () {
    test('base del sito è HTTPS portobellodigallura', () {
      expect(
        appSettings.urlSito,
        'https://www.portobellodigallura.it',
      );
      expect(appSettings.urlHome, startsWith('https://'));
      expect(appSettings.urlPosts, contains('/wp-json/wp/v2/posts'));
    });

    test('endpoint ritiro rifiuti incluso nel dominio ufficiale', () {
      expect(
        appSettings.urlRitiroRifiutiEndpoint,
        contains('pdg-app/v1/waste-pickup-request'),
      );
    });
  });

  group('AppTheme', () {
    test('usa Material 3 e colori di brand', () {
      final theme = AppTheme.theme;
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.primary.value, AppColors.primary.value);
      expect(theme.appBarTheme.backgroundColor, AppColors.secondary);
    });

    testWidgets('Si applica a MaterialApp senza errori', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: const Scaffold(body: Text('x')),
        ),
      );
      expect(find.text('x'), findsOneWidget);
    });
  });
}
