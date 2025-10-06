import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/foundation.dart'; // Import for listEquals
import 'package:url_launcher/url_launcher.dart'; // Import for launching URLs

// ========================= DATA MODELS =========================
class JournalEntry {
  final String id;
  final DateTime date;
  String title;
  String mood;
  String entryText;
  int themeColorValue;
  bool isProtected;
  String? protectionKey;
  String? sharedBy;
  String? sharedByEmail;
  String? sharedNote;
  DateTime? sharedAt;
  bool isShared;
  String? stampId;

  JournalEntry({
    required this.id,
    required this.date,
    required this.title,
    required this.mood,
    required this.entryText,
    required this.themeColorValue,
    this.isProtected = false,
    this.protectionKey,
    this.sharedBy,
    this.sharedByEmail,
    this.sharedNote,
    this.sharedAt,
    this.isShared = false,
    this.stampId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'title': title,
    'mood': mood,
    'entryText': entryText,
    'themeColorValue': themeColorValue,
    'isProtected': isProtected,
    'protectionKey': protectionKey,
    'sharedBy': sharedBy,
    'sharedByEmail': sharedByEmail,
    'sharedNote': sharedNote,
    'sharedAt': sharedAt?.toIso8601String(),
    'isShared': isShared,
    'stampId': stampId,
  };

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
    id: json['id'],
    date: DateTime.parse(json['date']),
    title: json['title'],
    mood: json['mood'],
    entryText: json['entryText'],
    themeColorValue: json['themeColorValue'] ?? 0xFFFDF0D5,
    isProtected: json['isProtected'] ?? false,
    protectionKey: json['protectionKey'],
    sharedBy: json['sharedBy'],
    sharedByEmail: json['sharedByEmail'],
    sharedNote: json['sharedNote'],
    sharedAt: json['sharedAt'] != null ? DateTime.parse(json['sharedAt']) : null,
    isShared: json['isShared'] ?? false,
    stampId: json['stampId'],
  );
}

class PostageStamp {
  final String id;
  final String frameShape;
  final Color frameColor;
  final double frameThickness;
  final String? imagePath;
  final String? imageUrl;
  final String? imageFilter;
  final List<StampText> texts;
  final DateTime createdAt;
  String? sharedBy;
  String? sharedByEmail;

  PostageStamp({
    required this.id,
    required this.frameShape,
    required this.frameColor,
    this.frameThickness = 2.0,
    this.imagePath,
    this.imageUrl,
    this.imageFilter,
    required this.texts,
    required this.createdAt,
    this.sharedBy,
    this.sharedByEmail,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'frameShape': frameShape,
    'frameColor': frameColor.value,
    'frameThickness': frameThickness,
    'imagePath': imagePath,
    'imageUrl': imageUrl,
    'imageFilter': imageFilter,
    'texts': texts.map((t) => t.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'sharedBy': sharedBy,
    'sharedByEmail': sharedByEmail,
  };

  factory PostageStamp.fromJson(Map<String, dynamic> json) => PostageStamp(
    id: json['id'],
    frameShape: json['frameShape'],
    frameColor: Color(json['frameColor']),
    frameThickness: json['frameThickness'] ?? 2.0,
    imagePath: json['imagePath'],
    imageUrl: json['imageUrl'],
    imageFilter: json['imageFilter'],
    texts: (json['texts'] as List).map((t) => StampText.fromJson(t)).toList(),
    createdAt: DateTime.parse(json['createdAt']),
    sharedBy: json['sharedBy'],
    sharedByEmail: json['sharedByEmail'],
  );
}

class StampText {
  String text;
  Offset position;
  String fontFamily;
  double fontSize;
  Color color;

  StampText({
    required this.text,
    required this.position,
    required this.fontFamily,
    required this.fontSize,
    required this.color,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'positionX': position.dx,
    'positionY': position.dy,
    'fontFamily': fontFamily,
    'fontSize': fontSize,
    'color': color.value,
  };

  factory StampText.fromJson(Map<String, dynamic> json) => StampText(
    text: json['text'],
    position: Offset(json['positionX'], json['positionY']),
    fontFamily: json['fontFamily'],
    fontSize: json['fontSize'],
    color: Color(json['color']),
  );
}

class Friend {
  final String userId;
  final String email;
  final String? name;
  final DateTime addedAt;

  Friend({
    required this.userId,
    required this.email,
    this.name,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'email': email,
    'name': name,
    'addedAt': addedAt.toIso8601String(),
  };

  factory Friend.fromJson(Map<String, dynamic> json) => Friend(
    userId: json['userId'],
    email: json['email'],
    name: json['name'],
    addedAt: DateTime.parse(json['addedAt']),
  );
}
// ========================= MAIN JOURNAL PAGE =========================

class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  final PageController _pageController = PageController();
  List<JournalEntry> _journalEntries = [];
  List<JournalEntry> _receivedJournals = [];
  List<JournalEntry> _sentJournals = [];
  List<Friend> _friends = [];
  List<PostageStamp> _myStamps = [];
  List<PostageStamp> _receivedStamps = [];
  Map<String, List<JournalEntry>> _groupedEntries = {};
  Map<String, bool> _expandedMonths = {};
  int _unreadCount = 0;
  PostageStamp? _selectedStamp;

  String? _newMood;
  Color _newThemeColor = const Color(0xFFFDF0D5);
  bool _newIsProtected = false;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _entryController = TextEditingController();
  final TextEditingController _protectionKeyController = TextEditingController();

  late Stream<DocumentSnapshot> _bannerStream;
  final Uri _buyMeACoffeeUrl = Uri.parse('https://www.buymeacoffee.com/adhithya');


  @override
  void initState() {
    super.initState();
    _ensureUserInDirectory();
    _loadJournals();
    _loadFriends();
    _loadStamps();
    _listenToSharedJournals();
    _listenToSentJournals();
    _listenToSharedStamps();
    _loadUnreadCount();

    _bannerStream = FirebaseFirestore.instance
        .collection('banners')
        .doc('main_banner')
        .snapshots();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _titleController.dispose();
    _entryController.dispose();
    _protectionKeyController.dispose();
    super.dispose();
  }

  Future<void> _launchBuyMeACoffee() async {
    if (!await launchUrl(_buyMeACoffeeUrl, mode: LaunchMode.externalApplication)) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch URL'))
        );
      }
    }
  }

  Future<void> _loadStamps() async {
    final prefs = await SharedPreferences.getInstance();
    final stampStrings = prefs.getStringList('myStamps') ?? [];
    final receivedStampStrings = prefs.getStringList('receivedStamps') ?? [];

    setState(() {
      _myStamps = stampStrings.map((s) => PostageStamp.fromJson(jsonDecode(s))).toList();
      _receivedStamps = receivedStampStrings.map((s) => PostageStamp.fromJson(jsonDecode(s))).toList();
    });
  }

  Future<void> _saveStamps() async {
    final prefs = await SharedPreferences.getInstance();
    final stampStrings = _myStamps.map((s) => jsonEncode(s.toJson())).toList();
    final receivedStampStrings = _receivedStamps.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList('myStamps', stampStrings);
    await prefs.setStringList('receivedStamps', receivedStampStrings);
  }

  void _listenToSharedStamps() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('shared_stamps')
        .where('receiverId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final stamp = PostageStamp.fromJson(data);
        if (!_receivedStamps.any((s) => s.id == stamp.id)) {
          setState(() {
            _receivedStamps.add(stamp);
          });
          _saveStamps();
        }
      }
    });
  }

  Future<void> _loadUnreadCount() async {
    final prefs = await SharedPreferences.getInstance();
    final readJournals = prefs.getStringList('read_journals') ?? [];
    setState(() {
      _unreadCount = _receivedJournals.where((j) => !readJournals.contains(j.id)).length;
    });
  }

  Future<void> _markJournalsAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    final readJournals = _receivedJournals.map((j) => j.id).toList();
    await prefs.setStringList('read_journals', readJournals);
    setState(() {
      _unreadCount = 0;
    });
  }

  void _listenToSentJournals() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('shared_journals')
        .where('senderId', isEqualTo: user.uid)
        .orderBy('sharedAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      final sentJournals = snapshot.docs.map((doc) {
        final data = doc.data();
        return JournalEntry(
          id: doc.id,
          date: (data['date'] as Timestamp).toDate(),
          title: data['title'],
          mood: data['mood'],
          entryText: data['entryText'],
          themeColorValue: data['themeColorValue'],
          sharedBy: data['receiverEmail'] ?? 'Unknown',
          sharedByEmail: data['receiverEmail'],
          sharedNote: data['sharedNote'],
          sharedAt: (data['sharedAt'] as Timestamp).toDate(),
          isShared: true,
        );
      }).toList();

      setState(() {
        _sentJournals = sentJournals;
      });
    });
  }

  Future<void> _ensureUserInDirectory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('user_directory')
          .doc(user.uid)
          .set({
        'email': user.email?.toLowerCase(),
        'name': user.displayName ?? user.email?.split('@')[0] ?? 'User',
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error adding user to directory: $e');
    }
  }

  void _listenToSharedJournals() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('shared_journals')
        .where('receiverId', isEqualTo: user.uid)
        .orderBy('sharedAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      final receivedJournals = snapshot.docs.map((doc) {
        final data = doc.data();
        return JournalEntry(
          id: doc.id,
          date: (data['date'] as Timestamp).toDate(),
          title: data['title'],
          mood: data['mood'],
          entryText: data['entryText'],
          themeColorValue: data['themeColorValue'],
          sharedBy: data['senderName'] ?? 'Unknown',
          sharedByEmail: data['senderEmail'],
          sharedNote: data['sharedNote'],
          sharedAt: (data['sharedAt'] as Timestamp).toDate(),
          isShared: true,
        );
      }).toList();

      setState(() {
        _receivedJournals = receivedJournals;
      });
      _loadUnreadCount();
    });
  }

  Future<void> _loadFriends() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data()?['friends'] != null) {
        final friendsList = (doc.data()!['friends'] as List)
            .map((f) => Friend.fromJson(f))
            .toList();
        setState(() {
          _friends = friendsList;
        });
      }
    } catch (e) {
      print('Error loading friends: $e');
    }
  }

  Future<void> _addFriend(String friendEmail) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    friendEmail = friendEmail.trim().toLowerCase();

    if (friendEmail == user.email?.toLowerCase()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You cannot add yourself as a friend')),
        );
      }
      return;
    }

    try {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Searching for user...')),
        );
      }

      final querySnapshot = await FirebaseFirestore.instance
          .collection('user_directory')
          .get();

      final foundDocs = querySnapshot.docs.where((doc) {
        final docEmail = doc.data()['email']?.toString().toLowerCase() ?? '';
        return docEmail == friendEmail;
      }).toList();

      String? friendId;
      String? friendName;

      if (foundDocs.isNotEmpty) {
        final friendDoc = foundDocs.first;
        friendId = friendDoc.id;
        friendName = friendDoc.data()['name'] ?? friendEmail.split('@')[0];
      } else {
        try {
          final tempId = 'pending_${DateTime.now().millisecondsSinceEpoch}';
          await FirebaseFirestore.instance
              .collection('user_directory')
              .doc(tempId)
              .set({
            'email': friendEmail,
            'name': friendEmail.split('@')[0],
            'isPending': true,
            'addedBy': user.uid,
            'lastUpdated': FieldValue.serverTimestamp(),
          });

          friendId = tempId;
          friendName = friendEmail.split('@')[0];
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('User $friendEmail not found. They need to log in at least once.')),
            );
          }
          return;
        }
      }

      if (_friends.any((f) => f.email.toLowerCase() == friendEmail)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Already in your friend list')),
          );
        }
        return;
      }

      final newFriend = Friend(
        userId: friendId,
        email: friendEmail,
        name: friendName,
        addedAt: DateTime.now(),
      );

      setState(() {
        _friends.add(newFriend);
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'friends': FieldValue.arrayUnion([newFriend.toJson()])
      }, SetOptions(merge: true));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$friendEmail added as friend!')),
        );
      }
    } catch (e) {
      print('Error adding friend: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error adding friend. Please try again.')),
        );
      }
    }
  }

  Future<void> _removeFriend(Friend friend) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _friends.removeWhere((f) => f.userId == friend.userId);
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'friends': _friends.map((f) => f.toJson()).toList()
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${friend.email} removed from friends')),
        );
      }
    } catch (e) {
      print('Error removing friend: $e');
    }
  }

  Future<void> _shareJournalWithMultiple(JournalEntry entry, List<Friend> friends, String? note, String senderName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      for (var friend in friends) {
        await FirebaseFirestore.instance.collection('shared_journals').add({
          'senderId': user.uid,
          'senderEmail': user.email,
          'senderName': senderName.isNotEmpty ? senderName : user.email?.split('@')[0] ?? 'Friend',
          'receiverId': friend.userId,
          'receiverEmail': friend.email,
          'title': entry.title,
          'mood': entry.mood,
          'entryText': entry.entryText,
          'themeColorValue': entry.themeColorValue,
          'date': Timestamp.fromDate(entry.date),
          'sharedAt': FieldValue.serverTimestamp(),
          'sharedNote': note,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Journal shared with ${friends.length} friend(s)!')),
        );
      }
    } catch (e) {
      print('Error sharing journal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error sharing journal')),
        );
      }
    }
  }

  Future<void> _shareStamp(PostageStamp stamp, Friend friend) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('shared_stamps').add({
        'senderId': user.uid,
        'senderEmail': user.email,
        'senderName': user.displayName ?? user.email?.split('@')[0] ?? 'Friend',
        'receiverId': friend.userId,
        'receiverEmail': friend.email,
        'frameShape': stamp.frameShape,
        'frameColor': stamp.frameColor.value,
        'frameThickness': stamp.frameThickness,
        'imageUrl': stamp.imageUrl,
        'imageFilter': stamp.imageFilter,
        'texts': stamp.texts.map((t) => t.toJson()).toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stamp shared with ${friend.email}!')),
        );
      }
    } catch (e) {
      print('Error sharing stamp: $e');
    }
  }

  void _showShareDialog(JournalEntry entry) {
    final noteController = TextEditingController();
    final nameController = TextEditingController();
    Set<Friend> selectedFriends = {};

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.65,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.share, color: Colors.black),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Share Journal',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Your name',
                          hintText: 'How should we introduce you?',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteController,
                        decoration: InputDecoration(
                          labelText: 'Add a note (optional)',
                          hintText: 'Hey, thought you\'d like this...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                if (selectedFriends.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.blue.shade50,
                    child: Row(
                      children: [
                        Text(
                          '${selectedFriends.length} friend(s) selected',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 1),
                Flexible(
                  child: _friends.isEmpty
                      ? Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No friends added yet',
                          style: GoogleFonts.poppins(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                      : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _friends.length,
                    itemBuilder: (context, index) {
                      final friend = _friends[index];
                      final isSelected = selectedFriends.contains(friend);
                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (val) {
                          setDialogState(() {
                            if (val == true) {
                              selectedFriends.add(friend);
                            } else {
                              selectedFriends.remove(friend);
                            }
                          });
                        },
                        title: Text(friend.name ?? friend.email),
                        subtitle: Text(friend.email),
                        secondary: CircleAvatar(
                          backgroundColor: Colors.grey.shade200,
                          child: Text(
                            friend.email[0].toUpperCase(),
                            style: const TextStyle(color: Colors.black),
                          ),
                        ),
                        activeColor: Colors.black,
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showAddFriendDialog();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(16),
                        ),
                        child: const Icon(Icons.person_add, color: Colors.white),
                      ),
                      const SizedBox(width: 20),
                      ElevatedButton(
                        onPressed: () {
                          if (nameController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter your name')),
                            );
                            return;
                          }
                          if (selectedFriends.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select at least one friend')),
                            );
                            return;
                          }
                          _shareJournalWithMultiple(
                            entry,
                            selectedFriends.toList(),
                            noteController.text,
                            nameController.text,
                          );
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(16),
                        ),
                        child: const Icon(Icons.send, color: Colors.white),
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
  }

  void _showAddFriendDialog() {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.person_add, color: Colors.black),
            const SizedBox(width: 12),
            Text('Add Friend', style: GoogleFonts.poppins()),
          ],
        ),
        content: TextField(
          controller: emailController,
          decoration: InputDecoration(
            labelText: 'Friend\'s Email',
            hintText: 'friend@example.com',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () async {
              if (emailController.text.isNotEmpty) {
                await _addFriend(emailController.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showMailbox() {
    _markJournalsAsRead();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MailboxPage(
          receivedJournals: _receivedJournals,
          sentJournals: _sentJournals,
          friends: _friends,
          onAddFriend: _showAddFriendDialog,
          onRemoveFriend: _removeFriend,
          onDeleteJournal: (journalId) async {
            try {
              await FirebaseFirestore.instance
                  .collection('shared_journals')
                  .doc(journalId)
                  .delete();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Journal deleted')),
                );
              }
            } catch (e) {
              print('Error deleting journal: $e');
            }
          },
        ),
      ),
    );
  }

  void _showStampGallery() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StampGalleryPage(
          myStamps: _myStamps,
          receivedStamps: _receivedStamps,
          friends: _friends,
          onCreateStamp: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const StampEditorPage(),
              ),
            );
            if (result != null && result is PostageStamp) {
              setState(() {
                _myStamps.add(result);
              });
              _saveStamps();
            }
          },
          onShareStamp: _shareStamp,
          onDeleteStamp: (stamp) {
            setState(() {
              _myStamps.removeWhere((s) => s.id == stamp.id);
            });
            _saveStamps();
          },
        ),
      ),
    );
  }

  void _createWelcomeJournal() {
    final welcomeEntry = JournalEntry(
      id: 'welcome_journal_001',
      date: DateTime.now(),
      title: 'The Art of Kindness',
      mood: 'Happy',
      entryText: '''Kindness is an art — painted not with brushes, but with hearts.

A smile, a gentle word, a helping hand… these are the strokes that color the world with hope.

Each act you share is a masterpiece — quiet, timeless, and deeply human.

Welcome to a space where kindness creates beauty that never fades. 💫

With warmth,
The Kind Team''',
      themeColorValue: 0xFFFADADD,
      isProtected: false,
    );

    setState(() {
      _journalEntries.add(welcomeEntry);
      _groupJournals();
    });
    _saveJournals();
  }

  void _groupJournals() {
    final grouped = <String, List<JournalEntry>>{};
    for (var entry in _journalEntries) {
      final monthYear = DateFormat('MMMM yyyy').format(entry.date);
      if (grouped[monthYear] == null) {
        grouped[monthYear] = [];
        if(_expandedMonths[monthYear] == null) {
          _expandedMonths[monthYear] = true;
        }
      }
      grouped[monthYear]!.add(entry);
    }
    setState(() {
      _groupedEntries = grouped;
    });
  }

  Future<void> _loadJournals() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isFirstJournalTime = prefs.getBool('isFirstJournalTime') ?? true;

    final journalStrings = prefs.getStringList('journalEntries') ?? [];
    _journalEntries = journalStrings
        .map((s) => JournalEntry.fromJson(jsonDecode(s)))
        .toList();

    if (isFirstJournalTime && _journalEntries.isEmpty) {
      _createWelcomeJournal();
      await prefs.setBool('isFirstJournalTime', false);
    } else {
      _journalEntries.sort((a, b) => b.date.compareTo(a.date));
      _groupJournals();
    }
  }

  Future<void> _saveJournals() async {
    final prefs = await SharedPreferences.getInstance();
    final journalStrings = _journalEntries.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('journalEntries', journalStrings);
  }

  void _startNewJournal() {
    setState(() {
      _newMood = null;
      _newThemeColor = const Color(0xFFFDF0D5);
      _newIsProtected = false;
      _selectedStamp = null;
      _titleController.clear();
      _entryController.clear();
      _protectionKeyController.clear();
      _pageController.animateToPage(1, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    });
  }

  void _saveNewJournal() {
    RibbonAnimationOverlay.show(context);

    final newEntry = JournalEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(),
      mood: _newMood ?? 'Neutral',
      title: _titleController.text.isNotEmpty ? _titleController.text : "Untitled Journal",
      entryText: _entryController.text,
      themeColorValue: _newThemeColor.value,
      isProtected: _newIsProtected,
      protectionKey: _newIsProtected ? _protectionKeyController.text : null,
      stampId: _selectedStamp?.id,
    );
    setState(() {
      _journalEntries.insert(0, newEntry);
      _groupJournals();
    });
    _saveJournals();

    Future.delayed(const Duration(milliseconds: 3000), () {
      _pageController.animateToPage(0, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    });
  }

  void _deleteJournal(String id) {
    setState(() {
      _journalEntries.removeWhere((entry) => entry.id == id);
      _groupJournals();
    });
    _saveJournals();
  }

  void _confirmDeleteJournal(JournalEntry entry) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFFF9F5F0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Delete Journal?"),
          content: const Text("This action cannot be undone."),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel", style: TextStyle(color: Colors.black))
            ),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  _deleteJournal(entry.id);
                  Navigator.pop(context);
                },
                child: const Text("Delete", style: TextStyle(color: Colors.white))
            )
          ],
        )
    );
  }

  void _viewJournal(JournalEntry entry) {
    if (entry.isProtected) {
      _promptForProtectionKey(entry);
    } else {
      PostageStamp? entryStamp;
      if (entry.stampId != null) {
        try {
          entryStamp = _myStamps.firstWhere((s) => s.id == entry.stampId);
        } catch (e) {
          try {
            entryStamp = _receivedStamps.firstWhere((s) => s.id == entry.stampId);
          } catch (e) {
            entryStamp = null;
          }
        }
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => JournalDetailPage(
            entry: entry,
            stamp: entryStamp,
          ),
        ),
      );
    }
  }

  void _promptForProtectionKey(JournalEntry entry) {
    final keyController = TextEditingController();
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFFF9F5F0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Journal Locked"),
          content: TextField(
            controller: keyController,
            obscureText: true,
            decoration: const InputDecoration(hintText: "Enter secret key"),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel", style: TextStyle(color: Colors.black))
            ),
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                onPressed: () {
                  if (keyController.text == entry.protectionKey) {
                    Navigator.pop(context);
                    PostageStamp? entryStamp;
                    if (entry.stampId != null) {
                      try {
                        entryStamp = _myStamps.firstWhere((s) => s.id == entry.stampId);
                      } catch (e) {
                        try {
                          entryStamp = _receivedStamps.firstWhere((s) => s.id == entry.stampId);
                        } catch (e) {
                          entryStamp = null;
                        }
                      }
                    }
                    Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => JournalDetailPage(entry: entry, stamp: entryStamp))
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Incorrect key.")));
                  }
                },
                child: const Text("Unlock", style: TextStyle(color: Colors.white))
            )
          ],
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F5F0),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildJournalListPage(),
          _buildMoodPage(),
          _buildJournalEditorPage(backgroundColor: _newThemeColor),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _bannerStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 65,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12, left: 24, right: 24),
            decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12)
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        var bannerData = snapshot.data!.data() as Map<String, dynamic>;
        bool isVisible = bannerData['isVisible'] ?? false;
        String? imageUrl = bannerData['imageUrl'];

        if (isVisible && imageUrl != null) {
          return GestureDetector(
            onTap: () async {
              final urlString = bannerData['targetUrl'];
              if (urlString != null && urlString.isNotEmpty) {
                final url = Uri.parse(urlString);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              }
            },
            child: Container(
              height: 65,
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12, left: 24, right: 24),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
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
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildJournalListPage() {
    final monthKeys = _groupedEntries.keys.toList();

    return SafeArea(
      child: Stack(
        children: [
          Column(
            children: [
              Container(
                color: const Color(0xFFF9F5F0),
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'All Journals',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _launchBuyMeACoffee,
                          icon: SizedBox(
                            width: 36,
                            height: 36,
                            child: ClipOval(
                              child: Image.asset('assets/buymecoffee.png'),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.receipt_long,
                              color: Colors.white,
                            ),
                          ),
                          onPressed: _showStampGallery,
                        ),
                        Stack(
                          children: [
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.mail_outline,
                                  color: Colors.white,
                                ),
                              ),
                              onPressed: _showMailbox,
                            ),
                            if (_unreadCount > 0)
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$_unreadCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildBanner(),
              Expanded(
                child: _groupedEntries.isEmpty
                    ? Center(child: Text("No journals yet. Tap the edit button to start!", style: GoogleFonts.poppins(color: Colors.grey)))
                    : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                  itemCount: monthKeys.length,
                  itemBuilder: (context, index) {
                    final monthKey = monthKeys[index];
                    final entriesForMonth = _groupedEntries[monthKey]!;
                    final isExpanded = _expandedMonths[monthKey] ?? true;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _expandedMonths[monthKey] = !isExpanded;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    monthKey,
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                AnimatedRotation(
                                  turns: isExpanded ? 0 : -0.25,
                                  duration: const Duration(milliseconds: 300),
                                  child: const Icon(Icons.keyboard_arrow_down_rounded),
                                ),
                              ],
                            ),
                          ),
                        ),
                        AnimatedCrossFade(
                          firstChild: Column(
                            children: entriesForMonth.map((entry) => _buildJournalCard(entry)).toList(),
                          ),
                          secondChild: Container(),
                          crossFadeState: isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                          duration: const Duration(milliseconds: 300),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 24,
            right: 24,
            child: FloatingActionButton(
              onPressed: _startNewJournal,
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: const CircleBorder(),
              child: const Icon(Icons.edit_outlined),
            ),
          ),
        ],
      ),
    );
  }


  String _getMoodEmoji(String mood) {
    final standardMoods = ['awesome', 'happy', 'sad'];
    if(standardMoods.contains(mood.toLowerCase())) {
      switch (mood.toLowerCase()) {
        case 'awesome': return '🥳';
        case 'happy': return '😊';
        case 'sad': return '😢';
      }
    }
    return '✨';
  }

  Widget _buildJournalCard(JournalEntry entry) {
    final bool isWelcomeJournal = entry.id == 'welcome_journal_001';

    return GestureDetector(
      onTap: () => _viewJournal(entry),
      onLongPress: () {
        if (!isWelcomeJournal) _confirmDeleteJournal(entry);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: isWelcomeJournal
            ? const EdgeInsets.symmetric(horizontal: 20, vertical: 30)
            : const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isWelcomeJournal ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFADADD),
              const Color(0xFFFFE6C9).withOpacity(0.8),
            ],
          ) : null,
          color: !isWelcomeJournal ? Color(entry.themeColorValue) : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isWelcomeJournal ? [
            BoxShadow(
              color: const Color(0xFFFADADD).withOpacity(0.5),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    DateFormat('d MMMM yyyy').format(entry.date),
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Colors.black.withOpacity(0.8)
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (entry.isProtected)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Icon(Icons.lock_outline, size: 16, color: Colors.black.withOpacity(0.6)),
                      ),
                    if (isWelcomeJournal)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Icon(Icons.auto_awesome, size: 16, color: Colors.black.withOpacity(0.7)),
                      ),
                    if (!isWelcomeJournal)
                      IconButton(
                        icon: Icon(Icons.share_outlined, size: 18, color: Colors.black.withOpacity(0.7)),
                        onPressed: () => _showShareDialog(entry),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              entry.title,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.black
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: [
                _buildTag('Mood: ${entry.mood} ${_getMoodEmoji(entry.mood)}', isSpecial: isWelcomeJournal),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, {bool isSpecial = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isSpecial
            ? Colors.white.withOpacity(0.5)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.black.withOpacity(0.8)
        ),
      ),
    );
  }

  Widget _buildMoodPage() {
    final List<Color> themeColors = [
      const Color(0xFFFDF0D5), const Color(0xFFD7E3FC), const Color(0xFFF9D6C4),
      const Color(0xFFDCDCDC), const Color(0xFFD1E7DD), const Color(0xFFF8D7DA),
      const Color(0xFFCFBCF0), const Color(0xFFE2F0CB),
    ];

    final allStamps = [..._myStamps, ..._receivedStamps];

    return Scaffold(
      backgroundColor: const Color(0xFFF9F5F0),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios),
                      onPressed: () => _pageController.animateToPage(0, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'How are you\nfeeling today?',
                    style: GoogleFonts.playfairDisplay(fontSize: 32, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _titleController,
                    style: GoogleFonts.poppins(fontSize: 16),
                    decoration: InputDecoration(
                      labelText: "Title for your journal entry",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSelector("Today's mood", _newMood ?? 'None', ['Awesome', 'Happy', 'Sad', 'Other...']),
                  const SizedBox(height: 24),
                  Text("Select a Theme", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: themeColors.map((color) => GestureDetector(
                      onTap: () => setState(() => _newThemeColor = color),
                      child: Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: _newThemeColor == color ? Colors.black : Colors.transparent,
                                width: 2
                            )
                        ),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 24),
                  if (allStamps.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Select a Stamp", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500)),
                        if (_selectedStamp != null)
                          TextButton(
                            onPressed: () => setState(() => _selectedStamp = null),
                            child: const Text('Clear', style: TextStyle(color: Colors.black)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 90,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: allStamps.length,
                        itemBuilder: (context, index) {
                          final stamp = allStamps[index];
                          final isSelected = _selectedStamp?.id == stamp.id;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedStamp = stamp),
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isSelected ? Colors.black : Colors.grey.shade300,
                                  width: isSelected ? 3 : 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: StampWidget(stamp: stamp, width: 60, height: 70),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text("Journal Protected", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500)),
                    value: _newIsProtected,
                    onChanged: (val) => setState(() => _newIsProtected = val),
                    activeColor: Colors.black,
                  ),
                  if(_newIsProtected)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: TextField(
                        controller: _protectionKeyController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: "Enter a secret key",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
            Positioned(
              bottom: 24,
              right: 24,
              child: FloatingActionButton(
                onPressed: () {
                  if (_newMood != null) {
                    if (_newIsProtected && _protectionKeyController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Please enter a secret key for protected journal.')));
                      return;
                    }
                    if (_titleController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Please enter a title for your journal.')));
                      return;
                    }
                    _pageController.animateToPage(2, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Please select your mood.')));
                  }
                },
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: const CircleBorder(),
                child: const Icon(Icons.arrow_forward_ios, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelector(String label, String value, List<String> options) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500)),
        ),
        GestureDetector(
          onTap: () => _showOptionsSheet(label, options),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _promptForCustomMood() {
    final moodController = TextEditingController();
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFFF9F5F0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Your Mood"),
          content: TextField(
            controller: moodController,
            decoration: const InputDecoration(hintText: "How are you feeling?"),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel", style: TextStyle(color: Colors.black))
            ),
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                onPressed: () {
                  if (moodController.text.isNotEmpty) {
                    setState(() => _newMood = moodController.text);
                  }
                  Navigator.pop(context);
                },
                child: const Text("Done", style: TextStyle(color: Colors.white))
            )
          ],
        )
    );
  }

  void _showOptionsSheet(String label, List<String> options) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF9F5F0),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: options.map((option) => ListTile(
                    title: Text(
                      option,
                      style: GoogleFonts.poppins(fontSize: 15),
                      textAlign: TextAlign.center,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      if (option == 'Other...') {
                        _promptForCustomMood();
                      } else {
                        setState(() {
                          _newMood = option;
                        });
                      }
                    },
                  )).toList(),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildJournalEditorPage({required Color backgroundColor}) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios),
                      onPressed: () => _pageController.animateToPage(1, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut),
                    ),
                    if (_selectedStamp != null)
                      StampWidget(stamp: _selectedStamp!, width: 50, height: 60),
                  ],
                ),
              ),
              Text(
                DateFormat('d MMMM yyyy').format(DateTime.now()),
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  _titleController.text,
                  style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600),
                ),
              ),
              Wrap(
                spacing: 8.0,
                children: [
                  _buildTag('Mood: ${_newMood ?? ''} ${_getMoodEmoji(_newMood ?? '')}'),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                  "What are you grateful for today?",
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TextField(
                  controller: _entryController,
                  maxLines: null,
                  expands: true,
                  style: GoogleFonts.poppins(fontSize: 15, height: 1.8),
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration.collapsed(
                    hintText: "Highlight of the Day...\n\nAs we sat around the dinner table...",
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: _saveNewJournal,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
                  ),
                  child: const Text('Save Journal'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
// ========================= WIDGETS AND OTHER PAGES =========================

// ... (Rest of the file is unchanged, including all the classes below)

// ========================= STAMP WIDGET =========================

class StampWidget extends StatelessWidget {
  final PostageStamp stamp;
  final double width;
  final double height;

  const StampWidget({
    super.key,
    required this.stamp,
    this.width = 80,
    this.height = 100,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: StampFramePainter(
        frameShape: stamp.frameShape,
        frameColor: stamp.frameColor,
        strokeWidth: stamp.frameThickness,
      ),
      child: ClipPath(
        clipper: StampClipper(frameShape: stamp.frameShape),
        child: Container(
          width: width,
          height: height,
          color: stamp.frameColor.withOpacity(0.3),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (stamp.imagePath != null || stamp.imageUrl != null)
                _buildImageWithFilter(),
              ..._buildTextWidgets(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageWithFilter() {
    Widget imageWidget;

    if (stamp.imagePath != null) {
      imageWidget = Image.file(
        File(stamp.imagePath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey.shade300,
          child: Icon(Icons.image_not_supported, size: width * 0.3, color: Colors.grey.shade500),
        ),
      );
    } else if (stamp.imageUrl != null) {
      imageWidget = Image.network(
        stamp.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey.shade300,
          child: Icon(Icons.image_not_supported, size: width * 0.3, color: Colors.grey.shade500),
        ),
      );
    } else {
      return Container();
    }

    if (stamp.imageFilter != null && stamp.imageFilter!.isNotEmpty) {
      return ColorFiltered(
        colorFilter: _getColorFilter(stamp.imageFilter!),
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  ColorFilter _getColorFilter(String filterName) {
    switch (filterName) {
      case 'Grayscale':
        return const ColorFilter.matrix([
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case 'Sepia':
        return const ColorFilter.matrix([
          0.393, 0.769, 0.189, 0, 0,
          0.349, 0.686, 0.168, 0, 0,
          0.272, 0.534, 0.131, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case 'Vintage':
        return const ColorFilter.matrix([
          0.6, 0.3, 0.3, 0, 0,
          0.2, 0.7, 0.2, 0, 0,
          0.2, 0.2, 0.5, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case 'Cool':
        return const ColorFilter.matrix([
          0.9, 0, 0, 0, 0,
          0, 0.9, 0, 0, 0,
          0, 0, 1.1, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case 'Warm':
        return const ColorFilter.matrix([
          1.1, 0, 0, 0, 0,
          0, 1.0, 0, 0, 0,
          0, 0, 0.9, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      default:
        return const ColorFilter.mode(Colors.transparent, BlendMode.multiply);
    }
  }

  List<Widget> _buildTextWidgets() {
    return stamp.texts.map((text) {
      return Positioned(
        left: (text.position.dx / 100) * width,
        top: (text.position.dy / 100) * height,
        child: Text(
          text.text,
          style: GoogleFonts.getFont(
            text.fontFamily,
            fontSize: (text.fontSize / 100) * height,
            color: text.color,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }).toList();
  }
}

class StampClipper extends CustomClipper<Path> {
  final String frameShape;

  StampClipper({required this.frameShape});

  @override
  Path getClip(Size size) {
    switch (frameShape) {
      case 'classic':
        return _createClassicPath(size);
      case 'zigzag':
        return _createZigzagPath(size);
      case 'wavy':
        return _createWavyPath(size);
      case 'rounded':
        return _createRoundedPath(size);
      case 'deckled':
        return _createDeckledPath(size);
      case 'postal':
        return _createPostalPath(size);
      default:
        return Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    }
  }

  Path _createClassicPath(Size size) {
    final path = Path();
    double toothWidth = size.width / 15;
    double toothHeight = size.height / 20;
    double toothRadius = toothWidth / 2.5;

    path.moveTo(0, toothRadius);
    for (double i = 0; i < size.width; i += toothWidth) {
      path.arcTo(Rect.fromCircle(center: Offset(i + toothWidth / 2, 0), radius: toothRadius), math.pi, math.pi, false);
    }
    path.lineTo(size.width, 0);
    for (double i = 0; i < size.height; i += toothHeight) {
      path.arcTo(Rect.fromCircle(center: Offset(size.width, i + toothHeight / 2), radius: toothRadius), 1.5 * math.pi, math.pi, false);
    }
    path.lineTo(size.width, size.height);
    for (double i = size.width; i > 0; i -= toothWidth) {
      path.arcTo(Rect.fromCircle(center: Offset(i - toothWidth / 2, size.height), radius: toothRadius), 0, math.pi, false);
    }
    path.lineTo(0, size.height);
    for (double i = size.height; i > 0; i -= toothHeight) {
      path.arcTo(Rect.fromCircle(center: Offset(0, i - toothHeight / 2), radius: toothRadius), 0.5 * math.pi, math.pi, false);
    }
    path.close();
    return path;
  }

  Path _createZigzagPath(Size size) {
    final path = Path();
    const double toothHeight = 4.0;
    int numTeethX = (size.width / (toothHeight * 1.5)).floor();
    double toothWidthX = size.width / numTeethX;
    int numTeethY = (size.height / (toothHeight * 1.5)).floor();
    double toothWidthY = size.height / numTeethY;

    path.moveTo(0, 0);
    for (int i = 0; i < numTeethX; i++) {
      path.lineTo(i * toothWidthX + toothWidthX / 2, -toothHeight);
      path.lineTo((i + 1) * toothWidthX, 0);
    }
    for (int i = 0; i < numTeethY; i++) {
      path.lineTo(size.width + toothHeight, i * toothWidthY + toothWidthY / 2);
      path.lineTo(size.width, (i + 1) * toothWidthY);
    }
    for (int i = numTeethX; i > 0; i--) {
      path.lineTo(i * toothWidthX - toothWidthX / 2, size.height + toothHeight);
      path.lineTo((i - 1) * toothWidthX, size.height);
    }
    for (int i = numTeethY; i > 0; i--) {
      path.lineTo(-toothHeight, i * toothWidthY - toothWidthY / 2);
      path.lineTo(0, (i - 1) * toothWidthY);
    }
    path.close();
    return path;
  }

  Path _createWavyPath(Size size) {
    final path = Path();
    const double waveHeight = 4.0;
    const int wavesX = 10;
    const int wavesY = 12;

    path.moveTo(0, 0);
    for (int i = 0; i < wavesX; i++) {
      path.quadraticBezierTo(size.width * (i + 0.5) / wavesX, (i.isEven) ? -waveHeight : waveHeight, size.width * (i + 1) / wavesX, 0);
    }
    for (int i = 0; i < wavesY; i++) {
      path.quadraticBezierTo(size.width + ((i.isEven) ? waveHeight : -waveHeight), size.height * (i + 0.5) / wavesY, size.width, size.height * (i + 1) / wavesY);
    }
    for (int i = wavesX; i > 0; i--) {
      path.quadraticBezierTo(size.width * (i - 0.5) / wavesX, size.height + ((i.isEven) ? waveHeight : -waveHeight), size.width * (i - 1) / wavesX, size.height);
    }
    for (int i = wavesY; i > 0; i--) {
      path.quadraticBezierTo(((i.isEven) ? -waveHeight : waveHeight), size.height * (i - 0.5) / wavesY, 0, size.height * (i - 1) / wavesY);
    }
    path.close();
    return path;
  }

  Path _createRoundedPath(Size size) {
    return Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(8)));
  }

  Path _createDeckledPath(Size size) {
    final path = Path();
    final random = math.Random(1);
    const double deviation = 2.5;

    path.moveTo(0, 0);
    for (double x = 0; x < size.width; x += 5) {
      path.lineTo(x, random.nextDouble() * deviation);
    }
    path.lineTo(size.width, 0);
    for (double y = 0; y < size.height; y += 5) {
      path.lineTo(size.width - random.nextDouble() * deviation, y);
    }
    path.lineTo(size.width, size.height);
    for (double x = size.width; x > 0; x -= 5) {
      path.lineTo(x, size.height - random.nextDouble() * deviation);
    }
    path.lineTo(0, size.height);
    for (double y = size.height; y > 0; y -= 5) {
      path.lineTo(random.nextDouble() * deviation, y);
    }
    path.close();
    return path;
  }

  Path _createPostalPath(Size size) {
    final path = Path();
    const int waves = 5;
    final double waveHeight = size.height / waves;
    final double amplitude = size.width * 0.1;

    path.moveTo(-amplitude, 0);
    for (int i = 0; i < waves; i++) {
      path.quadraticBezierTo(
        i.isEven ? amplitude : -amplitude,
        i * waveHeight + waveHeight / 2,
        0,
        (i + 1) * waveHeight,
      );
    }
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(StampClipper oldClipper) => oldClipper.frameShape != frameShape;
}

class StampFramePainter extends CustomPainter {
  final String frameShape;
  final Color frameColor;
  final double strokeWidth;

  StampFramePainter({
    required this.frameShape,
    required this.frameColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = frameColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final clipper = StampClipper(frameShape: frameShape);
    canvas.drawPath(clipper.getClip(size), paint);
  }

  @override
  bool shouldRepaint(StampFramePainter oldDelegate) =>
      oldDelegate.frameShape != frameShape || oldDelegate.frameColor != frameColor || oldDelegate.strokeWidth != strokeWidth;
}

// ========================= STAMP GALLERY PAGE =========================

class StampGalleryPage extends StatefulWidget {
  final List<PostageStamp> myStamps;
  final List<PostageStamp> receivedStamps;
  final List<Friend> friends;
  final VoidCallback onCreateStamp;
  final Function(PostageStamp, Friend) onShareStamp;
  final Function(PostageStamp) onDeleteStamp;

  const StampGalleryPage({
    super.key,
    required this.myStamps,
    required this.receivedStamps,
    required this.friends,
    required this.onCreateStamp,
    required this.onShareStamp,
    required this.onDeleteStamp,
  });

  @override
  State<StampGalleryPage> createState() => _StampGalleryPageState();
}

class _StampGalleryPageState extends State<StampGalleryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showStampOptionsDialog(PostageStamp stamp, bool isMyStamp) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StampWidget(stamp: stamp, width: 100, height: 130),
              const SizedBox(height: 20),
              if (isMyStamp) ...[
                ListTile(
                  leading: const Icon(Icons.share, color: Colors.black),
                  title: const Text('Share Stamp'),
                  onTap: () {
                    Navigator.pop(context);
                    _showShareStampDialog(stamp);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.black),
                  title: const Text('Delete Stamp'),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteStamp(stamp);
                  },
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Received from ${stamp.sharedBy}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteStamp(PostageStamp stamp) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Stamp?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              setState(() {
                widget.onDeleteStamp(stamp);
              });
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showShareStampDialog(PostageStamp stamp) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.send, color: Colors.black),
                    const SizedBox(width: 12),
                    Text(
                      'Share Stamp',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: widget.friends.isEmpty
                    ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No friends added yet',
                          style: GoogleFonts.poppins(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                )
                    : ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.friends.length,
                  itemBuilder: (context, index) {
                    final friend = widget.friends[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey.shade200,
                        child: Text(
                          friend.email[0].toUpperCase(),
                          style: const TextStyle(color: Colors.black),
                        ),
                      ),
                      title: Text(friend.name ?? friend.email),
                      subtitle: Text(friend.email),
                      trailing: IconButton(
                        icon: const Icon(Icons.send, color: Colors.black),
                        onPressed: () {
                          widget.onShareStamp(stamp, friend);
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.black)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F5F0),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          'Postage Stamps',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey.shade400,
          tabs: const [
            Tab(icon: Icon(Icons.collections), text: 'My Stamps'),
            Tab(icon: Icon(Icons.card_giftcard), text: 'Received'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // My Stamps
          widget.myStamps.isEmpty
              ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No stamps created yet',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: widget.onCreateStamp,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Create Stamp', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          )
              : GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.7,
            ),
            itemCount: widget.myStamps.length,
            itemBuilder: (context, index) {
              final stamp = widget.myStamps[index];
              return GestureDetector(
                onLongPress: () => _showStampOptionsDialog(stamp, true),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      StampWidget(stamp: stamp, width: 100, height: 130),
                      const SizedBox(height: 12),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          DateFormat('MMM d, yyyy').format(stamp.createdAt),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Received Stamps
          widget.receivedStamps.isEmpty
              ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.card_giftcard_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No stamps received yet',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          )
              : GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.7,
            ),
            itemCount: widget.receivedStamps.length,
            itemBuilder: (context, index) {
              final stamp = widget.receivedStamps[index];
              return GestureDetector(
                onLongPress: () => _showStampOptionsDialog(stamp, false),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        stamp.frameColor.withOpacity(0.3),
                        Colors.white,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: stamp.frameColor.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: StampWidget(stamp: stamp, width: 100, height: 130),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.card_giftcard, size: 16, color: Colors.grey.shade700),
                            const SizedBox(height: 4),
                            Text(
                              'From ${stamp.sharedBy ?? 'Unknown'}',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: widget.onCreateStamp,
        backgroundColor: Colors.black,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// ========================= STAMP EDITOR PAGE =========================

class StampEditorPage extends StatefulWidget {
  const StampEditorPage({super.key});

  @override
  State<StampEditorPage> createState() => _StampEditorPageState();
}

class _StampEditorPageState extends State<StampEditorPage> {
  String _selectedFrame = 'classic';
  Color _selectedColor = const Color(0xFFE8B4B8);
  double _frameThickness = 2.0;
  File? _selectedImage;
  String? _selectedFilter;
  List<StampText> _texts = [];
  int? _selectedTextIndex;

  final List<Map<String, dynamic>> _frameTemplates = [
    {'shape': 'classic', 'icon': Icons.grid_on, 'name': 'Classic'},
    {'shape': 'zigzag', 'icon': Icons.show_chart, 'name': 'Zigzag'},
    {'shape': 'wavy', 'icon': Icons.waves, 'name': 'Wavy'},
    {'shape': 'rounded', 'icon': Icons.crop_din, 'name': 'Rounded'},
    {'shape': 'deckled', 'icon': Icons.document_scanner_outlined, 'name': 'Deckled'},
    {'shape': 'postal', 'icon': Icons.local_post_office_outlined, 'name': 'Postal'},
  ];

  final List<String> _filters = [
    'None',
    'Grayscale',
    'Sepia',
    'Vintage',
    'Cool',
    'Warm',
  ];

  final List<String> _fontFamilies = [
    'Poppins',
    'Playfair Display',
    'Roboto',
    'Lato',
    'Oswald',
    'Pacifico',
    'Lobster',
    'Dancing Script',
  ];

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  void _addText() {
    setState(() {
      final newText = StampText(
        text: 'Text',
        position: const Offset(30, 30),
        fontFamily: 'Poppins',
        fontSize: 16,
        color: Colors.black,
      );
      _texts.add(newText);
      _selectedTextIndex = _texts.length - 1;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_texts.isNotEmpty) {
        _showTextEditor(_texts.length - 1);
      }
    });
  }

  void _showCustomColorPicker() {
    Color tempColor = _selectedColor;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Custom Color', style: GoogleFonts.poppins()),
        content: StatefulBuilder(
          builder: (context, setDialogState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hue', style: GoogleFonts.poppins(fontSize: 14)),
                    Slider(
                      value: HSVColor.fromColor(tempColor).hue,
                      min: 0,
                      max: 360,
                      activeColor: Colors.black,
                      onChanged: (value) {
                        setDialogState(() {
                          final hsv = HSVColor.fromColor(tempColor);
                          tempColor = hsv.withHue(value).toColor();
                        });
                      },
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Saturation', style: GoogleFonts.poppins(fontSize: 14)),
                    Slider(
                      value: HSVColor.fromColor(tempColor).saturation,
                      min: 0,
                      max: 1,
                      activeColor: Colors.black,
                      onChanged: (value) {
                        setDialogState(() {
                          final hsv = HSVColor.fromColor(tempColor);
                          tempColor = hsv.withSaturation(value).toColor();
                        });
                      },
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lightness', style: GoogleFonts.poppins(fontSize: 14)),
                    Slider(
                      value: HSVColor.fromColor(tempColor).value,
                      min: 0,
                      max: 1,
                      activeColor: Colors.black,
                      onChanged: (value) {
                        setDialogState(() {
                          final hsv = HSVColor.fromColor(tempColor);
                          tempColor = hsv.withValue(value).toColor();
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: tempColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              setState(() {
                _selectedColor = tempColor;
              });
              Navigator.pop(context);
            },
            child: const Text('Apply', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _saveStamp() {
    if (_texts.isEmpty && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add some content to your stamp')),
      );
      return;
    }

    final stamp = PostageStamp(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      frameShape: _selectedFrame,
      frameColor: _selectedColor,
      frameThickness: _frameThickness,
      imagePath: _selectedImage?.path,
      imageFilter: _selectedFilter,
      texts: _texts,
      createdAt: DateTime.now(),
    );

    Navigator.pop(context, stamp);
  }

  void _showTextEditor(int index) {
    if (index < 0 || index >= _texts.length) return;

    final text = _texts[index];
    final textController = TextEditingController(text: text.text);
    String selectedFont = text.fontFamily;
    Color selectedColor = text.color;
    double selectedSize = text.fontSize;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF9F5F0),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Edit Text',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.black),
                      onPressed: () {
                        setState(() {
                          _texts.removeAt(index);
                          _selectedTextIndex = null;
                        });
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: textController,
                  decoration: InputDecoration(
                    labelText: 'Text',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _texts[index].text = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Text('Font Family', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _fontFamilies.length,
                    itemBuilder: (context, fontIndex) {
                      final font = _fontFamilies[fontIndex];
                      final isSelected = selectedFont == font;
                      return GestureDetector(
                        onTap: () {
                          setSheetState(() {
                            selectedFont = font;
                          });
                          setState(() {
                            _texts[index].fontFamily = font;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.black : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Center(
                            child: Text(
                              font,
                              style: GoogleFonts.getFont(
                                font,
                                color: isSelected ? Colors.white : Colors.black,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text('Font Size', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                Slider(
                  value: selectedSize,
                  min: 12,
                  max: 32,
                  divisions: 20,
                  label: selectedSize.round().toString(),
                  activeColor: Colors.black,
                  onChanged: (value) {
                    setSheetState(() {
                      selectedSize = value;
                    });
                    setState(() {
                      _texts[index].fontSize = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Text('Text Color', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Colors.black,
                    Colors.white,
                    Colors.red,
                    Colors.blue,
                    Colors.green,
                    Colors.purple,
                    Colors.orange,
                    Colors.pink,
                  ].map((color) => GestureDetector(
                    onTap: () {
                      setSheetState(() {
                        selectedColor = color;
                      });
                      setState(() {
                        _texts[index].color = color;
                      });
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selectedColor == color ? Colors.black : Colors.grey.shade300,
                          width: selectedColor == color ? 3 : 1,
                        ),
                      ),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Done', style: TextStyle(color: Colors.white)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F5F0),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          'Create Stamp',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _saveStamp,
            child: const Text(
              'Save',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(20, 40, 20, 20),
              height: 400,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: GestureDetector(
                  onTapDown: (details) {
                    setState(() {
                      _selectedTextIndex = null;
                    });
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      StampWidget(
                        stamp: PostageStamp(
                          id: 'preview',
                          frameShape: _selectedFrame,
                          frameColor: _selectedColor,
                          frameThickness: _frameThickness,
                          imagePath: _selectedImage?.path,
                          imageFilter: _selectedFilter,
                          texts: [],
                          createdAt: DateTime.now(),
                        ),
                        width: 140,
                        height: 180,
                      ),
                      ..._texts.asMap().entries.map((entry) {
                        final index = entry.key;
                        final text = entry.value;
                        final isSelected = _selectedTextIndex == index;

                        return Positioned(
                          left: (text.position.dx / 100) * 140,
                          top: (text.position.dy / 100) * 180,
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                _selectedTextIndex = index;
                                final newDx = ((text.position.dx / 100) * 140 + details.delta.dx).clamp(0.0, 140.0);
                                final newDy = ((text.position.dy / 100) * 180 + details.delta.dy).clamp(0.0, 180.0);
                                text.position = Offset(
                                  (newDx / 140) * 100,
                                  (newDy / 180) * 100,
                                );
                              });
                            },
                            onTap: () {
                              setState(() {
                                _selectedTextIndex = index;
                              });
                              _showTextEditor(index);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isSelected ? Colors.blue : Colors.transparent,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                text.text,
                                style: GoogleFonts.getFont(
                                  text.fontFamily,
                                  fontSize: (text.fontSize / 100) * 180,
                                  color: text.color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Frame Style',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _frameTemplates.length,
                      itemBuilder: (context, index) {
                        final template = _frameTemplates[index];
                        final isSelected = _selectedFrame == template['shape'];
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedFrame = template['shape'];
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(12),
                            width: 90,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.black : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? Colors.black : Colors.grey.shade300,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  template['icon'],
                                  color: isSelected ? Colors.white : Colors.black,
                                  size: 28,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  template['name'],
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: isSelected ? Colors.white : Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Frame Thickness',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Slider(
                    value: _frameThickness,
                    min: 1.0,
                    max: 5.0,
                    divisions: 8,
                    label: _frameThickness.toStringAsFixed(1),
                    activeColor: Colors.black,
                    onChanged: (value) {
                      setState(() {
                        _frameThickness = value;
                      });
                    },
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Frame Color',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _showCustomColorPicker,
                        icon: const Icon(Icons.palette, color: Colors.black, size: 16),
                        label: const Text('Custom', style: TextStyle(color: Colors.black)),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.grey.shade200,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      const Color(0xFFE8B4B8),
                      const Color(0xFFB4C7E7),
                      const Color(0xFFC9E4CA),
                      const Color(0xFFFFF4E0),
                      const Color(0xFFE0BBE4),
                      const Color(0xFFFFD3B6),
                      const Color(0xFFD5AAFF),
                      const Color(0xFFA8E6CF),
                    ].map((color) => GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColor = color;
                        });
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _selectedColor == color ? Colors.black : Colors.grey.shade300,
                            width: _selectedColor == color ? 3 : 1,
                          ),
                        ),
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            if (_selectedImage != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Image Filter',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _filters.length,
                        itemBuilder: (context, index) {
                          final filter = _filters[index];
                          final isSelected = _selectedFilter == filter || (_selectedFilter == null && filter == 'None');
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedFilter = filter == 'None' ? null : filter;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.black : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Center(
                                child: Text(
                                  filter,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: isSelected ? Colors.white : Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image, color: Colors.white),
                    label: Text(
                      _selectedImage == null ? 'Add Image' : 'Change Image',
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _addText,
                    icon: const Icon(Icons.text_fields, color: Colors.black),
                    label: const Text(
                      'Add Text',
                      style: TextStyle(color: Colors.black),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_texts.isNotEmpty)
                    Text(
                      'Drag text to reposition • Tap to edit',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========================= MAILBOX PAGE =========================

class MailboxPage extends StatefulWidget {
  final List<JournalEntry> receivedJournals;
  final List<JournalEntry> sentJournals;
  final List<Friend> friends;
  final VoidCallback onAddFriend;
  final Function(Friend) onRemoveFriend;
  final Function(String) onDeleteJournal;

  const MailboxPage({
    super.key,
    required this.receivedJournals,
    required this.sentJournals,
    required this.friends,
    required this.onAddFriend,
    required this.onRemoveFriend,
    required this.onDeleteJournal,
  });

  @override
  State<MailboxPage> createState() => _MailboxPageState();
}

class _MailboxPageState extends State<MailboxPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<JournalEntry> _localReceivedJournals;
  late List<JournalEntry> _localSentJournals;
  late List<Friend> _localFriends;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _localReceivedJournals = List.from(widget.receivedJournals);
    _localSentJournals = List.from(widget.sentJournals);
    _localFriends = List.from(widget.friends);
  }

  @override
  void didUpdateWidget(MailboxPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.receivedJournals, oldWidget.receivedJournals) ||
        !listEquals(widget.sentJournals, oldWidget.sentJournals) ||
        !listEquals(widget.friends, oldWidget.friends)) {
      setState(() {
        _localReceivedJournals = List.from(widget.receivedJournals);
        _localSentJournals = List.from(widget.sentJournals);
        _localFriends = List.from(widget.friends);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _deleteReceivedJournal(String journalId) async {
    setState(() {
      _localReceivedJournals.removeWhere((j) => j.id == journalId);
    });
    widget.onDeleteJournal(journalId);
  }

  void _deleteSentJournal(String journalId) async {
    setState(() {
      _localSentJournals.removeWhere((j) => j.id == journalId);
    });
    widget.onDeleteJournal(journalId);
  }

  void _confirmDeleteJournal(JournalEntry journal, bool isSent) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Journal?'),
        content: Text(isSent
            ? 'Remove this journal from sent items?'
            : 'Remove this journal from your inbox?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              if (isSent) {
                _deleteSentJournal(journal.id);
              } else {
                _deleteReceivedJournal(journal.id);
              }
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveFriend(Friend friend) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Friend?'),
        content: Text('Remove ${friend.email} from your friends list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              setState(() {
                _localFriends.removeWhere((f) => f.userId == friend.userId);
              });
              widget.onRemoveFriend(friend);
              Navigator.pop(context);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F5F0),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          'Journal Mailbox',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey.shade400,
          tabs: const [
            Tab(icon: Icon(Icons.inbox), text: 'Received'),
            Tab(icon: Icon(Icons.send), text: 'Sent'),
            Tab(icon: Icon(Icons.people), text: 'Friends'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // RECEIVED JOURNALS TAB
          _localReceivedJournals.isEmpty
              ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mail_outline, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No journals received yet',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _localReceivedJournals.length,
            itemBuilder: (context, index) {
              final journal = _localReceivedJournals[index];
              return _buildReceivedJournalCard(journal);
            },
          ),

          // SENT JOURNALS TAB
          _localSentJournals.isEmpty
              ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.send_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No journals sent yet',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _localSentJournals.length,
            itemBuilder: (context, index) {
              final journal = _localSentJournals[index];
              return _buildSentJournalCard(journal);
            },
          ),

          // FRIENDS TAB
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: widget.onAddFriend,
                    icon: const Icon(Icons.person_add, color: Colors.white),
                    label: const Text('Add Friend', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _localFriends.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No friends added yet',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _localFriends.length,
                  itemBuilder: (context, index) {
                    final friend = _localFriends[index];
                    return GestureDetector(
                      onLongPress: () => _confirmRemoveFriend(friend),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey.shade200,
                            child: Text(
                              friend.email[0].toUpperCase(),
                              style: const TextStyle(color: Colors.black),
                            ),
                          ),
                          title: Text(friend.name ?? friend.email),
                          subtitle: Text(friend.email),
                          trailing: Text(
                            DateFormat('MMM d').format(friend.addedAt),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReceivedJournalCard(JournalEntry journal) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JournalDetailPage(
              entry: journal,
              stamp: null,
            ),
          ),
        );
      },
      onLongPress: () => _confirmDeleteJournal(journal, false),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(journal.themeColorValue),
              Color(journal.themeColorValue).withOpacity(0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Color(journal.themeColorValue).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 45,
                      height: 45,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          journal.sharedByEmail?[0].toUpperCase() ?? '?',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            journal.sharedBy ?? 'Unknown',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            DateFormat('MMM d at h:mm a').format(journal.sharedAt!),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.auto_stories,
                    size: 20,
                    color: Colors.black.withOpacity(0.7),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      journal.title,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
              if (journal.sharedNote != null && journal.sharedNote!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.black.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.message,
                        size: 18,
                        color: Colors.black.withOpacity(0.6),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          journal.sharedNote!,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: Colors.black.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Tap to read',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.black.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: Colors.black.withOpacity(0.6),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Long press to delete',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.black.withOpacity(0.6),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSentJournalCard(JournalEntry journal) {
    return GestureDetector(
      onLongPress: () => _confirmDeleteJournal(journal, true),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Color(journal.themeColorValue),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send,
                      size: 16,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Sent to: ',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                journal.sharedBy ?? 'Unknown',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          DateFormat('MMM d, h:mm a').format(journal.sharedAt!),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 14,
                          color: Colors.green[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Sent',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                journal.title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (journal.sharedNote != null && journal.sharedNote!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.note,
                        size: 14,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Note: ${journal.sharedNote}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Long press to delete',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.black.withOpacity(0.5),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========================= JOURNAL DETAIL PAGE =========================

class JournalDetailPage extends StatelessWidget {
  final JournalEntry entry;
  final PostageStamp? stamp;

  const JournalDetailPage({
    super.key,
    required this.entry,
    this.stamp,
  });

  String _getMoodEmoji(String mood) {
    final standardMoods = ['awesome', 'happy', 'sad'];
    if(standardMoods.contains(mood.toLowerCase())) {
      switch (mood.toLowerCase()) {
        case 'awesome': return '🥳';
        case 'happy': return '😊';
        case 'sad': return '😢';
      }
    }
    return '✨';
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black.withOpacity(0.8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isWelcomeJournal = entry.id == 'welcome_journal_001';

    return Scaffold(
      backgroundColor: isWelcomeJournal ? null : Color(entry.themeColorValue),
      body: Container(
        decoration: isWelcomeJournal ? BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFADADD),
              const Color(0xFFFFE6C9).withOpacity(0.8),
            ],
          ),
        ) : null,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      if (stamp != null)
                        StampWidget(stamp: stamp!, width: 50, height: 70),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (entry.isShared) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.mail, size: 16, color: Colors.black),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Shared by ${entry.sharedBy}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.black,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  DateFormat('d MMMM yyyy').format(entry.date),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    entry.title,
                    style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: [
                    _buildTag('Mood: ${entry.mood} ${_getMoodEmoji(entry.mood)}'),
                  ],
                ),
                if (entry.sharedNote != null && entry.sharedNote!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Note from ${entry.sharedBy}:',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          entry.sharedNote!,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      entry.entryText,
                      style: GoogleFonts.poppins(fontSize: 15, height: 1.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ========================= RIBBON ANIMATION OVERLAY =========================

class RibbonAnimationOverlay extends StatefulWidget {
  const RibbonAnimationOverlay({super.key});

  static void show(BuildContext context) {
    OverlayEntry? overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => const RibbonAnimationOverlay(),
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
                  'Sealed with Love',
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