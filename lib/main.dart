import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

String? jwtToken;
String urlSito = 'https://www.new.portobellodigallura.it';
String appPassword = 'oNod nxLF mW9Y vMkv DQrU wKwi';

// Funzione per creare l'autenticazione Basic Auth
String createBasicAuth(String username, String password) {
  final credentials = '$username:$password';
  final encoded = base64Encode(utf8.encode(credentials));
  return 'Basic $encoded';
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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
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
          final title = post['title']['rendered'] ?? '';
          final excerpt = post['excerpt']['rendered'] ?? '';
                  final authorId = post['author'] ?? 0;
                  final status = post['status'] ?? '';
                  final url = post['link'] ?? '';

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: status == 'private'
                            ? Colors.orange.withValues(alpha: 0.5)
                            : Colors.transparent,
                        width: status == 'private' ? 2 : 0,
                      ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
                            ),
                          ),
                          if (status == 'private')
                            const Icon(
                              Icons.lock,
                              color: Colors.orange,
                              size: 16,
                            ),
                        ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                  _removeHtmlTags(excerpt),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
                            const SizedBox(height: 4),
                            Text(
                              'Autore ID: $authorId | Status: $status',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        if (url.isNotEmpty) {
                          _openInAppBrowser(url);
                        }
                      },
            ),
          );
        },
              ),
      ),
    );
  }

  String _removeHtmlTags(String htmlText) {
    final regex = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true);
    return htmlText.replaceAll(regex, '');
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
      appBar: AppBar(
        title: const Text('Webcam Live'),
        backgroundColor: const Color(0xFFFFC107),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.videocam),
              label: const Text('Webcam Porto'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 60),
              ),
              onPressed: () {
                _openInAppBrowser(
                  'https://player.castr.com/live_c8ab600012f411f08aa09953068f9db6',
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.landscape),
              label: const Text('Webcam Panoramica'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 60),
              ),
              onPressed: () {
                _openInAppBrowser(
                  'https://player.castr.com/live_e63170f014a311f0bf78a9d871469680',
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.cloud),
              label: const Text('Stazione Meteo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 60),
              ),
              onPressed: () {
                _openInAppBrowser(
                  'https://stazioni5.soluzionimeteo.it/portobellodigallura/',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2E86C1), // Blu mare come sfondo
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                children: [
                  _buildOnboardingPage(
                    'Benvenuto nell\'app per il condominio!',
                    'Gestisci facilmente tutte le informazioni relative al tuo condominio.',
                    'assets/condominio.jpeg',
                  ),
                  _buildOnboardingPage(
                    'Tieniti aggiornato!',
                    'Visualizza le ultime novità e aggiornamenti riguardanti il tuo condominio.',
                    'assets/2.jpeg',
                  ),
                  _buildOnboardingPage(
                    'Contatta i vicini',
                    'Usa il nostro sistema di messaggistica per restare in contatto con i tuoi vicini.',
                    'assets/3.jpg',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LoginScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor:
                        const Color(0xFFFFC107), // Giallo sole per il pulsante
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  child: const Text(
                    'Inizia',
                    style: TextStyle(
                        color: Colors.white), // Testo bianco per contrasto
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingPage(
      String title, String description, String imagePath) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                imagePath,
                height: 300,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white), // Testo bianco per i titoli
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontSize: 16, color: Colors.white70), // Testo bianco chiaro
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<void> handleLogin(
      BuildContext context, String username, String password) async {
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore di connessione. Riprova.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/2.jpeg"),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                color: Colors.white.withValues(alpha: 0.95),
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset("assets/logo.png", width: 80, height: 80),
                      const SizedBox(height: 16),
                      Text(
                        'Login',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium!
                            .copyWith(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 30),
                      TextField(
                        controller: usernameController,
                        decoration: InputDecoration(
                          labelText: 'Nome utente',
                          labelStyle: const TextStyle(color: Colors.black),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          prefixIcon:
                              const Icon(Icons.person, color: Colors.blue),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: const TextStyle(color: Colors.black),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          prefixIcon:
                              const Icon(Icons.lock, color: Colors.blue),
                        ),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: () {
                          final username = usernameController.text;
                          final password = passwordController.text;
                          if (username.isEmpty || password.isEmpty) {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('Campi mancanti'),
                                  content: const Text(
                                      'Inserisci username e password per effettuare il login.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                );
                              },
                            );
                          } else {
                            handleLogin(context, username, password);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFC107),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                        child: const Text('Login'),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              launchUrl(Uri.parse(
                                  '$urlSito/wp-login.php?action=register'));
                            },
                            child: const Text('Crea nuovo utente'),
                          ),
                          TextButton(
                            onPressed: () {
                              launchUrl(Uri.parse(
                                  '$urlSito/wp-login.php?action=lostpassword'));
                            },
                            child: const Text('Cambio\nPassword'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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

    if (savedToken != null &&
        savedToken.isNotEmpty &&
        isLoggedIn &&
        username != null &&
        password != null) {
      jwtToken = savedToken;

      // Verifica se i cookie contengono una sessione valida
      if (jwtToken!.contains('wordpress_logged_in')) {
        debugPrint('Cookie di sessione valido, utente già loggato');
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
        debugPrint('Cookie di sessione scaduto, riautenticazione automatica');
        // Prova a riautenticare automaticamente
        await _autoReLogin(username, password);
      }
    } else {
      debugPrint('Nessun token salvato, mostra login');
      // Mostra la login
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      }
    }
  }

  Future<void> _autoReLogin(String username, String password) async {
    try {
      debugPrint('Tentativo riautenticazione automatica per: $username');

      // Effettua login automatico
      final loginResponse = await http.post(
        Uri.parse('$urlSito/wp-login.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body:
            'log=$username&pwd=$password&wp-submit=Log+In&redirect_to=$urlSito/wp-admin/&testcookie=1',
      );

      if (loginResponse.headers['set-cookie'] != null) {
        final cookies = loginResponse.headers['set-cookie']!;

        if (cookies.contains('wordpress_logged_in')) {
          // Riautenticazione riuscita
          jwtToken = cookies;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwtToken', jwtToken!);
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
              'Riautenticazione automatica fallita - credenziali non valide');
          await clearLoginData();
          if (context.mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const OnboardingScreen()),
            );
          }
        }
      } else {
        debugPrint(
            'Riautenticazione automatica fallita - nessun cookie ricevuto');
        await clearLoginData();
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const OnboardingScreen()),
          );
        }
      }
    } catch (e) {
      debugPrint('Errore riautenticazione automatica: $e');
      await clearLoginData();
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
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
  bool isLoggedIn = false;
  int _selectedIndex = 0;
  Map<String, dynamic>? userData;
  bool isLoadingUserData = true;
  final Set<int> _notifiedUrgentPostIds = {};
  Timer? _notificationTimer;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void startUrgentNotificationWatcher(
      BuildContext context, List<dynamic> posts) {
    _notificationTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      final urgentPosts = posts.where((post) {
        final isUrgente = _isUrgent(post);
        final id = post['id'];
        return isUrgente && !_notifiedUrgentPostIds.contains(id);
      }).toList();

      if (urgentPosts.isNotEmpty && context.mounted) {
        final latest = urgentPosts.first;
        final id = latest['id'];

        _notifiedUrgentPostIds.add(id); // Segna come notificato

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
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
                child: const Text('Apri'),
              ),
            ],
          ),
        );
      }
    });
  }

  List<dynamic> wpMenuItems = [];
  bool isLoadingMenu = true;

  Future<void> fetchUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('jwtToken');
    final username = prefs.getString('username');

    if (savedToken != null) {
      jwtToken = savedToken;
      isLoggedIn = true;
    }

    // Usa i dati salvati invece di fare una chiamata API
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
    _initializeWithTokenReload();
  }

  Future<void> _initializeWithTokenReload() async {
    debugPrint('=== INIZIALIZZAZIONE CON RICARICA TOKEN ===');

    // Ricarica il token dalle SharedPreferences (utile per hot reload)
    await reloadTokenFromStorage();

    debugPrint(
        'Token dopo ricarica: ${jwtToken != null ? "Presente" : "Mancante"}');
    if (jwtToken != null) {
      debugPrint(
          'Token contiene wordpress_logged_in: ${jwtToken!.contains('wordpress_logged_in')}');
      debugPrint('Token length: ${jwtToken!.length}');
    }

    // Se il token è presente ma non valido, prova a rigenerarlo
    if (jwtToken != null && !jwtToken!.contains('wordpress_logged_in')) {
      debugPrint('Token presente ma non valido, tentativo di rigenerazione...');
      await regenerateToken();

      // Ricarica di nuovo dopo rigenerazione
      await reloadTokenFromStorage();
      debugPrint(
          'Token dopo rigenerazione: ${jwtToken != null ? "Presente" : "Mancante"}');
    }

    await _initializeData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationTimer?.cancel();
    super.dispose();
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
      // Verifica se la sessione è ancora valida
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

      final loginResponse = await http.post(
        Uri.parse('$urlSito/wp-login.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body:
            'log=$username&pwd=$password&wp-submit=Log+In&redirect_to=$urlSito/wp-admin/&testcookie=1',
      );

      if (loginResponse.headers['set-cookie'] != null) {
        final cookies = loginResponse.headers['set-cookie']!;

        if (cookies.contains('wordpress_logged_in')) {
          jwtToken = cookies;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwtToken', jwtToken!);
          await prefs.setBool('isLoggedIn', true);

          debugPrint('Riautenticazione automatica dalla home riuscita');

          // Ricarica i dati con la nuova sessione
          await _initializeData();
        } else {
          debugPrint('Riautenticazione automatica dalla home fallita');
          await clearLoginData();
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const OnboardingScreen()),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Errore riautenticazione automatica dalla home: $e');
    }
  }

  Future<void> _initializeData() async {
    await fetchWpMenu();
    await fetchPosts();
    await fetchUserData();
    if (mounted) {
      startUrgentNotificationWatcher(context, posts);
      startTokenRefreshTimer();
    }
  }

  void startTokenRefreshTimer() {
    // Verifica la validità del token ogni 30 minuti
    Timer.periodic(const Duration(minutes: 30), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (jwtToken != null) {
        // Verifica se i cookie contengono ancora una sessione valida
        if (!jwtToken!.contains('wordpress_logged_in')) {
          debugPrint('Cookie di sessione scaduto, rigenerazione automatica');
          await regenerateToken();
        }
      }
    });
  }

  Future<void> fetchWpMenu() async {
    try {
      // Prepara gli headers con autenticazione se disponibile
      final Map<String, String> headers = {};
      if (jwtToken != null && jwtToken!.isNotEmpty) {
        headers['Cookie'] = jwtToken!;
      }

      final response = await http.get(
        Uri.parse(
          '$urlSito/wp-json/wp-api-menus/v2/menus/1',
        ), // 1 è l'ID del menu primario, cambia se serve
        headers: headers,
      );

      debugPrint('Menu response status: ${response.statusCode}');
      debugPrint('Menu response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          wpMenuItems = data['items'] ?? [];
          isLoadingMenu = false;
        });
        debugPrint(
            'Menu caricato con successo: ${wpMenuItems.length} elementi');
      } else {
        debugPrint('Errore caricamento menu: ${response.statusCode}');
        // Se il plugin wp-api-menus non è installato, usa un menu di default
        setState(() {
          wpMenuItems = [
            {'title': 'Home', 'url': '$urlSito/'},
            {'title': 'Servizi', 'url': '$urlSito/servizi/'},
            {'title': 'Contatti', 'url': '$urlSito/contatti/'},
          ];
          isLoadingMenu = false;
        });
      }
    } catch (e) {
      debugPrint('Errore fetchWpMenu: $e');
      // In caso di errore, usa un menu di default
      setState(() {
        wpMenuItems = [
          {'title': 'Home', 'url': '$urlSito/'},
          {'title': 'Servizi', 'url': '$urlSito/servizi/'},
          {'title': 'Contatti', 'url': '$urlSito/contatti/'},
        ];
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
    } catch (e) {
      debugPrint('Errore caricamento post: $e');
      await _fetchPostsAlternative();
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

  Future<void> _testAdminAjax() async {
    try {
      debugPrint('=== TEST BASIC AUTH ===');
      
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username');
      
      if (username == null) {
        debugPrint('Username non trovato per test Basic Auth');
        return;
      }

      final basicAuth = createBasicAuth(username, appPassword);
      debugPrint('Test Basic Auth per utente: $username');

      // Test endpoint base con Basic Auth
      final response = await http.get(
        Uri.parse('$urlSito/wp-json/wp/v2/posts?per_page=5'),
        headers: {
          'Authorization': basicAuth,
          'Content-Type': 'application/json',
          'User-Agent': 'Flutter App/1.0',
          'Accept': 'application/json',
        },
      );

      debugPrint('Basic Auth test status: ${response.statusCode}');
      debugPrint('Basic Auth test response: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Basic Auth test: SUCCESS - ${data.length} post trovati');
      } else if (response.statusCode == 401) {
        debugPrint('Basic Auth test: FAILED - credenziali non valide');
      } else if (response.statusCode == 403) {
        debugPrint('Basic Auth test: FAILED - permessi insufficienti');
      }

      debugPrint('=== TEST ADMIN-AJAX (fallback) ===');

      if (jwtToken == null || jwtToken!.isEmpty) {
        debugPrint('Nessun token disponibile per test admin-ajax');
        return;
      }

      // Test diversi action di admin-ajax
      final actions = [
        'heartbeat',
        'query_posts',
        'get_posts',
        'wp_ajax_get_posts',
      ];

      for (final action in actions) {
        try {
          debugPrint('Test admin-ajax action: $action');

          final response = await http.post(
            Uri.parse('$urlSito/wp-admin/admin-ajax.php'),
            headers: {
              'Cookie': jwtToken!,
              'Content-Type': 'application/x-www-form-urlencoded',
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              'Referer': '$urlSito/wp-admin/',
            },
            body: 'action=$action',
          );

          debugPrint('Admin-ajax $action status: ${response.statusCode}');
          debugPrint(
              'Admin-ajax $action response: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');

          if (response.statusCode == 200 && response.body.isNotEmpty) {
            debugPrint('Admin-ajax $action: SUCCESS');
          }
        } catch (e) {
          debugPrint('Errore admin-ajax $action: $e');
        }
      }
    } catch (e) {
      debugPrint('Errore test admin-ajax: $e');
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
            ? CategoryPostViewer(posts: posts)
            : const NoAccessMessage();
      case 3:
        return const WebcamScreen();
      default:
        return Container();
    }
  }

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
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.white70,
          size: 16,
        ),
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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Sezioni Utili',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF01579B),
                ),
              ),
            ),
            _buildUsefulSectionItem(
              context,
              'Identità',
              'Dove siamo e chi siamo',
              Icons.location_on,
              () => _openInAppBrowser('https://www.new.portobellodigallura.it/dove-siamo/'),
            ),
            _buildUsefulSectionItem(
              context,
              'Numeri Utili',
              'Contatti e informazioni',
              Icons.phone,
              () => _openInAppBrowser('https://www.new.portobellodigallura.it/numeri-util/'),
            ),
            _buildUsefulSectionItem(
              context,
              'Servizi',
              'Tutti i nostri servizi',
              Icons.room_service,
              () => _openInAppBrowser('https://www.new.portobellodigallura.it/servizi/'),
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
        child: Icon(
          icon,
          color: const Color(0xFF0277BD),
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
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
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.security, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Autenticazione attiva',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
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
            child: const Text('Chiudi'),
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
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingUserData) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    return Scaffold(
      endDrawer: Drawer(
        child: Container(
                decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF1E3C72), // Blu scuro
                Color(0xFF2A5298), // Blu medio
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(
                  children: [
                // Header moderno
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Image.asset('assets/logo.png', height: 60),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Porto Bello di Gallura',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          userData?['name'] ?? 'Utente',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                      ),
                    ),
                  ],
                ),
              ),
                
                // Menu items
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _buildModernMenuItem(
                          context,
                          icon: Icons.link,
                          title: 'Sezioni Utili',
                          subtitle: 'Link e risorse',
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
                          title: 'Contatti',
                          subtitle: 'Contatta il porto',
                          color: const Color(0xFF2196F3),
                onTap: () {
                  Navigator.pop(context);
                            _onItemTapped(1); // Vai alla sezione servizi
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildModernMenuItem(
                          context,
                          icon: Icons.person,
                          title: 'Account',
                          subtitle: 'Gestisci il tuo account',
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
                          title: 'Informazioni App',
                          subtitle: 'Versione e dettagli',
                          color: const Color(0xFFFF9800),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AppInfoScreen(),
                    ),
                  );
                },
              ),
                      ],
                    ),
                  ),
                ),
                
                // Logout button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE91E63), Color(0xFFF06292)],
                      ),
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
                      leading: const Icon(Icons.logout, color: Colors.white, size: 24),
                      title: const Text(
                        'Logout',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                onTap: () async {
                  await clearLoginData();
                  if (context.mounted) {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MyApp(),
                      ),
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
          builder: (context) => AppBar(
            backgroundColor: const Color(0xFFFFC107), // Giallo sole
            elevation: 8,
            automaticallyImplyLeading: false,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Logo a sinistra
                Row(
                  children: [
                    Image.asset(
                      'assets/logo.png',
                      height: 40,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Porto di Gallura',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.contact_mail),
            label: 'Servizi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.room_service),
            label: 'Articoli',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'WebCam',
          ),
        ],
      ),
    );
  }

  String _removeHtmlTags(String htmlText) {
    final regex = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true);
    return htmlText.replaceAll(regex, '');
  }

  bool _isUrgent(dynamic post) {
    final categories = post['_embedded']?['wp:term']?[0];
    if (categories == null) return false;
    return categories.any((c) =>
        (c['name'] as String?)?.toLowerCase().contains('urgenti') ?? false);
  }

  Widget _homeContent() {
    final visiblePosts = posts.where((post) {
      final title = post['title']['rendered']?.toLowerCase() ?? '';
      final content = post['content']['rendered'] ?? '';
      final excerpt = post['excerpt']['rendered'] ?? '';

      final hasRestrictedTitle = title.contains('restricted');
      final hasRestrictedContent = content.contains('effettuare il login') ||
          excerpt.contains('effettuare il login') ||
          excerpt.contains('devi essere loggato') ||
          content.trim().isEmpty;

      return !hasRestrictedTitle && !hasRestrictedContent;
    }).toList();

    // Ordina: prima i post urgenti
    visiblePosts.sort((a, b) {
      bool aUrgent = _isUrgent(a);
      bool bUrgent = _isUrgent(b);
      return bUrgent.toString().compareTo(aUrgent.toString());
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: double.infinity,
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
                            (categories != null && categories.isNotEmpty)
                                ? categories
                                    .map<String>((c) => c['name'] as String)
                                    .join(', ')
                                : 'Senza categoria';

                        final imageUrl = post['_embedded']?['wp:featuredmedia']
                            ?[0]?['source_url'];

                        final isUrgente = _isUrgent(post);
                        final url = post['link']; // Link al post WordPress
                        final title = post['title']['rendered'] ?? 'Post';
                      final authorId = post['author'] ?? 0;
                      final status = post['status'] ?? '';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: GestureDetector(
                            onTap: () {
                              _openInAppBrowser(url);
                            },
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: isUrgente
                                      ? Colors.red
                                    : status == 'private'
                                        ? Colors.orange
                                      : Colors.transparent,
                                width: isUrgente
                                    ? 3
                                    : status == 'private'
                                        ? 2
                                        : 0,
                                ),
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
                                        height: 150,
                                        fit: BoxFit.cover,
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                            post['title']['rendered'],
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF01579B),
                                            ),
                                              ),
                                            ),
                                            if (status == 'private')
                                              const Icon(
                                                Icons.lock,
                                                color: Colors.orange,
                                                size: 20,
                                              ),
                                          ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            "Categorie: $categoryNames",
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF0277BD),
                                          ),
                                        ),
                                        if (authorId > 0)
                                          Text(
                                            "Autore ID: $authorId | Status: $status",
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
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
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList()
                  else
                    const NoAccessMessage(),
                ],
              ),
            ),
          ),
        );
      },
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
    final regex = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true);
    return htmlText.replaceAll(regex, '');
  }

  @override
  Widget build(BuildContext context) {
    final visiblePosts = posts.where((post) {
      final title = post['title']['rendered']?.toLowerCase() ?? '';
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
                                post['title']['rendered'],
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
        title: const Text("Contatta il Porto"),
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
                const Text(
                  'Seleziona il servizio',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF01579B),
                  ),
                ),
                const SizedBox(height: 30),
            _buildButton(context, "Bombole Gas", Icons.local_gas_station),
            _buildButton(context, "Rifiuti", Icons.delete),
            _buildButton(context, "Guasto", Icons.build),
            _buildButton(context, "Porto", Icons.anchor),
                
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
    
    switch (label) {
      case "Bombole Gas":
        primaryColor = const Color(0xFFE91E63); // Rosa vibrante
        secondaryColor = const Color(0xFFF06292);
        break;
      case "Rifiuti":
        primaryColor = const Color(0xFF4CAF50); // Verde natura
        secondaryColor = const Color(0xFF81C784);
        break;
      case "Guasto":
        primaryColor = const Color(0xFFFF5722); // Arancione emergenza
        secondaryColor = const Color(0xFFFF8A65);
        break;
      case "Porto":
        primaryColor = const Color(0xFF2196F3); // Blu oceano
        secondaryColor = const Color(0xFF64B5F6);
        break;
      default:
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

  void _submitForm() {
    final email = _emailController.text.trim();
    final name = _nameController.text.trim();
    final message = _messageController.text.trim();

    if (email.isEmpty || message.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compila tutti i campi obbligatori')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Messaggio inviato!')),
    );

    _phoneController.clear();
    _messageController.clear();
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
                const Text(
                  'Invia un messaggio',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF01579B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _nameController,
                  label: 'Nome *',
                  icon: Icons.person,
                ),
                const SizedBox(height: 15),
                _buildTextField(
                  controller: _emailController,
                  label: 'Email *',
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 15),
                _buildTextField(
                  controller: _phoneController,
                  label: 'Telefono',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 15),
                _buildTextField(
                  controller: _messageController,
                  label: 'Messaggio *',
                  icon: Icons.message,
                  maxLines: 4,
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  icon: const Icon(Icons.send, color: Colors.white),
                  label: const Text('Invia'),
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
