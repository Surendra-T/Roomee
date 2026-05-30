import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:roomee/features/chat/chat_screen.dart';
import 'package:roomee/theme/app_theme.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please sign in.')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('connections')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const _ChatListError();
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const _ChatListEmpty();
            }

            return ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: docs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final otherUid = doc['otherUid'] as String?;
                final connectionId = doc['connectionId'] as String?;
                final matchPercent = doc['matchPercent']?.toString() ?? '--';

                if (otherUid == null || connectionId == null) {
                  return const SizedBox.shrink();
                }

                return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(otherUid)
                      .get(),
                  builder: (context, userSnapshot) {
                    final data = userSnapshot.data?.data() ?? {};
                    final answers = Map<String, dynamic>.from(
                      data['answers'] as Map? ?? {},
                    );
                    final alias = _buildAlias(answers);
                    final city = (data['city'] as String?) ?? '';

                    return _ChatTile(
                      alias: alias,
                      city: city,
                      matchPercent: matchPercent,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              connectionId: connectionId,
                              otherUid: otherUid,
                              alias: alias,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.alias,
    required this.city,
    required this.matchPercent,
    required this.onTap,
  });

  final String alias;
  final String city;
  final String matchPercent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.subtleBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alias,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 18,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    city.isEmpty ? 'Tap to chat' : city,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.subtleUiBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.subtleBorder),
              ),
              child: Text(
                '$matchPercent%',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.accent,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatListEmpty extends StatelessWidget {
  const _ChatListEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No connections yet.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.secondaryText),
      ),
    );
  }
}

class _ChatListError extends StatelessWidget {
  const _ChatListError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Unable to load chats.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

String _buildAlias(Map<String, dynamic> answers) {
  final cleanliness = _asDouble(answers['cleanliness']) ?? 5;
  final sleep = _asDouble(answers['sleep']) ?? 5;

  final vibe = cleanliness >= 7
      ? 'Neat'
      : cleanliness <= 3
      ? 'Easygoing'
      : 'Balanced';

  final sleepLabel = sleep >= 7
      ? 'Night Owl'
      : sleep <= 3
      ? 'Early Bird'
      : 'Flexible';

  return '$vibe $sleepLabel';
}

double? _asDouble(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value.toDouble();
  }
  if (value is double) {
    return value;
  }
  return null;
}
