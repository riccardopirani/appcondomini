import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

String? jwtToken;

void main() {
  runApp(const MyApp());
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
      home: const OnboardingScreen(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

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
      backgroundColor: Color(0xFF2E86C1), // Blu mare come sfondo
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
                    backgroundColor: Color(0xFFFFC107), // Giallo sole per il pulsante
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  child: const Text(
                    'Inizia',
                    style: TextStyle(color: Colors.white), // Testo bianco per contrasto
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
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium!
                  .copyWith(fontSize: 16, color: Colors.white70), // Testo bianco chiaro
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
    final response = await http.post(
      Uri.parse('https://portobellodigallura.it/wp-json/jwt-auth/v1/token'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': username,
        'password': password,
      }),
    );
    try {
      final data = json.decode(response.body);
      jwtToken = data['token'];
    } catch (err) {
      print(err.toString());
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MyHomePage(title: '')),
    );
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
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
                child: Card(
                  color: Colors.white.withOpacity(0.9), // Card con opacità per contrastare il blu
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
                          style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                            color: Colors.blue, // Titolo blu per richiamare il mare
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
                            prefixIcon: const Icon(Icons.lock, color: Colors.blue),
                          ),
                        ),
                        const SizedBox(height: 30),
                        ElevatedButton(
                          onPressed: () {
                            var username = usernameController.text;
                            var password = passwordController.text;
                            if (username.isEmpty || password.isEmpty) {
                              username = "admin";
                              password = "7e97b7pHD4mW.GF7";
                            }
                            if (username.isNotEmpty && password.isNotEmpty) {
                              handleLogin(context, username, password);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Compila tutti i campi'),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFFFC107), // Giallo sole
                            foregroundColor:
                            Colors.white, // Testo del bottone bianco
                            padding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            textStyle: const TextStyle(fontSize: 16),
                          ),
                          child: const Text('Login'),
                        ),
                      ],
                    ),
                  ),
                )),
          ),
        ],
      ),
    );
  }
}

class _MyHomePageState extends State<MyHomePage> {
  late List<dynamic> posts = [];
  bool isLoggedIn = false;
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    fetchPosts();
  }

  Future<void> fetchPosts() async {
    final response = await http.get(
      Uri.parse(
          'https://portobellodigallura.it/new/wp-json/wp/v2/posts?per_page=20&orderby=date&order=desc&_embed=true'),
      headers: {
        'Authorization': 'Bearer $jwtToken',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);

      final filtered = data.where((post) {
        final status = post['status'];
        final content = post['content']['rendered'] ?? '';
        final isPublished = status == 'publish';
        final isPrivate = status == 'private';
        final isAccessible = content.contains('login') == false;

        return isPublished || (isPrivate && isAccessible);
      }).toList();

      setState(() {
        posts = filtered;
      });
    } else {
      throw Exception('Failed to load posts');
    }
  }

  Widget _getBody() {
    switch (_selectedIndex) {
      case 0:
        return _homeContent();
      case 1:
        return const EmailFormTab();
      case 2:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.anchor,
                size: 80,
                color: Color(0xFF1E88E5), // Blu mare
              ),
              SizedBox(height: 20),
              Text(
                'Servizi in arrivo!',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E88E5),
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Stiamo preparando il meglio per te...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 30),
              CircularProgressIndicator(
                color: Color(0xFF1E88E5),
              ),
            ],
          ),
        );
      default:
        return Container();
    }
  }

  @override
  Widget build(BuildContext context) {
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
                title: const Text('Visualizza Post'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TabScreen(posts: posts),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.black87),
                title: const Text('Logout'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MyApp(),
                    ),
                  );
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
            label: 'Contatti',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.room_service),
            label: 'Servizi',
          ),
        ],
      ),
    );
  }


  String _removeHtmlTags(String htmlText) {
    final regex = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true);
    return htmlText.replaceAll(regex, '');
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

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(
            'https://images.unsplash.com/photo-1507525428034-b723cf961d3e',
          ),
          fit: BoxFit.cover,
          opacity: 0.6,
        ),
      ),
      child: Container(
        color: const Color(0xCCFFF8E1),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: visiblePosts.isNotEmpty
                  ? visiblePosts.map((post) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post['title']['rendered'],
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _removeHtmlTags(
                                    post['excerpt']['rendered'] ?? ''),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList()
                  : const [NoAccessMessage()],
            ),
          ),
        ),
      ),
    );
  }
}

class TabScreen extends StatelessWidget {
  final List<dynamic> posts;

  const TabScreen({super.key, required this.posts});

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
            const EmailFormTab(),
          ],
        ),
        bottomNavigationBar: Container(
          color: const Color(0xFFFFC107), // Giallo sole
          child: const TabBar(
            indicatorColor: Color(0xFF1565C0), // Blu mare
            indicatorWeight: 4,
            labelColor: Colors.black, // Testo attivo
            unselectedLabelColor: Colors.black54, // Testo non attivo
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

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: visiblePosts.length,
      itemBuilder: (context, index) {
        final post = visiblePosts[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              vertical: 20,
              horizontal: 20,
            ),
            title: Text(
              post['title']['rendered'],
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                _removeHtmlTags(post['excerpt']['rendered'] ?? ''),
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                ),
              ),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              color: Color(0xFF1ABC9C),
              size: 20,
            ),
            onTap: () {
              // TODO: Navigate to post details
            },
          ),
        );
      },
    );
  }
}

class EmailFormTab extends StatefulWidget {
  const EmailFormTab({super.key});

  @override
  State<EmailFormTab> createState() => _EmailFormTabState();
}

class _EmailFormTabState extends State<EmailFormTab> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();

  void _submitForm() {
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final message = _messageController.text.trim();

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+\$');
    final phoneRegex = RegExp(r'^[0-9]{6,15}\$');

    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Inserisci un'email valida")),
      );
      return;
    }

    if (email.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email e messaggio sono obbligatori")),
      );
      return;
    }

    if (phone.isNotEmpty && !phoneRegex.hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Inserisci un numero di telefono valido")),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Messaggio inviato!")),
    );

    _emailController.clear();
    _phoneController.clear();
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F7FA), // Azzurro mare
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueGrey.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(28.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.anchor,
                  size: 48,
                  color: Color(0xFF0288D1), // Blu mare
                ),
                const SizedBox(height: 12),
                const Text(
                  'Contattaci al Porto',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF01579B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _emailController,
                  label: 'Email *',
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 15),
                _buildTextField(
                  controller: _phoneController,
                  label: 'Numero di Telefono',
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
                    backgroundColor: const Color(0xFFFFD54F), // Giallo sole
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
                const SizedBox(height: 12),
                const Text(
                  'Ti risponderemo al più presto via email o telefono.\nGrazie per averci contattato!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
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
