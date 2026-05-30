import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:roomee/firebase_options.dart';
import 'package:roomee/features/auth/auth_gate.dart';
import 'package:roomee/theme/app_theme.dart';

Future<void> injectDummies() async {
  final firestore = FirebaseFirestore.instance;
  final List<Map<String, dynamic>> dummies = [
    {
      'uid': 'dummy1',
      'name': 'Alex',
      'city': 'Bangalore',
      'onboardingComplete': true,
      'answers': {
        'cleanliness': 9.0,
        'noise': 2.0,
        'sleep': 2.0,
        'chores': 8.0,
        'temp': 3.0,
        'guests': 'Rarely',
        'sharing': 'Keep separate',
        'pets': 'Dogs OK',
        'wfh': 'Hybrid',
        'dealbreaker': 'No loud alarms',
      },
    },
    {
      'uid': 'dummy2',
      'name': 'Sam',
      'city': 'Bangalore',
      'onboardingComplete': true,
      'answers': {
        'cleanliness': 3.0,
        'noise': 9.0,
        'sleep': 9.0,
        'chores': 3.0,
        'temp': 8.0,
        'guests': 'Often',
        'sharing': 'Open share',
        'pets': 'Any OK',
        'wfh': 'Always',
        'dealbreaker': 'I play drums',
      },
    },
    {
      'uid': 'dummy3',
      'name': 'Jordan',
      'city': 'Mumbai',
      'onboardingComplete': true,
      'answers': {
        'cleanliness': 6.0,
        'noise': 5.0,
        'sleep': 5.0,
        'chores': 5.0,
        'temp': 5.0,
        'guests': 'Sometimes',
        'sharing': 'Some sharing',
        'pets': 'Cats OK',
        'wfh': 'Hybrid',
        'dealbreaker': '',
      },
    },
    {
      'uid': 'dummy4',
      'name': 'Taylor',
      'city': 'Bangalore',
      'onboardingComplete': true,
      'answers': {
        'cleanliness': 10.0,
        'noise': 1.0,
        'sleep': 8.0,
        'chores': 10.0,
        'temp': 2.0,
        'guests': 'Rarely',
        'sharing': 'Keep separate',
        'pets': 'No pets',
        'wfh': 'Never',
        'dealbreaker': 'No outside shoes inside',
      },
    },
    {
      'uid': 'dummy5',
      'name': 'Casey',
      'city': 'Delhi',
      'onboardingComplete': true,
      'answers': {
        'cleanliness': 4.0,
        'noise': 7.0,
        'sleep': 3.0,
        'chores': 4.0,
        'temp': 7.0,
        'guests': 'Often',
        'sharing': 'Some sharing',
        'pets': 'Any OK',
        'wfh': 'Always',
        'dealbreaker': '',
      },
    },
    {
      'uid': 'dummy6',
      'name': 'Jamie',
      'city': 'Bangalore',
      'onboardingComplete': true,
      'answers': {
        'cleanliness': 8.0,
        'noise': 4.0,
        'sleep': 2.0,
        'chores': 7.0,
        'temp': 4.0,
        'guests': 'Sometimes',
        'sharing': 'Keep separate',
        'pets': 'Cats OK',
        'wfh': 'Hybrid',
        'dealbreaker': 'Must love cats',
      },
    },
    {
      'uid': 'dummy7',
      'name': 'Riley',
      'city': 'Pune',
      'onboardingComplete': true,
      'answers': {
        'cleanliness': 2.0,
        'noise': 8.0,
        'sleep': 10.0,
        'chores': 2.0,
        'temp': 9.0,
        'guests': 'Often',
        'sharing': 'Open share',
        'pets': 'Dogs OK',
        'wfh': 'Always',
        'dealbreaker': 'I host parties',
      },
    },
    {
      'uid': 'dummy8',
      'name': 'Morgan',
      'city': 'Bangalore',
      'onboardingComplete': true,
      'answers': {
        'cleanliness': 7.0,
        'noise': 3.0,
        'sleep': 6.0,
        'chores': 6.0,
        'temp': 5.0,
        'guests': 'Rarely',
        'sharing': 'Some sharing',
        'pets': 'No pets',
        'wfh': 'Hybrid',
        'dealbreaker': '',
      },
    },
    {
      'uid': 'dummy9',
      'name': 'Avery',
      'city': 'Chennai',
      'onboardingComplete': true,
      'answers': {
        'cleanliness': 5.0,
        'noise': 6.0,
        'sleep': 4.0,
        'chores': 5.0,
        'temp': 6.0,
        'guests': 'Sometimes',
        'sharing': 'Open share',
        'pets': 'Any OK',
        'wfh': 'Never',
        'dealbreaker': 'Veg food only',
      },
    },
    {
      'uid': 'dummy10',
      'name': 'Quinn',
      'city': 'Bangalore',
      'onboardingComplete': true,
      'answers': {
        'cleanliness': 9.0,
        'noise': 1.0,
        'sleep': 1.0,
        'chores': 9.0,
        'temp': 2.0,
        'guests': 'Rarely',
        'sharing': 'Keep separate',
        'pets': 'No pets',
        'wfh': 'Always',
        'dealbreaker': 'Absolute silence at 10 PM',
      },
    },
  ];

  for (var dummy in dummies) {
    await firestore.collection('users').doc(dummy['uid']).set(dummy);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // await injectDummies();

  runApp(const RoomeeApp());
}

class RoomeeApp extends StatelessWidget {
  const RoomeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Roomee',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AuthGate(),
    );
  }
}
