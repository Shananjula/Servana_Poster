import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:servana/models/user_model.dart';
import 'package:servana/providers/user_provider.dart';
import 'package:servana/screens/conversation_screen.dart';
import 'package:servana/screens/helper_public_profile_screen.dart';
import 'package:servana/services/firestore_service.dart';

class HelperCard extends StatefulWidget {
  final HelpifyUser helper;
  const HelperCard({Key? key, required this.helper}) : super(key: key);

  @override
  State<HelperCard> createState() => _HelperCardState();
}

class _HelperCardState extends State<HelperCard> {
  bool _isContacting = false;
  final FirestoreService _firestoreService = FirestoreService();

  TextStyle _getTextStyle(
      {double fontSize = 16,
        FontWeight fontWeight = FontWeight.normal,
        Color color = Colors.white,
        double letterSpacing = 0.5}) {
    return GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      shadows: [
        Shadow(
          color: Colors.black.withOpacity(0.25),
          offset: const Offset(0, 1),
          blurRadius: 4,
        )
      ],
    );
  }

  void _onContactPressed(BuildContext context) async {
    if (_isContacting) return;
    setState(() => _isContacting = true);

    try {
      final currentUser = context.read<UserProvider>().user;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You must be logged in to contact a helper.")),
        );
        return;
      }

      final existingChannelId = await _firestoreService.getDirectChatChannelId(currentUser.id, widget.helper.id);

      if (!context.mounted) return;

      if (existingChannelId != null) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (ctx) => ConversationScreen(
            chatChannelId: existingChannelId,
            otherUserName: widget.helper.displayName ?? 'Helper',
            otherUserAvatarUrl: widget.helper.photoURL,
            taskTitle: "Direct Inquiry",
          ),
        ));
      } else {
        final bool? confirmPayment = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text("Contact ${widget.helper.displayName}?"),
            content: const Text(
                "A one-time fee of 20 Serv Coins will be deducted to start a private chat. Do you want to continue?"),
            actions: [
              TextButton(
                child: const Text("Cancel"),
                onPressed: () => Navigator.of(dialogContext).pop(false),
              ),
              ElevatedButton(
                child: const Text("Confirm & Pay"),
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
            ],
          ),
        );

        if (confirmPayment == true) {
          final String newChatChannelId = await _firestoreService.initiateDirectContact(
            currentUser: currentUser,
            helper: widget.helper,
          );

          if (!context.mounted) return;

          Navigator.of(context).push(MaterialPageRoute(
            builder: (ctx) => ConversationScreen(
              chatChannelId: newChatChannelId,
              otherUserName: widget.helper.displayName ?? 'Helper',
              otherUserAvatarUrl: widget.helper.photoURL,
              taskTitle: "Direct Inquiry",
            ),
          ));
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isContacting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _GlassmorphicCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            HelperPublicProfileScreen(helperId: widget.helper.id))),
                child: CircleAvatar(
                  radius: 30,
                  backgroundImage:
                  widget.helper.photoURL != null ? NetworkImage(widget.helper.photoURL!) : null,
                  child: widget.helper.photoURL == null
                      ? const Icon(Icons.person, size: 30, color: Colors.white70)
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => HelperPublicProfileScreen(
                              helperId: widget.helper.id))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(widget.helper.displayName ?? 'Servana Helper',
                              style: _getTextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (widget.helper.isProMember)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.purpleAccent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('PRO', style: _getTextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            )
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber.shade300, size: 16),
                          const SizedBox(width: 4),
                          Text(
                              '${widget.helper.averageRating.toStringAsFixed(1)} (${widget.helper.ratingCount} reviews)',
                              style: _getTextStyle(fontSize: 13, color: Colors.white.withOpacity(0.8))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              _isContacting
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : IconButton(
                icon: Icon(Icons.chat_bubble_outline_rounded,
                    color: Colors.white.withOpacity(0.8)),
                onPressed: () => _onContactPressed(context),
                tooltip: "Contact Helper",
              ),
            ],
          ),
          if (widget.helper.skills.isNotEmpty) ...[
            const Divider(height: 24, color: Colors.white12),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: widget.helper.skills
                    .take(3)
                    .map((skill) => Chip(
                  label: Text(skill),
                  backgroundColor: Colors.white.withOpacity(0.2),
                  labelStyle: _getTextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  side: BorderSide.none,
                ))
                    .toList(),
              ),
            )
          ]
        ],
      ),
    );
  }
}

class _GlassmorphicCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;

  const _GlassmorphicCard({
    required this.child,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          margin: margin,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: child,
        ),
      ),
    );
  }
}
