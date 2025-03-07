import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
      home: const MyHomePage(title: 'Condominio App'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late List<dynamic> posts = [];
  bool isLoggedIn = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> fetchPosts() async {
    final response = await http.get(Uri.parse('https://portobellodigallura.it/new/wp-json/wp/v2/posts'));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      setState(() {
        posts = data;
      });
    } else {
      throw Exception('Failed to load posts');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoggedIn
          ? DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
            backgroundColor: Colors.green,
            elevation: 5,
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Post'),
                Tab(text: 'Contatti'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              PostTab(posts: posts),
              const EmailFormTab(),
            ],
          ),
        ),
      )
          : const LoginScreen(),
    );
  }

  Future<void> handleLogin(String username, String password) async {
    final response = await http.post(
      Uri.parse('https://portobellodigallura.it/new/wp-json/jwt-auth/v1/token'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': username,
        'password': password,
      }),
    );
    setState(() {
      isLoggedIn = true;
    });
    fetchPosts();
    if (response.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Credenziali non valide')),
      );
    }
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final _usernameController = TextEditingController();
    final _passwordController = TextEditingController();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Card(
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Login Condominio App',
                  style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Nome utente',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    prefixIcon: const Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    prefixIcon: const Icon(Icons.lock),
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    final username = _usernameController.text;
                    final password = _passwordController.text;
                    if (username.isNotEmpty && password.isNotEmpty) {
                      final homePageState =
                      context.findAncestorStateOfType<_MyHomePageState>();
                      if (homePageState != null) {
                        homePageState.handleLogin(username, password);
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Compila tutti i campi')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
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
        ),
      ),
    );
  }
}

class PostTab extends StatelessWidget {
  final List<dynamic> posts;
  const PostTab({super.key, required this.posts});

  @override
  Widget build(BuildContext context) {
    return posts.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
      itemCount: posts.length,
      itemBuilder: (context, index) {
        var post = posts[index];
        String title = post['title']['rendered'];
        String excerpt = post['excerpt']['rendered'];
        excerpt = excerpt.replaceAll(RegExp(r'<p>|</p>'), '');
        String imageUrl = "https://www.condominio360.it/logo.png";

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 10,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          excerpt,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.network(
                    imageUrl,
                    height: 150,
                    width: 150,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ),
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
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email del destinatario',
              labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              hintText: 'Inserisci l\'email del destinatario',
              hintStyle: TextStyle(color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: Colors.deepPurpleAccent),
              ),
              prefixIcon: Icon(Icons.email, color: Colors.deepPurpleAccent),
              contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _subjectController,
            decoration: InputDecoration(
              labelText: 'Oggetto',
              labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              hintText: 'Inserisci l\'oggetto della mail',
              hintStyle: TextStyle(color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: Colors.deepPurpleAccent),
              ),
              prefixIcon: Icon(Icons.subject, color: Colors.deepPurpleAccent),
              contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _bodyController,
            decoration: InputDecoration(
              labelText: 'Messaggio',
              labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              hintText: 'Scrivi il corpo del messaggio',
              hintStyle: TextStyle(color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: Colors.deepPurpleAccent),
              ),
              prefixIcon: Icon(Icons.message, color: Colors.deepPurpleAccent),
              contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            ),
            maxLines: 5,
          ),
          const SizedBox(height: 30),
          Center(
            child: ElevatedButton(
              onPressed: () {
                final recipient = _emailController.text;
                final subject = _subjectController.text;
                final body = _bodyController.text;

                if (recipient.isNotEmpty &&
                    subject.isNotEmpty &&
                    body.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Email inviata con successo')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Compila tutti i campi')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                padding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              child: const Text('Invia Email'),
            ),
          ),
        ],
      ),
    );
  }
}