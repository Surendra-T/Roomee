// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // NEW: Hardware access for Haptics!
import 'package:google_fonts/google_fonts.dart';
import 'package:roomee/features/chat/chat_list_screen.dart';
import 'package:roomee/features/history/history_screen.dart';
import 'package:roomee/features/profile/profile_screen.dart';
import 'package:roomee/theme/app_theme.dart';

enum SwipeAction { like, pass }

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please sign in.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Roomee'),
        actions: [
          _ConnectionsBadge(userId: user.uid),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ChatListScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: _FeedBody(user: user),
        ),
      ),
    );
  }
}

class _FeedBody extends StatefulWidget {
  const _FeedBody({required this.user});

  final User user;

  @override
  State<_FeedBody> createState() => _FeedBodyState();
}

class _FeedBodyState extends State<_FeedBody> {
  final List<RoommateProfile> _deck = [];
  final Set<String> _likedUids = {};
  Map<String, dynamic> _currentAnswers = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _undoSub;

  @override
  void initState() {
    super.initState();
    _undoSub = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .collection('undoQueue')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .listen(_handleUndoSnapshot);
  }

  @override
  void dispose() {
    _undoSub?.cancel();
    super.dispose();
  }

  void _handleUndoSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    for (final change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.added) {
        _processUndoDoc(change.doc);
      }
    }
  }

  Future<void> _processUndoDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final otherUid = (doc.data()?['otherUid'] as String?) ?? doc.id;
    if (otherUid == widget.user.uid) {
      await doc.reference.delete();
      return;
    }

    final otherDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(otherUid)
        .get();

    if (!otherDoc.exists) {
      await doc.reference.delete();
      return;
    }

    final profile = RoommateProfile.fromDoc(otherDoc);
    if (!mounted) {
      return;
    }

    setState(() {
      _deck.removeWhere((item) => item.uid == profile.uid);
      _deck.insert(0, profile);
    });

    await doc.reference.delete();
  }

  void _queueSwipe(RoommateProfile profile, SwipeAction action) {
    // NEW: Fire a haptic vibration every time a card is swiped!
    HapticFeedback.mediumImpact();

    setState(() {
      _deck.removeWhere((item) => item.uid == profile.uid);
      if (action == SwipeAction.pass) {
        if (_deck.isNotEmpty) {
          _deck.add(profile);
        }
      } else {
        _likedUids.add(profile.uid);
      }
    });

    final matchPercent = _computeMatchPercent(_currentAnswers, profile.answers);
    _persistSwipe(profile, action, matchPercent);
  }

  Future<void> _persistSwipe(
    RoommateProfile profile,
    SwipeAction action,
    int matchPercent,
  ) async {
    try {
      final currentUid = widget.user.uid;
      final userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid);

      await userDoc.collection('swipes').doc(profile.uid).set({
        'direction': action.name,
        'matchPercent': matchPercent,
        'targetUid': profile.uid,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (action != SwipeAction.like) {
        return;
      }

      final otherSwipe = await FirebaseFirestore.instance
          .collection('users')
          .doc(profile.uid)
          .collection('swipes')
          .doc(currentUid)
          .get();

      if (otherSwipe.data()?['direction'] != 'like') {
        return;
      }

      final connectionId = _connectionId(currentUid, profile.uid);
      final connectionData = {
        'members': [currentUid, profile.uid],
        'matchPercent': matchPercent,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('connections')
          .doc(connectionId)
          .set(connectionData, SetOptions(merge: true));

      await userDoc.collection('connections').doc(profile.uid).set({
        'connectionId': connectionId,
        'matchPercent': matchPercent,
        'otherUid': profile.uid,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(profile.uid)
          .collection('connections')
          .doc(currentUid)
          .set({
            'connectionId': connectionId,
            'matchPercent': matchPercent,
            'otherUid': currentUid,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Unable to save swipe.')),
      );
    }
  }

  void _syncDeck(List<RoommateProfile> profiles) {
    final existing = _deck.map((profile) => profile.uid).toSet();
    for (final profile in profiles) {
      if (!existing.contains(profile.uid) &&
          !_likedUids.contains(profile.uid)) {
        _deck.add(profile);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userDoc.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const _FeedError();
        }

        final currentData = snapshot.data?.data() ?? {};
        _currentAnswers = Map<String, dynamic>.from(
          currentData['answers'] as Map? ?? {},
        );

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('onboardingComplete', isEqualTo: true)
              .snapshots(),
          builder: (context, usersSnapshot) {
            if (usersSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (usersSnapshot.hasError) {
              return const _FeedError();
            }

            final profiles =
                usersSnapshot.data?.docs
                    .map(RoommateProfile.fromDoc)
                    .where((profile) => profile.uid != widget.user.uid)
                    .toList() ??
                [];

            if (profiles.isEmpty) {
              return const _EmptyFeed();
            }

            _syncDeck(profiles);

            if (_deck.isEmpty) {
              return const _EmptyFeed();
            }

            final deck = _deck.take(2).toList();

            return _FeedContent(
              profiles: deck,
              currentAnswers: _currentAnswers,
              onSwipe: _queueSwipe,
            );
          },
        );
      },
    );
  }
}

class _FeedContent extends StatelessWidget {
  const _FeedContent({
    required this.profiles,
    required this.currentAnswers,
    required this.onSwipe,
  });

  final List<RoommateProfile> profiles;
  final Map<String, dynamic> currentAnswers;
  final void Function(RoommateProfile profile, SwipeAction action) onSwipe;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Find your match',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontSize: 28,
            height: 1.1,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tap a card to see their Roommate Resume.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.secondaryText),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cards = <Widget>[];
              for (int i = profiles.length - 1; i >= 0; i--) {
                final depth = i;
                final profile = profiles[i];
                final isTop = i == 0;
                final matchPercent = _computeMatchPercent(
                  currentAnswers,
                  profile.answers,
                );

                Widget card = _MatchCard(
                  profile: profile,
                  matchPercent: matchPercent,
                  currentAnswers: currentAnswers, // Passed down for the Resume!
                  onLike: isTop
                      ? () {
                          HapticFeedback.lightImpact(); // Button Haptics!
                          onSwipe(profile, SwipeAction.like);
                        }
                      : null,
                  onPass: isTop
                      ? () {
                          HapticFeedback.lightImpact(); // Button Haptics!
                          onSwipe(profile, SwipeAction.pass);
                        }
                      : null,
                );

                if (isTop) {
                  card = Dismissible(
                    key: ValueKey('card-${profile.uid}'),
                    direction: DismissDirection.horizontal,
                    background: const _SwipeBackground(
                      alignment: Alignment.centerLeft,
                      icon: Icons.check,
                      color: AppColors.primaryAction,
                    ),
                    secondaryBackground: const _SwipeBackground(
                      alignment: Alignment.centerRight,
                      icon: Icons.close,
                      color: AppColors.accent,
                    ),
                    onDismissed: (direction) {
                      final action = direction == DismissDirection.startToEnd
                          ? SwipeAction.like
                          : SwipeAction.pass;
                      onSwipe(profile, action);
                    },
                    child: card,
                  );
                }

                cards.add(
                  Align(
                    alignment: Alignment.topCenter,
                    child: Transform.translate(
                      offset: Offset(0, depth * 12),
                      child: Transform.scale(
                        scale: 1 - depth * 0.03,
                        child: SizedBox(
                          width: constraints.maxWidth,
                          child: card,
                        ),
                      ),
                    ),
                  ),
                );
              }
              return Stack(children: cards);
            },
          ),
        ),
      ],
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.profile,
    required this.matchPercent,
    required this.currentAnswers,
    required this.onLike,
    required this.onPass,
  });

  final RoommateProfile profile;
  final int matchPercent;
  final Map<String, dynamic> currentAnswers;
  final VoidCallback? onLike;
  final VoidCallback? onPass;

  void _showResume(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RoommateResumeSheet(
        profile: profile,
        currentAnswers: currentAnswers,
        matchPercent: matchPercent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alias = _buildAlias(profile.answers);
    final tags = _buildTags(profile);
    final quote = _buildQuote(profile.answers);

    // FIX: Material wraps the InkWell so it catches mobile taps perfectly!
    return Material(
      color: AppColors.pureWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.subtleBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showResume(context),
        splashColor: AppColors.accent.withValues(alpha: 0.1),
        highlightColor: AppColors.accent.withValues(alpha: 0.05),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.accent, AppColors.accentLight],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'MATCH $matchPercent%',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          letterSpacing: 3,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                      ),
                      const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppColors.secondaryText,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    alias,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 30,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [for (final tag in tags) _TagChip(label: tag)],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.subtleUiBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.subtleBorder.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      quote,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _RejectButton(onPressed: onPass),
                      const SizedBox(width: 16),
                      Expanded(child: _AcceptButton(onPressed: onLike)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- NEW: The Roommate Resume Bottom Sheet Widget ---
class _RoommateResumeSheet extends StatelessWidget {
  const _RoommateResumeSheet({
    required this.profile,
    required this.currentAnswers,
    required this.matchPercent,
  });

  final RoommateProfile profile;
  final Map<String, dynamic> currentAnswers;
  final int matchPercent;

  Widget _buildComparisonRow(
    String label,
    dynamic myAnswer,
    dynamic theirAnswer,
  ) {
    bool isMatch = false;
    if (myAnswer is double && theirAnswer is double) {
      isMatch =
          (myAnswer - theirAnswer).abs() <= 2.0; // Close enough on sliders
    } else {
      isMatch = myAnswer == theirAnswer; // Exact match on text choices
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            isMatch ? Icons.check_circle : Icons.warning_rounded,
            color: isMatch ? AppColors.primaryAction : Colors.amber,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Them: $theirAnswer',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.subtleBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Roommate Resume',
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              color: AppColors.primaryText,
            ),
          ),
          Text(
            '$matchPercent% Compatible',
            style: const TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'LIFESTYLE BREAKDOWN',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 12),
          _buildComparisonRow(
            'Cleanliness',
            currentAnswers['cleanliness'],
            profile.answers['cleanliness'],
          ),
          _buildComparisonRow(
            'Sleep Schedule',
            currentAnswers['sleep'],
            profile.answers['sleep'],
          ),
          _buildComparisonRow(
            'Guests',
            currentAnswers['guests'],
            profile.answers['guests'],
          ),
          _buildComparisonRow(
            'Pets',
            currentAnswers['pets'],
            profile.answers['pets'],
          ),
          _buildComparisonRow(
            'Work from Home',
            currentAnswers['wfh'],
            profile.answers['wfh'],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryText,
                foregroundColor: AppColors.pureWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Close Resume'),
            ),
          ),
        ],
      ),
    );
  }
}
// ---------------------------------------------------

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.subtleUiBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.subtleBorder),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 12,
          color: AppColors.primaryText,
        ),
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.icon,
    required this.color,
  });

  final Alignment alignment;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      // ignore: deprecated_member_use
      color: color.withOpacity(0.12),
      child: Icon(icon, color: color, size: 28),
    );
  }
}

class _RejectButton extends StatelessWidget {
  const _RejectButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          shape: const CircleBorder(),
          side: const BorderSide(color: AppColors.subtleBorder, width: 2),
        ),
        child: const Icon(Icons.close, color: AppColors.primaryText),
      ),
    );
  }
}

class _AcceptButton extends StatelessWidget {
  const _AcceptButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ElevatedButton(
        onPressed: onPressed,
        style:
            ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryAction,
              foregroundColor: AppColors.pureWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32),
              ),
              elevation: 0,
            ).copyWith(
              shadowColor: WidgetStateProperty.all(
                // ignore: deprecated_member_use
                AppColors.primaryAction.withOpacity(0.2),
              ),
              elevation: const WidgetStatePropertyAll(6),
            ),
        child: const Icon(Icons.check, size: 24),
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No available matches yet.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.secondaryText),
      ),
    );
  }
}

class _FeedError extends StatelessWidget {
  const _FeedError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Unable to load the feed.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _ConnectionsBadge extends StatefulWidget {
  const _ConnectionsBadge({required this.userId});

  final String userId;

  @override
  State<_ConnectionsBadge> createState() => _ConnectionsBadgeState();
}

class _ConnectionsBadgeState extends State<_ConnectionsBadge> {
  int _lastCount = 0;
  bool _initialized = false;

  void _notifyIfNeeded(int count) {
    if (!_initialized) {
      _initialized = true;
      _lastCount = count;
      return;
    }

    if (count <= _lastCount) {
      _lastCount = count;
      return;
    }

    final diff = count - _lastCount;
    _lastCount = count;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final message = diff == 1 ? 'New connection!' : '$diff new connections!';
      _showConnectionBanner(message);
    });
  }

  void _showConnectionBanner(String message) {
    // NEW: Heavy haptic feedback when a mutual match hits!
    HapticFeedback.heavyImpact();

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentMaterialBanner();

    messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: AppColors.pureWhite,
        content: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leadingPadding: const EdgeInsets.only(right: 0),
        actions: [
          TextButton(
            onPressed: messenger.hideCurrentMaterialBanner,
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      messenger.hideCurrentMaterialBanner();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('connections')
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        _notifyIfNeeded(count);

        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
            },
            child: Row(
              children: [
                const Icon(Icons.people_outline, size: 20),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accent),
                  ),
                  child: Text(
                    '$count',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        );
      },
    );
  }
}

class RoommateProfile {
  RoommateProfile({
    required this.uid,
    required this.name,
    required this.city,
    required this.answers,
  });

  final String uid;
  final String name;
  final String city;
  final Map<String, dynamic> answers;

  factory RoommateProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return RoommateProfile(
      uid: (data['uid'] as String?) ?? doc.id,
      name: (data['name'] as String?) ?? 'Roommate',
      city: (data['city'] as String?) ?? '',
      answers: Map<String, dynamic>.from(data['answers'] as Map? ?? {}),
    );
  }
}

int _computeMatchPercent(
  Map<String, dynamic> current,
  Map<String, dynamic> other,
) {
  const sliderKeys = ['cleanliness', 'noise', 'sleep', 'chores', 'temp'];
  const choiceKeys = ['guests', 'sharing', 'pets', 'wfh'];

  double score = 0;
  int count = 0;

  for (final key in sliderKeys) {
    final currentValue = _asDouble(current[key]);
    final otherValue = _asDouble(other[key]);
    if (currentValue == null || otherValue == null) continue;

    final diff = (currentValue - otherValue).abs();
    final similarity = 1 - (diff / 10);
    score += similarity;
    count += 1;
  }

  for (final key in choiceKeys) {
    final currentValue = current[key] as String?;
    final otherValue = other[key] as String?;
    if (currentValue == null || otherValue == null) continue;

    score += currentValue == otherValue ? 1 : 0.5;
    count += 1;
  }

  if (count == 0) return 0;
  return ((score / count) * 100).round().clamp(0, 100);
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

String _buildQuote(Map<String, dynamic> answers) {
  final dealbreaker = (answers['dealbreaker'] as String?)?.trim();
  if (dealbreaker != null && dealbreaker.isNotEmpty) {
    return 'Deal-breaker: $dealbreaker';
  }
  return 'Looking for a calm, respectful space.';
}

List<String> _buildTags(RoommateProfile profile) {
  final tags = <String>[];
  final cleanliness = _asDouble(profile.answers['cleanliness']);
  if (cleanliness != null) {
    if (cleanliness >= 7) {
      tags.add('Spotless');
    } else if (cleanliness <= 3)
      tags.add('Relaxed');
    else
      tags.add('Balanced');
  }

  final guests = profile.answers['guests'] as String?;
  if (guests != null && guests.isNotEmpty) tags.add('Guests $guests');

  final sharing = profile.answers['sharing'] as String?;
  if (sharing != null && sharing.isNotEmpty) tags.add(_sharingTag(sharing));

  if (profile.city.isNotEmpty) tags.add(profile.city);
  return tags.take(3).toList();
}

String _sharingTag(String value) {
  switch (value) {
    case 'Keep separate':
      return 'Private';
    case 'Some sharing':
      return 'Shared';
    case 'Open share':
      return 'Open share';
    default:
      return value;
  }
}

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is int) return value.toDouble();
  if (value is double) return value;
  return null;
}

String _connectionId(String uidA, String uidB) {
  final sorted = [uidA, uidB]..sort();
  return '${sorted.first}_${sorted.last}';
}
