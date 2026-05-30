import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:roomee/theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final Set<String> _undoing = {};

  Future<void> _undoPass(String otherUid, String userId) async {
    if (_undoing.contains(otherUid)) {
      return;
    }

    setState(() {
      _undoing.add(otherUid);
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('swipes')
          .doc(otherUid)
          .delete();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('undoQueue')
          .doc(otherUid)
          .set({
            'otherUid': otherUid,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Undo applied.')));
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Unable to undo.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _undoing.remove(otherUid);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please sign in.')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('swipes')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const _HistoryError();
            }

            final docs = snapshot.data?.docs ?? [];
            final rejected = docs
                .where((doc) => doc['direction'] == 'pass')
                .toList();

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your history',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Track who you passed and connected with.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _ConnectionsCount(userId: user.uid),
                      const SizedBox(width: 12),
                      _StatCard(
                        label: 'Rejected',
                        value: rejected.length.toString(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Recently rejected',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: rejected.isEmpty
                        ? const _HistoryEmpty()
                        : ListView.separated(
                            itemCount: rejected.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final doc = rejected[index];
                              final otherUid =
                                  (doc['targetUid'] as String?) ?? doc.id;
                              final match =
                                  doc['matchPercent']?.toString() ?? '—';
                              final isUndoing = _undoing.contains(otherUid);
                              return _HistoryTile(
                                otherUid: otherUid,
                                matchPercent: match,
                                isUndoing: isUndoing,
                                onUndo: isUndoing
                                    ? null
                                    : () => _undoPass(otherUid, user.uid),
                              );
                            },
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

class _ConnectionsCount extends StatelessWidget {
  const _ConnectionsCount({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('connections')
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return _StatCard(label: 'Connections', value: count.toString());
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.subtleBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.secondaryText,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.otherUid,
    required this.matchPercent,
    required this.isUndoing,
    required this.onUndo,
  });

  final String otherUid;
  final String matchPercent;
  final bool isUndoing;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.subtleUiBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.subtleBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(otherUid, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text(
                  'Match $matchPercent%',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.accent,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onUndo,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryText,
              side: const BorderSide(color: AppColors.subtleBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isUndoing
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Undo'),
          ),
        ],
      ),
    );
  }
}

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No rejected profiles yet.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.secondaryText),
      ),
    );
  }
}

class _HistoryError extends StatelessWidget {
  const _HistoryError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Unable to load history.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
