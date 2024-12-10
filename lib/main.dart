import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.grey),
        useMaterial3: true,
        textTheme: TextTheme(
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
      debugShowCheckedModeBanner: false, // Remove debug banner
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
  bool isLoggedIn = true;

  @override
  void initState() {
    super.initState();
    fetchPosts();
  }

  // Function to fetch posts from WordPress API
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
            backgroundColor: Colors.grey,
            elevation: 5,
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Posts'),
                Tab(text: 'Send Email'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              PostTab(posts: posts), // Pass the posts data to PostTab
              EmailFormTab(), // Your EmailFormTab here (kept as is)
            ],
          ),
        ),
      )
          : const LoginScreen(),
    );
  }

  // Handle Login Process (dummy example)
  void handleLogin(String username, String password) {
    if (username == 'user' && password == 'password') {
      setState(() {
        isLoggedIn = true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid credentials')),
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
                  'Login to Condominio App',
                  style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
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
                    //obscureText: true,
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    // Simulate a login action
                    //handleLogin("prov","prova");
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),

                    textStyle: TextStyle(fontSize: 16),
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
        String imageUrl = "https://www.condominio360.it/logo.png"; // Placeholder if no image

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 10,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                // Left column for text content
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
                // Right column for image
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
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Recipient Email',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              prefixIcon: const Icon(Icons.email),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _subjectController,
            decoration: InputDecoration(
              labelText: 'Subject',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              prefixIcon: const Icon(Icons.subject),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _bodyController,
            decoration: InputDecoration(
              labelText: 'Body',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              prefixIcon: const Icon(Icons.message),
            ),
            maxLines: 5,
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              final recipient = _emailController.text;
              final subject = _subjectController.text;
              final body = _bodyController.text;

              if (recipient.isNotEmpty && subject.isNotEmpty && body.isNotEmpty) {
                // Email sending logic (you can use FlutterMailer for this)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Email sent successfully')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill in all fields')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
             // primary: Colors.deepPurple,
              textStyle: TextStyle(fontSize: 16),
            ),
            child: const Text('Send Email'),
          ),
        ],
      ),
    );
  }
}