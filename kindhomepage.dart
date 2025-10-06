import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:share_plus/share_plus.dart';

// Import local pages
import 'journalPage.dart';
import 'kindactpage.dart';
import 'ProfillePage.dart';

// Import Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore

// Import Local Notifications
import 'package:flutter_local_notifications/flutter_local_notifications.dart';


// --- FCM & Local Notifications Setup ---

// 1. Define the Local Notifications plugin instance
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

// 2. Define the Android Notification Channel (required for Android 8.0+)
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel', // id
  'High Importance Notifications', // title
  description: 'This channel is used for important notifications.', // description
  importance: Importance.max,
);

// 3. Define the background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
}


Future<void> main() async {
  // Ensure Flutter engine is initialized
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase Core
  await Firebase.initializeApp();
  // Set the background messaging handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // --- Initialize Local Notifications ---
  // Create the notification channel on Android
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // Initialize the plugin for both Android and iOS
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  // --- End Local Notifications Initialization ---

  runApp(const KindApp());
}

class KindApp extends StatelessWidget {
  const KindApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kind',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        textTheme: GoogleFonts.poppinsTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFF7F7FA),
      ),
      debugShowCheckedModeBanner: false,
      home: const RootPage(),
    );
  }
}

class RootPage extends StatelessWidget {
  const RootPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          if (snapshot.hasData) {
            return const MainPage();
          }
          return const LoginPage();
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}

class LoginPage extends StatelessWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFD6BCFA), Color(0xFF9B6DC8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'KIND',
                    style: GoogleFonts.poppins(
                      fontSize: 60,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 8,
                    ),
                  ),
                  Text(
                    'HUGS SWEETIE!',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.8),
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () => _showRegisterSheet(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        textStyle: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Register',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () => _showHopInSheet(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(color: Colors.black),
                        ),
                        textStyle: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Hop In',
                          style: TextStyle(color: Colors.black)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showHopInSheet(BuildContext context) {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passController = TextEditingController();
    bool _obscurePass = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateSB) {
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context))),
                TextField(
                    controller: emailController,
                    decoration: const InputDecoration(hintText: 'Email')),
                const SizedBox(height: 12),
                TextField(
                  controller: passController,
                  obscureText: _obscurePass,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePass
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setStateSB(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await FirebaseAuth.instance.signInWithEmailAndPassword(
                          email: emailController.text.trim(),
                          password: passController.text.trim(),
                        );
                        if (context.mounted) Navigator.pop(context);
                      } on FirebaseAuthException catch (e) {
                        if (e.code == 'user-not-found' ||
                            e.code == 'wrong-password' ||
                            e.code == 'invalid-credential') {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                  Text('Incorrect email or password.')));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: ${e.message}')));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20))),
                    child: const Text('Hop In',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  void _showRegisterSheet(BuildContext context, {String prefillEmail = ''}) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController emailController =
    TextEditingController(text: prefillEmail);
    final TextEditingController passController = TextEditingController();
    bool _obscurePass = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateSB) {
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context))),
                TextField(
                    controller: nameController,
                    decoration: const InputDecoration(hintText: 'Name')),
                const SizedBox(height: 12),
                TextField(
                    controller: emailController,
                    decoration: const InputDecoration(hintText: 'Email')),
                const SizedBox(height: 12),
                TextField(
                  controller: passController,
                  obscureText: _obscurePass,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePass
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setStateSB(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Please enter your name.')));
                        return;
                      }
                      try {
                        final userCredential = await FirebaseAuth.instance
                            .createUserWithEmailAndPassword(
                          email: emailController.text.trim(),
                          password: passController.text.trim(),
                        );
                        await userCredential.user
                            ?.updateDisplayName(nameController.text.trim());
                        if (context.mounted) Navigator.pop(context);
                      } on FirebaseAuthException catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: ${e.message}')));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20))),
                    child: const Text('Register',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  final GlobalKey<_HomePageState> _homeKey = GlobalKey<_HomePageState>();
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _initializeFirebaseMessaging(); // Call FCM setup
    _pages = [
      HomePage(key: _homeKey),
      const JournalPage(),
      const KindActPage(),
      const ProfilePage(),
    ];
  }

  // --- FCM Setup Method ---
  void _initializeFirebaseMessaging() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // 1. Request Permission (iOS + Android 13+)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ User granted permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('User granted provisional permission');
    } else {
      print('❌ User declined or has not accepted permission');
    }

    // 2. Get the FCM Token
    final fcmToken = await messaging.getToken();
    print('🔑 FCM Token: $fcmToken');

    // 3. Handle Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Foreground Message also contained a notification: ${message.notification}');
        print('Title: ${message.notification!.title}');
        print('Body: ${message.notification!.body}');

        // **** THIS IS THE NEW PART ****
        // Use the local notifications plugin to show the notification
        flutterLocalNotificationsPlugin.show(
          message.hashCode, // A unique ID for the notification
          message.notification!.title,
          message.notification!.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id, // The channel ID we defined earlier
              channel.name, // The channel name
              channelDescription: channel.description,
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher', // default icon
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
        );
      }
    });

    // 4. Handle notification tap when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A new onMessageOpenedApp event was published!');
      // You can navigate to a specific screen based on the message content here.
    });
  }


  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _pages[_selectedIndex],
          if (_selectedIndex == 0)
            Positioned(
              bottom: 120,
              right: 24,
              child: GestureDetector(
                onTap: () {
                  _homeKey.currentState?.showAddOptions();
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(Icons.home_rounded, 'Home', 0),
            _buildNavItem(Icons.book_rounded, 'Journal', 1),
            _buildNavItem(Icons.favorite_rounded, 'Kind', 2),
            _buildNavItem(Icons.person_outline, 'Profile', 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        _onItemTapped(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[400],
              size: 28,
            ),
            if (isSelected) const SizedBox(height: 4),
            if (isSelected)
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? Colors.white : Colors.grey[400],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);
  @override
  State<HomePage> createState() => _HomePageState();
}

class Album {
  String id;
  String name;
  Color color;
  DateTime createdAt;

  Album({
    required this.id,
    required this.name,
    required this.color,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color.value,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Album.fromJson(Map<String, dynamic> json) => Album(
    id: json['id'],
    name: json['name'],
    color: Color(json['color']),
    createdAt: DateTime.parse(json['createdAt']),
  );
}

class _HomePageState extends State<HomePage> {
  bool showMoments = false;
  String _randomGreeting = '';
  String _selectedPetGif = '';
  List<Map<String, dynamic>> momentCards = [];
  List<Map<String, dynamic>> todoCards = [];
  List<Album> albums = [];
  String? selectedAlbumId;
  final ImagePicker _picker = ImagePicker();

  final List<String> _animatedTexts = [ 'Hey You \u{2728}', 'Cutie \u{1F495}', 'Shine On \u{1F31F}', 'Stay Cool \u{2744}\u{FE0F}', 'My Star \u{2B50}', 'Bestie \u{1F917}', 'Be You \u{1F4AB}',  'Stay Rad \u{1F680}', 'Lil Champ \u{1F3C6}', 'Sweetie \u{1F36D}', 'Dear \u{1F496}', 'Bright One \u{1F308}', 'Love Ya \u{2764}\u{FE0F}', 'Hero \u{1F4AA}', 'Angel \u{1F607}', 'Boo \u{1F495}', 'Kind Soul \u{1F54A}\u{FE0F}', 'Buddy \u{1F33B}', 'Rockstar \u{1F3B8}', 'Sunshine \u{2600}\u{FE0F}', 'Pumpkin \u{1F383}', 'Cookie \u{1F36A}', 'Baby \u{1F495}', 'Darlin\' \u{1F338}', 'Honey \u{1F36F}', 'Pookie \u{1F43C}', 'Peach \u{1F351}', 'Dove \u{1F54A}\u{FE0F}', 'Treasure \u{1F48E}', 'Cutiepie \u{1F967}', 'Angel Face \u{1F607}', 'Sweetpea \u{1F33F}', 'Bubbles \u{1FAB8}', 'Jellybean \u{1F36C}', 'Bunny \u{1F407}', 'Cherry \u{1F352}', 'Snuggles \u{1F917}', 'Twinkle \u{2728}', ];
  final List<String> _petGifs = List.generate(18, (index) => 'assets/pet${index + 1}.gif');
  final List<Color> cardColors = [ const Color(0xFFFBD38D), const Color(0xFFFBB6CE), const Color(0xFF9AE6B4), const Color(0xFF90CDF4), const Color(0xFFD6BCFA), const Color(0xFF81E6D9), ];

  // Stream for the banner from Firestore
  late Stream<DocumentSnapshot> _bannerStream;

  @override
  void initState() {
    super.initState();
    _setupFirstTimeUser();
    _randomGreeting = _animatedTexts[Random().nextInt(_animatedTexts.length)];
    _selectedPetGif = _petGifs[Random().nextInt(_petGifs.length)];

    // Initialize the banner stream
    _bannerStream = FirebaseFirestore.instance
        .collection('banners')
        .doc('main_banner')
        .snapshots();
  }

  Future<void> _setupFirstTimeUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool hasSeenWelcomeCard = prefs.getBool('hasSeenWelcomeCard') ?? false;

    await _loadTaskData();

    if (!hasSeenWelcomeCard) {
      final kindTodoChecklist = {
        'title': 'Kind To-Do',
        'isChecklist': true,
        'checklist': [
          {'text': 'Start with gratitude 🌿', 'done': false},
          {'text': 'Work with patience 🌱', 'done': false},
          {'text': 'Listen with heart 💖', 'done': false},
          {'text': 'Help where you can 🌍', 'done': false},
          {'text': 'Rest with love for yourself ✨', 'done': false},
        ],
        'color': cardColors[2].value,
        'isWelcomeCard': true,
      };

      if (mounted) {
        setState(() {
          todoCards.insert(0, kindTodoChecklist);
          _saveData();
        });
      }
      await prefs.setBool('hasSeenWelcomeCard', true);
    }
  }

  Map<String, List<Map<String, dynamic>>> groupMomentsByMonth() {
    Map<String, List<Map<String, dynamic>>> grouped = {};

    List<Map<String, dynamic>> filteredMoments = selectedAlbumId == null
        ? momentCards
        : momentCards.where((m) => m['albumId'] == selectedAlbumId).toList();

    for (var moment in filteredMoments) {
      DateTime date = DateTime.parse(moment['timestamp']);
      String monthKey = DateFormat('MMMM yyyy').format(date);

      if (!grouped.containsKey(monthKey)) {
        grouped[monthKey] = [];
      }
      grouped[monthKey]!.add(moment);
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 55, 20, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text( _randomGreeting, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 28, height: 1.2), ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text( "Try to stay kind today \u{2728}", style: GoogleFonts.poppins(fontSize: 15, color: Colors.black.withOpacity(0.6)), ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 85,
                height: 85,
                child: ClipOval(
                  child: Image.asset(
                    _selectedPetGif,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
        ),

        // --- DYNAMIC BANNER WIDGET ---
        _buildBanner(),

        buildCalendar(),
        buildToggleButtons(),
        if (showMoments && albums.isNotEmpty) buildAlbumSelector(),
        Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 4, bottom: 120),
              children: [
                if (!showMoments)
                  todoCards.isEmpty
                      ? const Center(child: Padding(padding: EdgeInsets.all(40.0), child: Text('No To-Do\'s yet. Tap + to add.')))
                      : Column(
                    children: [
                      ...todoCards.where((card) => card['isWelcomeCard'] == true).toList().asMap().entries.map((entry) {
                        int index = todoCards.indexOf(entry.value);
                        return Column(
                          children: [
                            buildTodoCard(entry.value, index),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                              child: Text(
                                'Every task done in kindness changes more than your day — it changes the world. 🌟',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.black.withOpacity(0.6),
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        );
                      }).toList(),
                      ...todoCards.where((card) => card['isWelcomeCard'] != true).toList().asMap().entries.map((entry) {
                        int adjustedIndex = todoCards.indexOf(entry.value);
                        return buildTodoCard(entry.value, adjustedIndex);
                      }).toList(),
                    ],
                  ),

                if (showMoments)
                  buildMomentsSection(),
              ],
            )
        ),
      ],
    );
  }

  // --- NEW: Method to build the banner from Firestore data ---
  Widget _buildBanner() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _bannerStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show a minimal placeholder while loading to prevent UI jump
          return Container(
            height: 65,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12, left: 20, right: 20),
            color: Colors.grey.shade200,
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          // If no document, show nothing
          return const SizedBox.shrink();
        }

        var bannerData = snapshot.data!.data() as Map<String, dynamic>;
        bool isVisible = bannerData['isVisible'] ?? false;
        String? imageUrl = bannerData['imageUrl'];

        if (isVisible && imageUrl != null) {
          // If banner is visible and has an image, display it
          return GestureDetector(
            onTap: () {
              // Handle banner tap, e.g., open a URL
              // You can add a 'targetUrl' field in Firestore
            },
            child: Container(
              height: 65,
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12, left: 20, right: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  // Optional: Add loading and error builders for a better UX
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(child: Icon(Icons.error));
                  },
                ),
              ),
            ),
          );
        }

        // If not visible or no image, show nothing
        return const SizedBox.shrink();
      },
    );
  }


  Widget buildAlbumSelector() {
    return Container(
      height: 45,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          // All Photos chip
          GestureDetector(
            onTap: () => setState(() => selectedAlbumId = null),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: selectedAlbumId == null ? Colors.black : Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  'All Photos',
                  style: GoogleFonts.poppins(
                    color: selectedAlbumId == null ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          // Album chips
          ...albums.map((album) => GestureDetector(
            onTap: () => setState(() => selectedAlbumId = album.id),
            onLongPress: () => _showAlbumOptions(album),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: selectedAlbumId == album.id ? album.color : album.color.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  album.name,
                  style: GoogleFonts.poppins(
                    color: selectedAlbumId == album.id ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          )).toList(),
          // Add Album button
          GestureDetector(
            onTap: _createAlbum,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[400]!),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Row(
                  children: [
                    Icon(Icons.add, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'New Album',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAlbumOptions(Album album) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              album.name,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Rename Album'),
              onTap: () {
                Navigator.pop(context);
                _renameAlbum(album);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Album'),
              onTap: () {
                Navigator.pop(context);
                _deleteAlbum(album);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _renameAlbum(Album album) {
    final controller = TextEditingController(text: album.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Album'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Album name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  album.name = controller.text.trim();
                  _saveData();
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteAlbum(Album album) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Album?'),
        content: const Text('Photos in this album will not be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                // Move all photos from this album to no album
                for (var moment in momentCards) {
                  if (moment['albumId'] == album.id) {
                    moment['albumId'] = null;
                  }
                }
                albums.remove(album);
                if (selectedAlbumId == album.id) {
                  selectedAlbumId = null;
                }
                _saveData();
              });
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _createAlbum() {
    final nameController = TextEditingController();
    final randomColor = cardColors[Random().nextInt(cardColors.length)];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Create New Album",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'Album name',
                  filled: true,
                  fillColor: const Color(0xFFF8F8FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  if (nameController.text.trim().isNotEmpty) {
                    final newAlbum = Album(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameController.text.trim(),
                      color: randomColor,
                      createdAt: DateTime.now(),
                    );
                    setState(() {
                      albums.add(newAlbum);
                      _saveData();
                    });
                    Navigator.pop(context);
                  }
                },
                child: const Text(
                  'Create Album',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildMomentsSection() {
    final groupedMoments = groupMomentsByMonth();

    if (groupedMoments.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: Text('No Moments yet. Tap + to capture.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groupedMoments.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text(
                entry.key,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: entry.value.length,
              itemBuilder: (ctx, i) => buildMomentThumbnail(entry.value[i]),
            ),
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }

  Widget buildMomentThumbnail(Map<String, dynamic> moment) {
    return GestureDetector(
      onTap: () {
        // Find all moments in the same month for horizontal scrolling
        DateTime momentDate = DateTime.parse(moment['timestamp']);
        String monthKey = DateFormat('MMMM yyyy').format(momentDate);

        List<Map<String, dynamic>> filteredMoments = selectedAlbumId == null
            ? momentCards
            : momentCards.where((m) => m['albumId'] == selectedAlbumId).toList();

        List<Map<String, dynamic>> monthMoments = filteredMoments.where((m) {
          DateTime date = DateTime.parse(m['timestamp']);
          return DateFormat('MMMM yyyy').format(date) == monthKey;
        }).toList();

        int initialIndex = monthMoments.indexOf(moment);
        _showMomentViewer(monthMoments, initialIndex);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[200],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: moment['imagePath'] != null && File(moment['imagePath']).existsSync()
              ? Image.file(
            File(moment['imagePath']),
            fit: BoxFit.cover,
          )
              : Container(
            color: cardColors[momentCards.indexOf(moment) % cardColors.length],
            child: const Icon(Icons.photo_camera, size: 30, color: Colors.white54),
          ),
        ),
      ),
    );
  }

  void _showMomentViewer(List<Map<String, dynamic>> moments, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MomentViewerPage(
          moments: moments,
          initialIndex: initialIndex,
          onDelete: (moment) {
            setState(() {
              if (moment['imagePath'] != null) {
                try {
                  File(moment['imagePath']).deleteSync();
                } catch (e) {
                  print('Error deleting image: $e');
                }
              }
              momentCards.remove(moment);
              _saveData();
            });
          },
          onAlbumChange: (moment, albumId) {
            setState(() {
              moment['albumId'] = albumId;
              _saveData();
            });
          },
          albums: albums,
        ),
      ),
    );
  }

  Widget buildCalendar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 2.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          DateFormat('dd MMM, yyyy').format(DateTime.now()),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 22,
            color: Colors.black.withOpacity(0.7),
          ),
        ),
      ),
    );
  }

  Widget buildToggleButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildToggleItem("To Do's", false),
          const SizedBox(width: 60),
          _buildToggleItem("Moments", true),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String title, bool isMomentsOption) {
    final bool isActive = showMoments == isMomentsOption;
    final textStyle = GoogleFonts.poppins(
      fontSize: 18,
      color: isActive ? Colors.black : Colors.black.withOpacity(0.5),
      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
    );

    return GestureDetector(
      onTap: () {
        setState(() {
          showMoments = isMomentsOption;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              style: textStyle,
              overflow: TextOverflow.visible,
            ),
            const SizedBox(height: 6),
            if (isActive)
              Container(
                height: 2.5,
                width: title == "To Do's" ? 70 : 80,
                color: Colors.black,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> addMoment() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo != null) {
        // Save image to app directory
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String fileName = 'moment_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final String savedPath = path.join(appDir.path, fileName);
        await File(photo.path).copy(savedPath);

        // Get location
        String? locationName;
        try {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }

          if (permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always) {
            Position position = await Geolocator.getCurrentPosition();
            List<Placemark> placemarks = await placemarkFromCoordinates(
              position.latitude,
              position.longitude,
            );
            if (placemarks.isNotEmpty) {
              Placemark place = placemarks[0];
              locationName = '${place.locality}, ${place.country}';
            }
          }
        } catch (e) {
          print('Location error: $e');
        }

        // Show dialog to add tag and description
        if (mounted) {
          _showMomentDetailsDialog(savedPath, locationName);
        }
      }
    } catch (e) {
      print('Error capturing moment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to capture moment')),
        );
      }
    }
  }

  void _showMomentDetailsDialog(String imagePath, String? location) {
    final tagController = TextEditingController();
    final descController = TextEditingController();
    String? selectedAlbumIdForNew;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Capture This Moment",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          // Delete the saved image if user cancels
                          File(imagePath).deleteSync();
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Preview image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(imagePath),
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Tag",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: tagController,
                    decoration: InputDecoration(
                      hintText: 'e.g., Beautiful Sunset, Coffee Time',
                      filled: true,
                      fillColor: const Color(0xFFF8F8FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Description (Optional)",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'What made this moment special?',
                      filled: true,
                      fillColor: const Color(0xFFF8F8FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (albums.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      "Add to Album (Optional)",
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: albums.map((album) => GestureDetector(
                        onTap: () {
                          setModalState(() {
                            selectedAlbumIdForNew = selectedAlbumIdForNew == album.id ? null : album.id;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: selectedAlbumIdForNew == album.id
                                ? album.color
                                : album.color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            album.name,
                            style: TextStyle(
                              color: selectedAlbumIdForNew == album.id
                                  ? Colors.white
                                  : Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                  const SizedBox(height: 18),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      final tag = tagController.text.trim();
                      if (tag.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please add a tag')),
                        );
                        return;
                      }

                      final newMoment = {
                        'tag': tag,
                        'description': descController.text.trim(),
                        'imagePath': imagePath,
                        'timestamp': DateTime.now().toIso8601String(),
                        'location': location,
                        'albumId': selectedAlbumIdForNew,
                      };

                      setState(() {
                        momentCards.insert(0, newMoment);
                        _saveData();
                      });

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Moment captured! ✨')),
                      );
                    },
                    child: const Text(
                      'Save Moment',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadTaskData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      momentCards = prefs.getStringList('momentCards')?.map((e) => jsonDecode(e) as Map<String, dynamic>).toList() ?? [];
      todoCards = prefs.getStringList('todoCards')?.map((e) => jsonDecode(e) as Map<String, dynamic>).toList() ?? [];

      // Load albums
      final albumsJson = prefs.getStringList('albums') ?? [];
      albums = albumsJson.map((json) => Album.fromJson(jsonDecode(json))).toList();
    });
  }

  Future<void> _saveData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('momentCards', momentCards.map((e) => jsonEncode(e)).toList());
    await prefs.setStringList('todoCards', todoCards.map((e) => jsonEncode(e)).toList());
    await prefs.setStringList('albums', albums.map((e) => jsonEncode(e.toJson())).toList());
  }

  void showAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2E),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9B6DC8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.checklist_rounded, color: Colors.white),
                ),
                title: const Text(
                  'Add Todo',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  addTodoCard();
                },
              ),
              const Divider(color: Colors.white24, height: 1, indent: 20, endIndent: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9B6DC8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Colors.white),
                ),
                title: const Text(
                  'Capture Moment',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  addMoment();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void addTodoCard() {
    final textController = TextEditingController();
    final checklistController = TextEditingController();
    final titleController = TextEditingController();
    bool isChecklist = false;
    List<Map<String, dynamic>> checklistItems = [];
    int chosenColorIndex = Random().nextInt(cardColors.length);

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return StatefulBuilder(
              builder: (ctx, setStateModal) {
                return Padding(
                    padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
                    child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(30))
                        ),
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text("New Todo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                                        IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                                      ]
                                  ),
                                  const SizedBox(height: 16),
                                  const Text("Title", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  const SizedBox(height: 8),
                                  TextField(
                                      controller: titleController,
                                      decoration: InputDecoration(
                                          hintText: 'e.g., Grocery List',
                                          filled: true,
                                          fillColor: const Color(0xFFF8F8FA),
                                          border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide.none
                                          )
                                      )
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                      children: [
                                        Expanded(
                                            child: GestureDetector(
                                                onTap: () => setStateModal(() => isChecklist = false),
                                                child: Container(
                                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                                                    decoration: BoxDecoration(
                                                        color: isChecklist ? const Color(0xFFF8F8FA) : const Color(0xFF9B6DC8),
                                                        borderRadius: BorderRadius.circular(12)
                                                    ),
                                                    child: Center(
                                                        child: Text(
                                                            'Text',
                                                            style: TextStyle(
                                                                color: isChecklist ? Colors.black87 : Colors.white,
                                                                fontWeight: FontWeight.w700
                                                            )
                                                        )
                                                    )
                                                )
                                            )
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                            child: GestureDetector(
                                                onTap: () => setStateModal(() => isChecklist = true),
                                                child: Container(
                                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                                                    decoration: BoxDecoration(
                                                        color: isChecklist ? const Color(0xFF9B6DC8) : const Color(0xFFF8F8FA),
                                                        borderRadius: BorderRadius.circular(12)
                                                    ),
                                                    child: Center(
                                                        child: Text(
                                                            'Checklist',
                                                            style: TextStyle(
                                                                color: isChecklist ? Colors.white : Colors.black87,
                                                                fontWeight: FontWeight.w700
                                                            )
                                                        )
                                                    )
                                                )
                                            )
                                        )
                                      ]
                                  ),
                                  const SizedBox(height: 12),
                                  if (!isChecklist)
                                    Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text("Text", style: TextStyle(fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 8),
                                          TextField(
                                              controller: textController,
                                              maxLines: null,
                                              keyboardType: TextInputType.multiline,
                                              decoration: InputDecoration(
                                                  hintText: 'Write a single to-do item...',
                                                  filled: true,
                                                  fillColor: const Color(0xFFF8F8FA),
                                                  border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(12),
                                                      borderSide: BorderSide.none
                                                  )
                                              )
                                          )
                                        ]
                                    )
                                  else
                                    Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text("Checklist Items", style: TextStyle(fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 8),
                                          ...checklistItems.map((it) {
                                            bool isDone = it['done'] == true;
                                            return ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              leading: GestureDetector(
                                                onTap: () => setStateModal(() => it['done'] = !isDone),
                                                child: Container(
                                                  width: 24,
                                                  height: 24,
                                                  decoration: BoxDecoration(
                                                    color: isDone ? const Color(0xFF2C2C2E) : Colors.transparent,
                                                    border: Border.all(color: const Color(0xFF2C2C2E), width: 2.5),
                                                    borderRadius: BorderRadius.circular(7),
                                                  ),
                                                  child: isDone
                                                      ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                                                      : null,
                                                ),
                                              ),
                                              title: Text(
                                                it['text'],
                                                style: TextStyle(
                                                  decoration: isDone ? TextDecoration.lineThrough : TextDecoration.none,
                                                ),
                                              ),
                                              trailing: IconButton(
                                                icon: const Icon(Icons.delete_outline_rounded),
                                                onPressed: () => setStateModal(() => checklistItems.remove(it)),
                                              ),
                                            );
                                          }),
                                          const SizedBox(height: 8),
                                          Row(
                                              children: [
                                                Expanded(
                                                    child: TextField(
                                                        controller: checklistController,
                                                        decoration: InputDecoration(
                                                            hintText: 'Add item',
                                                            filled: true,
                                                            fillColor: const Color(0xFFF8F8FA),
                                                            border: OutlineInputBorder(
                                                                borderRadius: BorderRadius.circular(12),
                                                                borderSide: BorderSide.none
                                                            )
                                                        ),
                                                        onSubmitted: (val) {
                                                          if (val.trim().isNotEmpty) {
                                                            setStateModal(() {
                                                              checklistItems.insert(0, {'text': val.trim(), 'done': false});
                                                              checklistController.clear();
                                                            });
                                                          }
                                                        }
                                                    )
                                                ),
                                                const SizedBox(width: 8),
                                                ElevatedButton(
                                                    onPressed: () {
                                                      final val = checklistController.text.trim();
                                                      if (val.isNotEmpty) {
                                                        setStateModal(() {
                                                          checklistItems.insert(0, {'text': val, 'done': false});
                                                          checklistController.clear();
                                                        });
                                                      }
                                                    },
                                                    style: ElevatedButton.styleFrom(
                                                        backgroundColor: const Color(0xFF9B6DC8),
                                                        padding: const EdgeInsets.all(14)
                                                    ),
                                                    child: const Icon(Icons.add, color: Colors.white)
                                                )
                                              ]
                                          )
                                        ]
                                    ),
                                  const SizedBox(height: 12),
                                  const Text("Card Color", style: TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                      height: 60,
                                      child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: cardColors.length,
                                          itemBuilder: (cctx, idx) {
                                            final g = cardColors[idx];
                                            final isSel = idx == chosenColorIndex;
                                            return GestureDetector(
                                                onTap: () => setStateModal(() => chosenColorIndex = idx),
                                                child: Container(
                                                    margin: const EdgeInsets.only(right: 10),
                                                    width: 60,
                                                    decoration: BoxDecoration(
                                                        color: g,
                                                        borderRadius: BorderRadius.circular(16),
                                                        border: isSel ? Border.all(color: Colors.black87, width: 2) : null
                                                    )
                                                )
                                            );
                                          }
                                      )
                                  ),
                                  const SizedBox(height: 18),
                                  ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                          minimumSize: const Size(double.infinity, 50),
                                          backgroundColor: Colors.black87,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                      ),
                                      onPressed: () {
                                        final title = titleController.text.trim();
                                        if (title.isEmpty) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Please add a title.'))
                                          );
                                          return;
                                        }
                                        if (!isChecklist) {
                                          final text = textController.text.trim();
                                          if (text.isEmpty) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Please enter text for the to-do.'))
                                            );
                                            return;
                                          }
                                          setState(() {
                                            todoCards.insert(0, {
                                              'title': title,
                                              'isChecklist': false,
                                              'text': text,
                                              'color': cardColors[chosenColorIndex].value
                                            });
                                            _saveData();
                                          });
                                        } else {
                                          if (checklistItems.isEmpty) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Add at least one checklist item.'))
                                            );
                                            return;
                                          }
                                          setState(() {
                                            todoCards.insert(0, {
                                              'title': title,
                                              'isChecklist': true,
                                              'checklist': checklistItems,
                                              'color': cardColors[chosenColorIndex].value
                                            });
                                            _saveData();
                                          });
                                        }
                                        Navigator.pop(ctx);
                                      },
                                      child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                                  ),
                                  const SizedBox(height: 8)
                                ]
                            )
                        )
                    )
                );
              }
          );
        }
    );
  }

  Widget buildTodoCard(Map<String, dynamic> card, int index) {
    Color cardColor = Color(card['color'] ?? cardColors[0].value);
    return GestureDetector(
      onLongPress: () => _showDeleteDialog(index, false),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration:
        BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (card['title'] != null && card['title'].isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(card['title'],
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                        color: Colors.black87)),
              ),
            if (card['isChecklist'] == true)
              ...List<Widget>.from(
                (card['checklist'] as List).asMap().entries.map((entry) {
                  int itemIndex = entry.key;
                  var item = entry.value;
                  bool isDone = item['done'] == true;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              card['checklist'][itemIndex]['done'] = !isDone;
                              _saveData();
                            });
                          },
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isDone
                                  ? const Color(0xFF2C2C2E)
                                  : Colors.transparent,
                              border: Border.all(
                                  color: const Color(0xFF2C2C2E), width: 2.5),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: isDone
                                ? const Icon(Icons.check_rounded,
                                size: 16, color: Colors.white)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            item['text'],
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color:
                              isDone ? Colors.black45 : Colors.black87,
                              decoration: isDone
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              )
            else
              Text(
                card['text'],
                style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87),
              ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(int index, bool isTodo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Todo?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                todoCards.removeAt(index);
                _saveData();
              });
              Navigator.pop(ctx);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// New page for viewing moments
class MomentViewerPage extends StatefulWidget {
  final List<Map<String, dynamic>> moments;
  final int initialIndex;
  final Function(Map<String, dynamic>) onDelete;
  final Function(Map<String, dynamic>, String?) onAlbumChange;
  final List<Album> albums;

  const MomentViewerPage({
    Key? key,
    required this.moments,
    required this.initialIndex,
    required this.onDelete,
    required this.onAlbumChange,
    required this.albums,
  }) : super(key: key);

  @override
  State<MomentViewerPage> createState() => _MomentViewerPageState();
}

class _MomentViewerPageState extends State<MomentViewerPage> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _shareImage() async {
    final moment = widget.moments[_currentIndex];
    if (moment['imagePath'] != null) {
      await Share.shareXFiles(
        [XFile(moment['imagePath'])],
        text: '${moment['tag'] ?? ''}\n${moment['description'] ?? ''}',
      );
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Moment?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              widget.onDelete(widget.moments[_currentIndex]);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAlbumSelector() {
    final currentMoment = widget.moments[_currentIndex];
    String? selectedAlbumId = currentMoment['albumId'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Move to Album',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('No Album'),
                trailing: selectedAlbumId == null ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () {
                  widget.onAlbumChange(currentMoment, null);
                  Navigator.pop(context);
                },
              ),
              ...widget.albums.map((album) => ListTile(
                leading: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: album.color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                title: Text(album.name),
                trailing: selectedAlbumId == album.id ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () {
                  widget.onAlbumChange(currentMoment, album.id);
                  Navigator.pop(context);
                },
              )).toList(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_outlined, color: Colors.white),
            onPressed: _showAlbumSelector,
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _shareImage,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: _showDeleteConfirmation,
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemCount: widget.moments.length,
        itemBuilder: (context, index) {
          final moment = widget.moments[index];
          return SingleChildScrollView(
            child: Column(
              children: [
                // Image
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: moment['imagePath'] != null && File(moment['imagePath']).existsSync()
                        ? Image.file(
                      File(moment['imagePath']),
                      fit: BoxFit.contain,
                    )
                        : Container(
                      height: 400,
                      color: Colors.grey[800],
                      child: const Icon(Icons.photo, size: 100, color: Colors.white54),
                    ),
                  ),
                ),
                // Details card
                Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9B6DC8).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          moment['tag'] ?? 'Moment',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF9B6DC8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Description
                      if (moment['description'] != null && moment['description'].isNotEmpty) ...[
                        Text(
                          moment['description'],
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            color: Colors.black87,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Date & Time
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('EEEE, MMMM d, yyyy').format(DateTime.parse(moment['timestamp'])),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('h:mm a').format(DateTime.parse(moment['timestamp'])),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      // Location
                      if (moment['location'] != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 18, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                moment['location'],
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Page indicator
                if (widget.moments.length > 1)
                  Container(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        widget.moments.length,
                            (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: index == _currentIndex ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: index == _currentIndex
                                ? const Color(0xFF9B6DC8)
                                : Colors.grey[400],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}