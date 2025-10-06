import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signature/signature.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

// ======================================================================
// SETUP INSTRUCTIONS (REQUIRED):
//
// 1. FIRESTORE:
//    - Create a new collection named `kindness_acts`.
//    - Add documents to this collection. Each document MUST have a
//      field named `act` (type: String) containing the text of a kind act.
//
// 2. BADGE IMAGES:
//    - Create an `assets` folder in your project's root directory.
//    - Place your 10 badge images inside it (e.g., `assets/badge1.jpeg`, `assets/badge2.jpeg`, etc.).
//    - Make sure to declare the assets folder in your `pubspec.yaml` file:
//
//      flutter:
//        assets:
//          - assets/
//
// ======================================================================

class KindActPage extends StatefulWidget {
  const KindActPage({Key? key}) : super(key: key);

  @override
  State<KindActPage> createState() => _KindActPageState();
}

class _KindActPageState extends State<KindActPage> with TickerProviderStateMixin {
  // FIX: Loading state to prevent form flash
  bool _isLoading = true;

  bool _isRegistered = false;
  int _kindnessTokens = 0;
  String? _currentAct;
  bool _actCompleted = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  int _streakCount = 0;
  DateTime? _lastActCompletionDate;
  List<String> _badges = [];

  final GlobalKey _shareCardKey = GlobalKey();
  final GlobalKey _badgeShareKey = GlobalKey();

  String _userName = '';
  String _userCountry = '';
  String _userCity = '';
  String _userAge = '';
  String _userProfession = '';
  String _userMotivation = '';
  Uint8List? _signatureBytes;

  // NEW: Stream for the banner
  late Stream<DocumentSnapshot> _bannerStream;

  final List<Map<String, String>> _allBadges = [
    {'name': 'Kind Flame', 'image': 'assets/badge1.jpeg'},
    {'name': 'Gentle Glow', 'image': 'assets/badge2.jpeg'},
    {'name': 'Soul Spark', 'image': 'assets/badge3.jpeg'},
    {'name': 'Warm Ripple', 'image': 'assets/badge4.jpeg'},
    {'name': 'Light Trail', 'image': 'assets/badge5.jpeg'},
    {'name': 'Kindling', 'image': 'assets/badge6.jpeg'},
    {'name': 'EverKind', 'image': 'assets/badge7.jpeg'},
    {'name': 'GlowChain', 'image': 'assets/badge8.jpeg'},
    {'name': 'HeartStreak', 'image': 'assets/badge9.jpeg'},
    {'name': 'RippleRun', 'image': 'assets/badge10.jpeg'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData().then((_) {
      _syncWithFirestore();
      _checkStreak();
      // FIX: Set loading to false after all initial data is loaded
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // NEW: Initialize banner stream
    _bannerStream = FirebaseFirestore.instance
        .collection('banners')
        .doc('main_banner')
        .snapshots();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isRegistered = prefs.getBool('kindness_registered') ?? false;
      _kindnessTokens = prefs.getInt('kindness_tokens') ?? 0;
      _userName = prefs.getString('kindness_name') ?? '';
      _userCountry = prefs.getString('kindness_country') ?? '';
      _userCity = prefs.getString('kindness_city') ?? '';
      _userAge = prefs.getString('kindness_age') ?? '';
      _userProfession = prefs.getString('kindness_profession') ?? '';
      _userMotivation = prefs.getString('kindness_motivation') ?? '';
      _currentAct = prefs.getString('current_act');

      final lastCompletionMillis = prefs.getInt('last_act_completion_date');
      if (lastCompletionMillis != null) {
        _lastActCompletionDate = DateTime.fromMillisecondsSinceEpoch(lastCompletionMillis);
        _actCompleted = DateUtils.isSameDay(_lastActCompletionDate, DateTime.now());
      } else {
        _actCompleted = false;
      }

      _streakCount = prefs.getInt('streak_count') ?? 0;
      _badges = prefs.getStringList('earned_badges') ?? [];

      final signatureString = prefs.getString('kindness_signature');
      if (signatureString != null) {
        _signatureBytes = Uint8List.fromList(signatureString.codeUnits);
      }
    });
  }

  Future<void> _saveUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('kindness_registered', _isRegistered);
    await prefs.setInt('kindness_tokens', _kindnessTokens);
    await prefs.setString('kindness_name', _userName);
    await prefs.setString('kindness_country', _userCountry);
    await prefs.setString('kindness_city', _userCity);
    await prefs.setString('kindness_age', _userAge);
    await prefs.setString('kindness_profession', _userProfession);
    await prefs.setString('kindness_motivation', _userMotivation);
    if (_currentAct != null) {
      await prefs.setString('current_act', _currentAct!);
    }
    await prefs.setBool('act_completed', _actCompleted);
    await prefs.setInt('streak_count', _streakCount);
    if (_lastActCompletionDate != null) {
      await prefs.setInt('last_act_completion_date', _lastActCompletionDate!.millisecondsSinceEpoch);
    }
    await prefs.setStringList('earned_badges', _badges);
  }

  Future<void> _syncWithFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !_isRegistered) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('user_stats').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final firestoreTokens = doc.data()!['totalActs'] as int? ?? 0;
        final localTokens = _kindnessTokens;

        if (firestoreTokens > localTokens) {
          setState(() {
            _kindnessTokens = firestoreTokens;
          });
          await _saveUserData();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error syncing with Firestore: $e");
      }
    }
  }

  void _checkStreak() {
    if (_lastActCompletionDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final lastDay = DateTime(_lastActCompletionDate!.year, _lastActCompletionDate!.month, _lastActCompletionDate!.day);

      if (today.difference(lastDay).inDays > 1) {
        setState(() {
          _streakCount = 0;
        });
        _saveUserData();
      }
    }
  }

  Future<String> _generateDynamicAct() async {
    try {
      final actsCollection = FirebaseFirestore.instance.collection('kindness_acts');
      final querySnapshot = await actsCollection.get();

      if (querySnapshot.docs.isEmpty) {
        return "Setup 'kindness_acts' collection in Firestore.";
      }

      final randomIndex = Random().nextInt(querySnapshot.docs.length);
      final randomAct = querySnapshot.docs[randomIndex].data()['act'];

      return randomAct ?? "Do something kind.";

    } catch (e) {
      if (kDebugMode) {
        print("Error fetching act from Firestore: $e");
      }
    }
    return "Could not fetch an act. Please try again.";
  }

  Future<void> _checkMilestone() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _currentAct != null) {
      try {
        await FirebaseFirestore.instance.collection('completed_acts').add({
          'userId': user.uid,
          'userEmail': user.email,
          'userName': _userName,
          'act': _currentAct,
          'tokenNumber': _kindnessTokens,
          'timestamp': FieldValue.serverTimestamp(),
        });

        await FirebaseFirestore.instance
            .collection('user_stats')
            .doc(user.uid)
            .set({
          'email': user.email,
          'name': _userName,
          'country': _userCountry,
          'city': _userCity,
          'age': _userAge,
          'totalActs': _kindnessTokens,
          'currentLevel': (_kindnessTokens ~/ 50) + 1,
          'lastActCompleted': _currentAct,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (_kindnessTokens % 50 == 0 && _kindnessTokens > 0) {
          await FirebaseFirestore.instance.collection('milestones').add({
            'userId': user.uid,
            'userEmail': user.email,
            'userName': _userName,
            'milestone': _kindnessTokens,
            'level': _kindnessTokens ~/ 50,
            'timestamp': FieldValue.serverTimestamp(),
          });

          _showCelebrationDialog();
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error saving to Firestore: $e');
        }
      }
    }
  }

  void _showCelebrationDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade300, Colors.amber.shade600],
                  ),
                ),
                child: const Icon(
                  Icons.celebration,
                  color: Colors.white,
                  size: 50,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Milestone Achieved!',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '$_kindnessTokens Acts of Kindness',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Level ${_kindnessTokens ~/ 50} Kindness Champion',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(
                  'Continue',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _generateNewAct() async {
    if (_actCompleted && _hasCompletedActToday()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('You\'ve completed your act for the day. Come back tomorrow!'),
          backgroundColor: Colors.grey.shade800,
        ),
      );
      return;
    }

    if (_currentAct != null && !_actCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please complete the current act first!'),
          backgroundColor: Colors.grey.shade800,
        ),
      );
      return;
    }

    String newAct = await _generateDynamicAct();
    setState(() {
      _currentAct = newAct;
      _actCompleted = false;
    });
    _saveUserData();
  }

  Future<void> _completeAct() async {
    final now = DateTime.now();
    setState(() {
      _actCompleted = true;

      if (_lastActCompletionDate == null || !DateUtils.isSameDay(_lastActCompletionDate, now)) {
        _kindnessTokens++;
        _lastActCompletionDate = now;
        _streakCount++;

        if (_streakCount >= 7) {
          _awardBadge();
          _streakCount = 0; // Reset after awarding
        }
      }
    });

    await _saveUserData();
    await _checkMilestone();
    _showShareCard();
  }

  void _awardBadge() {
    if (_badges.length < _allBadges.length) {
      String newBadgeName = _allBadges[_badges.length]['name']!;
      setState(() {
        _badges.add(newBadgeName);
      });
      _showBadgeShareDialog(newBadgeName, _allBadges[_badges.length-1]['image']!);
    } else {
      _showStreakCompletionDialog();
    }
  }

  Future<Uint8List?> _captureWidget(GlobalKey key) async {
    try {
      RenderRepaintBoundary boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      if (kDebugMode) {
        print('Error capturing widget: $e');
      }
      return null;
    }
  }

  Future<void> _showShareCard() async {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                "Inspire others by sharing your act!",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            RepaintBoundary(
              key: _shareCardKey,
              child: Container(
                width: 300,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF3E0), Color(0xFFFAD9E0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white.withOpacity(0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/bankofkindness.jpg',
                            width: 30,
                            height: 30,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Bank of Kindness',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.85),
                      ),
                      child: Text(
                        'ACT COMPLETED',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '"$_currentAct"',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Token #$_kindnessTokens',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _userName,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '#OneStepToChange',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final imageBytes = await _captureWidget(_shareCardKey);
                    if (imageBytes != null) {
                      await Share.shareXFiles(
                        [
                          XFile.fromData(
                            imageBytes,
                            name: 'kindness_act.png',
                            mimeType: 'image/png',
                          ),
                        ],
                        text: 'I completed an act of kindness! #BankOfKindness',
                      );
                    }
                  },
                  icon: const Icon(Icons.share, size: 18, color: Colors.white),
                  label: const Text('Share'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: Colors.black),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: const Text('Cancel', style: TextStyle(color: Colors.black)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBadgeShareDialog(String badgeName, String badgeImage) async {
    showDialog(
        context: context,
        builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RepaintBoundary(
                  key: _badgeShareKey,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFF3E0), Color(0xFFFAD9E0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20)
                    ),
                    child: Column(
                      children: [
                        Text("New Badge Unlocked!", style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Image.asset(badgeImage, width: 100, height: 100),
                        const SizedBox(height: 16),
                        Text(badgeName, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text("Awarded for completing a 7-day kindness streak.", textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    final imageBytes = await _captureWidget(_badgeShareKey);
                    if (imageBytes != null) {
                      await Share.shareXFiles(
                        [
                          XFile.fromData(
                            imageBytes,
                            name: 'kindness_badge.png',
                            mimeType: 'image/png',
                          ),
                        ],
                        text: 'I earned the "$badgeName" badge in the Bank of Kindness! #OneStepToChange',
                      );
                    }
                  },
                  icon: const Icon(Icons.share, color: Colors.white),
                  label: const Text("Share Badge"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                )
              ],
            )
        )
    );
  }

  void _showStreakCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star, color: Colors.amber[600], size: 60),
              const SizedBox(height: 16),
              Text(
                "Streak Complete!",
                style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                "Congratulations! You've completed another 7-day kindness streak. Keep the momentum going!",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.grey.shade700, height: 1.5),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                child: const Text("Continue"),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showProfileCard() {
    final level = (_kindnessTokens ~/ 50) + 1;
    final progress = _kindnessTokens % 50;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: Image.asset(
                    'assets/bankofkindness.jpg',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Bank of Kindness',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(height: 32),
                _buildProfileRow('Name', _userName),
                _buildProfileRow('Location', '$_userCity, $_userCountry'),
                _buildProfileRow('Age', _userAge),
                _buildProfileRow('Profession', _userProfession),
                _buildProfileRow('Total Acts', '$_kindnessTokens'),
                _buildProfileRow('Current Level', 'Level $level'),
                const SizedBox(height: 16),
                Column(
                  children: [
                    Text(
                      'Progress to Level ${level + 1}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress / 50,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$progress/50',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                Text(
                  'Badges Earned',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _badges.isEmpty
                    ? Text(
                  'Complete a 7-day streak to earn your first badge!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: Colors.grey.shade600),
                )
                    : Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: _badges.map((badgeName) {
                    final badgeData = _allBadges.firstWhere((b) => b['name'] == badgeName, orElse: () => {});
                    if (badgeData.isEmpty) return const SizedBox.shrink();
                    return Column(
                      children: [
                        Image.asset(badgeData['image']!, width: 50, height: 50),
                        const SizedBox(height: 4),
                        Text(
                          badgeName,
                          style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w500),
                        ),
                      ],
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  bool _hasCompletedActToday() {
    if (_lastActCompletionDate == null) return false;
    return DateUtils.isSameDay(_lastActCompletionDate, DateTime.now());
  }

  // NEW: Method to build the banner from Firestore data
  Widget _buildBanner() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _bannerStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show a minimal placeholder while loading
          return Container(height: 65, margin: const EdgeInsets.only(bottom: 8));
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink(); // Show nothing if no document
        }

        var bannerData = snapshot.data!.data() as Map<String, dynamic>;
        bool isVisible = bannerData['isVisible'] ?? false;
        String? imageUrl = bannerData['imageUrl'];

        if (isVisible && imageUrl != null) {
          return Container(
            height: 65,
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(child: Icon(Icons.error));
                },
              ),
            ),
          );
        }
        return const SizedBox.shrink(); // Show nothing if not visible
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Handle loading state to prevent form flash
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF9F5F0),
        body: Center(
          child: CircularProgressIndicator(color: Colors.black),
        ),
      );
    }

    if (!_isRegistered) {
      return _RegistrationForm(
        onComplete: (data) async {
          setState(() {
            _isRegistered = true;
            _userName = data['name']!;
            _userCountry = data['country']!;
            _userCity = data['city']!;
            _userAge = data['age']!;
            _userProfession = data['profession']!;
            _userMotivation = data['motivation']!;
            _signatureBytes = data['signature'] as Uint8List?;
          });

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('kindness_registered', true);
          await prefs.setString('kindness_name', _userName);
          await prefs.setString('kindness_country', _userCountry);
          await prefs.setString('kindness_city', _userCity);
          await prefs.setString('kindness_age', _userAge);
          await prefs.setString('kindness_profession', _userProfession);
          await prefs.setString('kindness_motivation', _userMotivation);
          if (_signatureBytes != null) {
            await prefs.setString('kindness_signature', String.fromCharCodes(_signatureBytes!));
          }

          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            try {
              await FirebaseFirestore.instance
                  .collection('kindness_users')
                  .doc(user.uid)
                  .set({
                'email': user.email,
                'name': _userName,
                'country': _userCountry,
                'city': _userCity,
                'age': _userAge,
                'profession': _userProfession,
                'motivation': _userMotivation,
                'registeredAt': FieldValue.serverTimestamp(),
                'totalActs': 0,
                'currentLevel': 1,
              });
            } catch (e) {
              if (kDebugMode) {
                print('Error saving to Firestore: $e');
              }
            }
          }
        },
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F5F0),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/bankofkindness.jpg',
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Bank of Kindness',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: _showProfileCard,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.favorite, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '${_kindnessTokens % 50}/50',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: Colors.black.withOpacity(0.03),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(7, (index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: Icon(
                      Icons.star,
                      size: 28,
                      color: index < _streakCount ? Colors.amber[600] : Colors.grey.shade300,
                    ),
                  );
                }),
              ),
            ),
            // NEW: Banner added here
            _buildBanner(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Daily Act of Kindness',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the heart to generate your act',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 40),
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _currentAct == null || _hasCompletedActToday() ? 1.0 : _pulseAnimation.value,
                          child: GestureDetector(
                            onTap: _generateNewAct,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black,
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                    color: Colors.black.withOpacity(0.2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.favorite,
                                size: 50,
                                color: Color(0xFFFFE4E1),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    if (_currentAct != null) ...[
                      const SizedBox(height: 40),
                      if (_hasCompletedActToday())
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20)
                          ),
                          child: Text(
                              "Great! You've taken a step towards change for the day.\nCome back tomorrow for another!",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade800, height: 1.5)
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 15,
                                color: Colors.black.withOpacity(0.05),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Your Act',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _currentAct!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 20),
                              if (!_actCompleted)
                                ElevatedButton(
                                  onPressed: _completeAct,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 12,
                                    ),
                                  ),
                                  child: Text(
                                    'Mark as Complete',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(25),
                                    border: Border.all(color: Colors.green.shade200),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.green.shade700,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Completed',
                                        style: GoogleFonts.poppins(
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegistrationForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onComplete;

  const _RegistrationForm({
    required this.onComplete,
  });

  @override
  State<_RegistrationForm> createState() => _RegistrationFormState();
}

class _RegistrationFormState extends State<_RegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();
  final _ageController = TextEditingController();
  final _professionController = TextEditingController();
  final _motivationController = TextEditingController();
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
  );
  bool _agreed = false;

  @override
  void dispose() {
    _nameController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _ageController.dispose();
    _professionController.dispose();
    _motivationController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate() && _agreed) {
      final signature = await _signatureController.toPngBytes();

      RibbonAnimationOverlay.show(context, 'SWORN WITH KINDNESS');

      Future.delayed(const Duration(seconds: 2), () {
        widget.onComplete({
          'name': _nameController.text,
          'country': _countryController.text,
          'city': _cityController.text,
          'age': _ageController.text,
          'profession': _professionController.text,
          'motivation': _motivationController.text,
          'signature': signature,
        });
      });
    } else if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the declaration'),
          backgroundColor: Colors.black87,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F5F0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(60),
                        child: Image.asset(
                          'assets/bankofkindness.jpg',
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Join the Movement',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your commitment to a kinder world starts here.',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                _buildTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  icon: Icons.person,
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _cityController,
                  label: 'City',
                  icon: Icons.location_city,
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _countryController,
                  label: 'Country',
                  icon: Icons.public,
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _ageController,
                        label: 'Age',
                        icon: Icons.cake,
                        keyboardType: TextInputType.number,
                        validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: _buildTextField(
                        controller: _professionController,
                        label: 'Profession',
                        icon: Icons.work,
                        validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _motivationController,
                  label: 'Why spread kindness?',
                  icon: Icons.favorite,
                  maxLines: 3,
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 32),
                Text(
                  'Declaration of Kindness',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'I hereby pledge to perform acts of kindness, to spread compassion in my community, and to make the world a better place through simple, meaningful actions.',
                  textAlign: TextAlign.justify,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    height: 1.6,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Your Signature',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Signature(
                    controller: _signatureController,
                    backgroundColor: Colors.white,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _signatureController.clear(),
                    child: const Text('Clear'),
                  ),
                ),
                CheckboxListTile(
                  value: _agreed,
                  onChanged: (value) {
                    setState(() {
                      _agreed = value ?? false;
                    });
                  },
                  title: Text(
                    'I agree to the declaration',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: Colors.black,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 32),
                Center(
                  child: ElevatedButton(
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 5,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_user, color: Colors.white),
                        const SizedBox(width: 12),
                        Text(
                          'TAKE THE OATH',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
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
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.poppins(),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.black54),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}

class RibbonAnimationOverlay extends StatefulWidget {
  final String text;
  const RibbonAnimationOverlay({super.key, required this.text});

  static void show(BuildContext context, String text) {
    OverlayEntry? overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => RibbonAnimationOverlay(text: text),
    );

    Navigator.of(context).overlay?.insert(overlayEntry);

    Future.delayed(const Duration(milliseconds: 2500), () {
      overlayEntry?.remove();
    });
  }

  @override
  State<RibbonAnimationOverlay> createState() => _RibbonAnimationOverlayState();
}

class _RibbonAnimationOverlayState extends State<RibbonAnimationOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, -2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.5),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              height: 60,
              width: double.infinity,
              color: Colors.black,
              child: Center(
                child: Text(
                  widget.text,
                  style: GoogleFonts.playfairDisplay(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}