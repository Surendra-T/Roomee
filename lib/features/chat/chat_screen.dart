// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:roomee/theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.connectionId,
    required this.otherUid,
    required this.alias,
  });

  final String connectionId;
  final String otherUid;
  final String alias;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  // States for our new features
  bool _isRevealed = false;
  String? _realName;
  bool _isRevealing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);

    try {
      _controller.clear();
      await FirebaseFirestore.instance
          .collection('connections')
          .doc(widget.connectionId)
          .collection('messages')
          .add({
            'senderId': user.uid,
            'text': text,
            'createdAt': FieldValue.serverTimestamp(),
          });
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Unable to send message.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // --- NEW: Reveal Identity Logic ---
  Future<void> _revealIdentity() async {
    setState(() => _isRevealing = true);
    try {
      // Fetch their real name from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUid)
          .get();
      final name = doc.data()?['name'] as String? ?? 'Mystery User';

      if (mounted) {
        setState(() {
          _realName = name;
          _isRevealed = true;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to reveal identity.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRevealing = false);
    }
  }

  // --- NEW: Un-connect Logic ---
  Future<void> _unconnect() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. Delete the main connection document
      await FirebaseFirestore.instance
          .collection('connections')
          .doc(widget.connectionId)
          .delete();

      // 2. Remove from my connections list
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('connections')
          .doc(widget.otherUid)
          .delete();

      // 3. Remove from their connections list
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUid)
          .collection('connections')
          .doc(user.uid)
          .delete();

      if (mounted) {
        Navigator.of(context).pop(); // Kick back to Chat List
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have un-connected with this user.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to un-connect.')));
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          // Dynamically swap the title if revealed!
          _isRevealed ? _realName! : widget.alias,
          style: GoogleFonts.playfairDisplay(
            fontSize: 18,
            color: AppColors.primaryAction,
          ),
        ),
        actions: [
          // Replaced the empty IconButton with a functional PopupMenu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            onSelected: (value) {
              if (value == 'unconnect') {
                _unconnect();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'unconnect',
                child: Text(
                  'Un-connect',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('connections')
                          .doc(widget.connectionId)
                          .collection('messages')
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) return const _ChatError();

                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) return const _ChatEmpty();

                        return ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.fromLTRB(24, 96, 24, 24),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final data = docs[index].data();
                            final isMe = data['senderId'] == user.uid;
                            final text = data['text'] as String? ?? '';

                            return _MessageBubble(text: text, isMe: isMe);
                          },
                        );
                      },
                    ),
                  ),
                  // Only show the Reveal button if we haven't revealed them yet
                  if (!_isRevealed)
                    _RevealIdentityFloating(
                      onPressed: _revealIdentity,
                      isLoading: _isRevealing,
                    ),
                ],
              ),
            ),
            _ChatInput(
              controller: _controller,
              onSend: _sending ? null : _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _RevealIdentityFloating extends StatelessWidget {
  const _RevealIdentityFloating({
    required this.onPressed,
    required this.isLoading,
  });

  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.pureWhite, AppColors.pureWhite.withOpacity(0.0)],
          ),
        ),
        child: Center(
          child: OutlinedButton.icon(
            onPressed: isLoading ? null : onPressed,
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.verified_user_outlined, size: 16),
            label: Text(isLoading ? 'Revealing...' : 'Reveal identity'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              side: const BorderSide(color: AppColors.accentLight),
              foregroundColor: AppColors.primaryText,
              backgroundColor: AppColors.subtleUiBackground,
              textStyle: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(letterSpacing: 1.2),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.text, required this.isMe});

  final String text;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft: Radius.circular(isMe ? 16 : 2),
      topRight: Radius.circular(isMe ? 2 : 16),
      bottomLeft: const Radius.circular(16),
      bottomRight: const Radius.circular(16),
    );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primaryAction : AppColors.subtleUiBackground,
          borderRadius: radius,
          border: isMe ? null : Border.all(color: AppColors.subtleBorder),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isMe ? AppColors.pureWhite : AppColors.primaryText,
          ),
        ),
      ),
    );
  }
}

class _ChatInput extends StatelessWidget {
  const _ChatInput({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      decoration: const BoxDecoration(
        color: AppColors.pureWhite,
        border: Border(top: BorderSide(color: AppColors.subtleBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Message',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 40,
            height: 40,
            child: ElevatedButton(
              onPressed: onSend,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryAction,
                foregroundColor: AppColors.pureWhite,
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
              ),
              child: const Icon(Icons.send, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatEmpty extends StatelessWidget {
  const _ChatEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Say hello to start the conversation.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.secondaryText),
      ),
    );
  }
}

class _ChatError extends StatelessWidget {
  const _ChatError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Unable to load chat.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
