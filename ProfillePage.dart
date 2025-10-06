import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart'; // Import for RootPage

// -------------------------------------------------------------------
// 1. PROFILE PAGE (MODIFIED)
// -------------------------------------------------------------------
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _userEmail = 'Loading...';
  String _userId = '';
  final String _appVersion = 'Version 1.0.0';
  bool _isLoading = true;

  final Uri _instagramUrl = Uri.parse('https://www.instagram.com/kindworldapp/');

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        setState(() {
          _userId = user.uid;
          _userEmail = user.email ?? 'No Email Provided';
        });

        final DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (!userDoc.exists) {
          await _firestore.collection('users').doc(user.uid).set({
            'email': user.email,
            'uid': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        setState(() {
          _userEmail = 'Guest';
          _userId = '';
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _userEmail = 'Error loading data';
        _userId = '';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _launchInstagram() async {
    if (!await launchUrl(_instagramUrl, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch Instagram')),
        );
      }
    }
  }

  Future<void> _sendPasswordResetEmail() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      await _auth.sendPasswordResetEmail(email: _userEmail);
      Navigator.pop(context); // Close loading dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Success'),
            ],
          ),
          content: Text(
            'Password reset link has been sent to $_userEmail. Please check your inbox.',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } on FirebaseAuthException catch (e) {
      Navigator.pop(context);
      String errorMessage = 'An error occurred';
      if (e.code == 'user-not-found') {
        errorMessage = 'No user found with this email address';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email address';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send reset email. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    final currentContext = context;
    showDialog(
      context: currentContext,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Log Out'),
          content: const Text('Are you sure you want to log out?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.black)),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Log Out', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                try {
                  Navigator.pop(dialogContext);
                  showDialog(
                    context: currentContext,
                    barrierDismissible: false,
                    builder: (context) => const Center(child: CircularProgressIndicator()),
                  );
                  await _auth.signOut();
                  if (mounted) {
                    Navigator.of(currentContext).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const RootPage()),
                          (Route<dynamic> route) => false,
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(currentContext);
                    ScaffoldMessenger.of(currentContext).showSnackBar(
                      const SnackBar(
                        content: Text('Error logging out. Please try again.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
        // FIX: Replaced complex layout with a simple Column + Spacer
            : Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: Column(
            children: [
              _buildProfileHeader(),
              const SizedBox(height: 30),
              _buildMenuItem(
                icon: Icons.lock_outline,
                text: 'Change Password',
                onTap: () {
                  if (_userEmail.isNotEmpty && _userEmail != "Guest") {
                    _showPasswordResetDialog();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('User email not found.')),
                    );
                  }
                },
              ),
              _buildMenuItem(
                icon: Icons.description_outlined,
                text: 'Privacy Policy',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                ),
              ),
              _buildMenuItem(
                icon: Icons.article_outlined,
                text: 'Terms & Conditions',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TermsAndConditionsPage()),
                ),
              ),
              _buildMenuItem(
                icon: Icons.help_outline,
                text: 'Help and Support',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HelpAndSupportPage()),
                ),
              ),
              _buildMenuItem(
                icon: Icons.logout,
                text: 'Log Out',
                textColor: Colors.red,
                hideArrow: true,
                onTap: _handleLogout,
              ),
              const Spacer(), // This pushes the version text to the bottom
              Center(
                child: Text(
                  _appVersion,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: _launchInstagram,
          icon: const Icon(Icons.group_add_outlined, color: Colors.white, size: 20),
          label: const Text('Join our Community'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30), // Pill shape
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _userEmail,
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        if (_userId.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'UID: ${_userId.substring(0, _userId.length > 8 ? 8 : _userId.length)}...',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontFamily: 'monospace',
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    Color? textColor,
    bool hideArrow = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: textColor ?? Colors.black87),
        title: Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
        trailing: hideArrow ? null : const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  void _showPasswordResetDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Reset Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('A password reset link will be sent to:', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_userEmail, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.black)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(context);
                _sendPasswordResetEmail();
              },
              child: const Text('Send Email', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}

// -------------------------------------------------------------------
// 2. PRIVACY POLICY PAGE
// -------------------------------------------------------------------
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Last Updated: October 5, 2025',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            SizedBox(height: 24),
            Text('1. INTRODUCTION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 8),
            Text(
              'Welcome to our app. We respect your privacy and are committed to protecting your personal data. This privacy policy will inform you about how we look after your personal data when you use our mobile application.',
              textAlign: TextAlign.justify,
              style: TextStyle(height: 1.5),
            ),
            // Add more sections as needed
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------
// 3. TERMS & CONDITIONS PAGE
// -------------------------------------------------------------------
class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Effective Date: October 5, 2025',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            SizedBox(height: 24),
            Text('1. ACCEPTANCE OF TERMS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 8),
            Text(
              'By downloading, installing, or using the app, you agree to be bound by these Terms and Conditions. If you disagree with any part of these terms, then you do not have permission to access the service.',
              textAlign: TextAlign.justify,
              style: TextStyle(height: 1.5),
            ),
            // Add more sections as needed
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------
// 4. HELP & SUPPORT PAGE
// -------------------------------------------------------------------
class HelpAndSupportPage extends StatelessWidget {
  const HelpAndSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> faqs = [
      {
        'question': 'How do I reset my password?',
        'answer': 'On the profile page, tap on "Change Password". A password reset link will be sent to your registered email address. Follow the instructions in the email to set a new password.',
      },
      {
        'question': 'How is my data used?',
        'answer': 'We use your data, such as email and name, solely to provide and improve the service. Please refer to our Privacy Policy for more details.',
      },
      {
        'question': 'How do I delete my account?',
        'answer': 'Account deletion is not yet available in the app. Please contact support at support@kindapp.com to request account deletion.',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Help and Support'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'Frequently Asked Questions',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const SizedBox(height: 16),
          ...faqs.map((faq) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ExpansionTile(
                title: Text(faq['question']!, style: const TextStyle(fontWeight: FontWeight.w500)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(faq['answer']!, textAlign: TextAlign.justify, style: const TextStyle(color: Colors.black87)),
                  ),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 30),
          Card(
            color: Colors.grey.shade100,
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: const Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Icon(Icons.mail_outline, color: Colors.black, size: 36),
                  SizedBox(height: 12),
                  Text('Still need help?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  SizedBox(height: 8),
                  Text('Contact our support team', style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 8),
                  SelectableText(
                    'support@kindapp.com',
                    style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}