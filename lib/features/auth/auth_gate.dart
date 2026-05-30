import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:roomee/features/auth/auth_screen.dart';
import 'package:roomee/features/feed/feed_screen.dart';
import 'package:roomee/features/onboarding/onboarding_name_city.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == null) {
          return const AuthScreen();
        }

        return _ProfileGate(user: snapshot.data!);
      },
    );
  }
}

class _ProfileGate extends StatelessWidget {
  const _ProfileGate({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userDoc.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Unable to load your profile.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          );
        }

        final data = snapshot.data?.data();
        final isComplete = data?['onboardingComplete'] == true;

        if (!isComplete) {
          return OnboardingNameCityScreen(
            initialName: data?['name'] as String?,
            initialCity: data?['city'] as String?,
          );
        }

        return const FeedScreen();
      },
    );
  }
}
