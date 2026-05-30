// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:roomee/features/auth/auth_gate.dart';
import 'package:roomee/features/onboarding/onboarding_questions.dart';
import 'package:roomee/theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  bool _initialized = false;
  bool _saving = false;
  bool _isLoggingOut = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
    await FirebaseAuth.instance.signOut();

    if (mounted) {
      // Pushing to AuthGate safely handles the redirect back to the login screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = 'Please sign in again.';
        _saving = false;
      });
      return;
    }

    final name = _nameController.text.trim();
    final city = _cityController.text.trim();

    if (name.isEmpty || city.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both name and city.';
        _saving = false;
      });
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': name,
        'city': city,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await user.updateDisplayName(name);
    } on FirebaseException catch (error) {
      setState(() {
        _errorMessage = error.message ?? 'Unable to save changes.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _retake() {
    final name = _nameController.text.trim();
    final city = _cityController.text.trim();

    if (name.isEmpty || city.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both name and city first.';
      });
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OnboardingQuestionsScreen(name: name, city: city),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please sign in.')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile & settings')),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const _ProfileError();
            }

            final data = snapshot.data?.data() ?? {};
            if (!_initialized) {
              _nameController.text = (data['name'] as String?) ?? '';
              _cityController.text = (data['city'] as String?) ?? '';
              _initialized = true;
            }

            // Extract the first letter for the avatar
            final currentName = (data['name'] as String?) ?? 'User';
            final initial = currentName.isNotEmpty
                ? currentName[0].toUpperCase()
                : 'U';

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Avatar Section ---
                  Center(
                    child: CircleAvatar(
                      radius: 45,
                      backgroundColor: AppColors.primaryAction.withOpacity(0.1),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryAction,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // --- Form Section ---
                  Text(
                    'Your details',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Update your info or retake your compatibility check.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _cityController,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(labelText: 'City'),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.redAccent),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryText,
                        foregroundColor: AppColors.pureWhite,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.pureWhite,
                              ),
                            )
                          : const Text('Save changes'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _retake,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryText,
                        side: const BorderSide(color: AppColors.subtleBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Retake compatibility questions'),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // --- Logout Section ---
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isLoggingOut ? null : _logout,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoggingOut
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.redAccent,
                              ),
                            )
                          : const Text(
                              'Log out',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Unable to load profile.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
