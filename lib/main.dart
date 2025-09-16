import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

String? jwtToken;
String urlSito = 'https://www.new.portobellodigallura.it';

Future<void> regenerateToken() async {
  final prefs = await SharedPreferences.getInstance();
  final username = prefs.getString('username');
  final password = prefs.getString('password');

  if (username != null && password != null) {
    debugPrint('Rigenerazione cookie per: $username');
    try {
      // Effettua nuovo login per ottenere cookie freschi
      final loginResponse = await http.post(
        Uri.parse('$urlSito/wp-login.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body:
            'log=$username&pwd=$password&wp-submit=Log+In&redirect_to=$urlSito/wp-admin/&testcookie=1',
      );

      if (loginResponse.headers['set-cookie'] != null) {
        final cookies = loginResponse.headers['set-cookie']!;
        jwtToken = cookies;
        await prefs.setString('jwtToken', jwtToken!);
        debugPrint('Cookie rigenerati con successo');
      } else {
        debugPrint('Rigenerazione cookie fallita');
        await clearLoginData();
      }
    } catch (e) {
      debugPrint('Errore rigenerazione cookie: $e');
      await clearLoginData();
    }
  } else {
    debugPrint('Credenziali non trovate');
    await clearLoginData();
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

class CategoryPostsScreen extends StatelessWidget {
  final String category;
  final List<dynamic> posts;

  const CategoryPostsScreen({
    super.key,
    required this.category,
    required this.posts,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(category),
        backgroundColor: const Color(0xFFFFC107),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          final title = post['title']['rendered'] ?? '';
          final excerpt = post['excerpt']['rendered'] ?? '';

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
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
              title: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _removeHtmlTags(excerpt),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _removeHtmlTags(String htmlText) {
    final regex = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true);
    return htmlText.replaceAll(regex, '');
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
      // Step 1: Effettua login per ottenere i cookie
      final loginResponse = await http.post(
        Uri.parse('$urlSito/wp-login.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body:
            'log=$username&pwd=$password&wp-submit=Log+In&redirect_to=$urlSito/wp-admin/&testcookie=1',
      );

      debugPrint('Login response status: ${loginResponse.statusCode}');
      debugPrint('Login response headers: ${loginResponse.headers}');

      // Step 2: Verifica se il login è riuscito controllando i cookie
      if (loginResponse.headers['set-cookie'] != null) {
        final cookies = loginResponse.headers['set-cookie']!;
        debugPrint('Login cookies ricevuti: $cookies');

        // Step 3: Verifica il login controllando se siamo reindirizzati
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
    _initializeData();
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
      // Prova prima senza autenticazione per i post pubblici
      final response = await http.get(
        Uri.parse(
          '$urlSito/wp-json/wp/v2/posts?orderby=date&order=desc&_embed=wp:term&per_page=20&status=publish',
        ),
      );

      debugPrint('Status code: ${response.statusCode}');
      debugPrint(
          'URL richiesta: $urlSito/wp-json/wp/v2/posts?orderby=date&order=desc&_embed=wp:term&per_page=20&status=publish');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        debugPrint('Post ricevuti: ${data.length}');

        // Se non ci sono post, usa il fallback
        if (data.isEmpty) {
          debugPrint('Nessun post trovato, uso post di esempio');
          await _fetchPostsAlternative();
          return;
        }

        // Filtra i post per rimuovere quelli con contenuto restrittivo
        final filtered = data.where((post) {
          final title = post['title']['rendered']?.toLowerCase() ?? '';
          final content = post['content']['rendered'] ?? '';
          final excerpt = post['excerpt']['rendered'] ?? '';

          // Escludi post con contenuto restrittivo
          final hasRestrictedTitle =
              title.contains('restricted') || title.contains('privato');
          final hasRestrictedContent =
              content.contains('effettuare il login') ||
                  excerpt.contains('effettuare il login') ||
                  excerpt.contains('devi essere loggato') ||
                  content.trim().isEmpty;

          return !hasRestrictedTitle && !hasRestrictedContent;
        }).toList();

        debugPrint('Post filtrati: ${filtered.length}');

        // Se dopo il filtraggio non ci sono post, usa il fallback
        if (filtered.isEmpty) {
          debugPrint('Nessun post valido dopo filtraggio, uso post di esempio');
          await _fetchPostsAlternative();
          return;
        }

        if (mounted) {
          setState(() {
            posts = filtered;
          });
        }
      } else {
        debugPrint('Errore HTTP: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');

        // Se fallisce, prova con un endpoint alternativo
        await _fetchPostsAlternative();
      }
    } catch (e) {
      debugPrint('Errore caricamento post: $e');
      // Prova con un metodo alternativo
      await _fetchPostsAlternative();
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
          color: const Color(0xFFE0F7FA), // Azzurro mare
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  color: Color(0xFF0288D1), // Blu mare
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset('assets/logo.png', height: 48),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Porto Bello\ndi Gallura',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.article, color: Colors.black87),
                title: const Text('Identità'),
                onTap: () {
                  Navigator.pop(context);

                  _openInAppBrowser(
                      'https://www.new.portobellodigallura.it/dove-siamo/');
                },
              ),
              ListTile(
                leading: const Icon(Icons.article, color: Colors.black87),
                title: const Text('Numeri utili'),
                onTap: () {
                  Navigator.pop(context);
                  _openInAppBrowser(
                      'https://www.new.portobellodigallura.it/numeri-util/');
                },
              ),
              ListTile(
                leading: const Icon(Icons.article, color: Colors.black87),
                title: const Text('Servizi'),
                onTap: () {
                  Navigator.pop(context);
                  _openInAppBrowser(
                    'https://www.new.portobellodigallura.it/servizi/',
                  );
                },
              ),
              const Divider(color: Color(0xFF0288D1), height: 1),
              ListTile(
                leading: const Icon(Icons.info, color: Colors.black87),
                title: const Text('Informazioni App'),
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
              const Divider(color: Color(0xFF0288D1), height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.black87),
                title: const Text('Logout'),
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
            ],
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
                children: visiblePosts.isNotEmpty
                    ? visiblePosts.map((post) {
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
                                      : Colors.transparent,
                                  width: isUrgente ? 3 : 0,
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
                                          Text(
                                            post['title']['rendered'],
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF01579B),
                                            ),
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
                    : const [NoAccessMessage()],
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
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildButton(context, "Bombole Gas", Icons.local_gas_station),
            const SizedBox(height: 20),
            _buildButton(context, "Rifiuti", Icons.delete),
            const SizedBox(height: 20),
            _buildButton(context, "Guasto", Icons.build),
            const SizedBox(height: 20),
            _buildButton(context, "Porto", Icons.anchor),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context, String label, IconData icon) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0288D1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
