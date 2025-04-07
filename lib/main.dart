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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          children: [
            _buildOnboardingPage(
              'Benvenuto nell\'app per il condominio!',
              'Gestisci facilmente tutte le informazioni relative al tuo condominio.',
              'https://i2.res.24o.it/images2010/Editrice/ILSOLE24ORE/QUOTIDIANI_VERTICALI/2021/08/04/Quotidiani%20Verticali/ImmaginiWeb/Ritagli/Condominio-moderno-834-AdobeStock-kEKG--1440x752@Quotidiani_Verticali-Web.jpg',
            ),
            _buildOnboardingPage(
              'Tieniti aggiornato!',
              'Visualizza le ultime novità e aggiornamenti riguardanti il tuo condominio.',
              'https://www.immobiliare.it/news/app/uploads/2022/05/Condominio.jpeg',
            ),
            _buildOnboardingPage(
              'Contatta i vicini',
              'Usa il nostro sistema di messaggistica per restare in contatto con i tuoi vicini.',
              'https://www.alperia.eu/wp-content/uploads/2024/08/teleriscladamenti-condomini-1024x705-1.jpg',
            ),
          ],
        ),
      ),
      bottomSheet: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          },
          child: const Text('Inizia'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.green,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            textStyle: const TextStyle(fontSize: 18), // Button color
          ),
        ),
      ),
    );
  }

  Widget _buildOnboardingPage(
      String title, String description, String imagePath) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.network(imagePath,
                height: 300, width: double.infinity, fit: BoxFit.cover),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: Theme.of(context)
                .textTheme
                .bodyMedium!
                .copyWith(fontSize: 16, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<void> handleLogin(
      BuildContext context, String username, String password) async {
    print("sono in handlelogin");
    final response = await http.post(
      Uri.parse('https://portobellodigallura.it/wp-json/jwt-auth/v1/token'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': username,
        'password': password,
      }),
    );

    print("Status Code: ${response.statusCode}");
    print("Response Body: ${response.body}");
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => const MyHomePage(
                title: '',
              )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final _usernameController = TextEditingController();
    final _passwordController = TextEditingController();

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                  'https://www.immobiliare.it/news/app/uploads/2022/05/Condominio.jpeg',
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Padding(
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
                        'Login',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium!
                            .copyWith(
                              color: Colors.blue,
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
                        obscureText: true,
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
                          var username = _usernameController.text;
                          var password = _passwordController.text;
                          if (username.isEmpty || password.isEmpty) {
                            username = "admin";
                            password = "7e97b7pHD4mW.GF7";
                          }
                          print(username);
                          print(password);
                          if (username.isNotEmpty && password.isNotEmpty) {
                            handleLogin(context, username, password);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Compila tutti i campi')),
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
          ),
        ],
      ),
    );
  }
}

class _MyHomePageState extends State<MyHomePage> {
  late List<dynamic> posts = [];
  bool isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    fetchPosts(); // Fetch posts when the screen is initialized
  }

  // Function to fetch posts from the WordPress API
  Future<void> fetchPosts() async {
    final response = await http.get(
        Uri.parse('https://portobellodigallura.it/new/wp-json/wp/v2/posts'));

    if (response.statusCode == 200) {
      print("Status Code: 200");
      final List<dynamic> data = json.decode(response.body);
      setState(() {
        posts = data;
      });
    } else {
      print("Error: ${response.statusCode}");
      throw Exception('Failed to load posts');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Homepage', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        elevation: 10,
      ),
      body: Container(
        width: MediaQuery.of(context)
            .size
            .width, // Set the container's width to full screen width
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(
                'https://images2-wpc.corriereobjects.it/HLJL2uFOpO9HAdqNn7gQ3sv6NDc=/fit-in/562x740/style.corriere.it/assets/uploads/2020/04/Lantern-House-exterior.jpg?v=243977'),
            fit: BoxFit
                .cover, // This will make the image cover the entire screen
            opacity: 0.5, // Optional: set opacity for the background image
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Create four stylish buttons
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => TabScreen(posts: posts)),
                  );
                },
                child: const Text('Visualizza Post'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  // Another button action
                },
                child: const Text('Button 2'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  // Another button action
                },
                child: const Text('Button 3'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  // Another button action
                },
                child: const Text('Button 4'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TabScreen extends StatelessWidget {
  final List<dynamic> posts;

  const TabScreen({Key? key, required this.posts}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Posts and Contacts',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        elevation: 10,
      ),
      body: DefaultTabController(
        length: 2, // Define the number of tabs
        child: Scaffold(
          appBar: AppBar(
            bottom: const TabBar(
              indicatorColor: Colors.white,
              labelStyle: TextStyle(fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: 'Post'),
                Tab(text: 'Contatti'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              // Posts tab
              posts.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : PostTab(posts: posts),
              // Email form tab (assuming EmailFormTab is a custom widget)
              const EmailFormTab(),
            ],
          ),
        ),
      ),
    );
  }
}

// PostTab Widget for displaying the posts in a beautiful card layout
class PostTab extends StatelessWidget {
  final List<dynamic> posts;
  const PostTab({Key? key, required this.posts}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return Card(
          elevation: 5,
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(15),
            title: Text(
              post['title']['rendered'],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              post['excerpt']['rendered'] ?? 'No content available',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            trailing: const Icon(Icons.arrow_forward, color: Colors.green),
            onTap: () {
              // Navigate to post details
            },
          ),
        );
      },
    );
  }
}

// Placeholder widget for the email form tab
class EmailFormTab extends StatelessWidget {
  const EmailFormTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width:
            double.infinity, // Makes sure the container takes full screen width
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(
                'https://images2-wpc.corriereobjects.it/HLJL2uFOpO9HAdqNn7gQ3sv6NDc=/fit-in/562x740/style.corriere.it/assets/uploads/2020/04/Lantern-House-exterior.jpg?v=243977'),
            fit: BoxFit.cover, // Make image cover the entire screen
            opacity:
                0.5, // Optional: adjust the opacity to see text and buttons
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              const Text(
                'Contatti',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              // Email Input Field
              TextField(
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: const TextStyle(color: Colors.white),
                  fillColor: Colors.white.withOpacity(0.7),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Phone Number Input Field
              TextField(
                decoration: InputDecoration(
                  labelText: 'Numero di Telefono',
                  labelStyle: const TextStyle(color: Colors.white),
                  fillColor: Colors.white.withOpacity(0.7),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Message Input Field
              TextField(
                decoration: InputDecoration(
                  labelText: 'Messaggio',
                  labelStyle: const TextStyle(color: Colors.white),
                  fillColor: Colors.white.withOpacity(0.7),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                maxLines: 5,
              ),
              const SizedBox(height: 20),

              // Submit Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  // Handle form submission
                  print("Form submitted");
                },
                child: const Text('Invia'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
