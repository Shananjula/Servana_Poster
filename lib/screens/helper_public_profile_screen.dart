import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:servana/models/review_model.dart';
import 'package:servana/models/user_model.dart';
import 'package:servana/providers/user_provider.dart';
import 'package:servana/screens/conversation_screen.dart';
import 'package:servana/services/firestore_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';

class HelperPublicProfileScreen extends StatefulWidget {
  final String helperId;

  const HelperPublicProfileScreen({Key? key, required this.helperId}) : super(key: key);

  @override
  State<HelperPublicProfileScreen> createState() => _HelperPublicProfileScreenState();
}

class _HelperPublicProfileScreenState extends State<HelperPublicProfileScreen> {
  bool _isContacting = false;
  final FirestoreService _firestoreService = FirestoreService();

  // --- Text Style Helper ---
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

  // --- Contact Logic ---
  void _onContactPressed(BuildContext context, HelpifyUser helper) async {
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

      final existingChannelId = await _firestoreService.getDirectChatChannelId(currentUser.id, helper.id);
      if (!context.mounted) return;

      if (existingChannelId != null) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (ctx) => ConversationScreen(
            chatChannelId: existingChannelId,
            otherUserName: helper.displayName ?? 'Helper',
            otherUserAvatarUrl: helper.photoURL,
            taskTitle: "Direct Inquiry",
          ),
        ));
      } else {
        final bool? confirmPayment = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text("Contact ${helper.displayName}?"),
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
            helper: helper,
          );
          if (!context.mounted) return;
          Navigator.of(context).push(MaterialPageRoute(
            builder: (ctx) => ConversationScreen(
              chatChannelId: newChatChannelId,
              otherUserName: helper.displayName ?? 'Helper',
              otherUserAvatarUrl: helper.photoURL,
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
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.helperId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Helper not found.'));
          }
          final helper = HelpifyUser.fromFirestore(snapshot.data!);

          return Stack(
            children: [
              // --- Gradient Background ---
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF005C97), Color(0xFF363795)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              // --- Scrollable Content ---
              CustomScrollView(
                slivers: [
                  _buildSliverAppBar(context, helper),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate(
                        [
                          _buildStatsCard(helper).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
                          const SizedBox(height: 24),
                          _buildAboutCard(helper).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
                          const SizedBox(height: 24),
                          if (helper.skills.isNotEmpty)
                            _buildSkillsCard(helper).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
                          const SizedBox(height: 24),
                          if (helper.portfolioImageUrls.isNotEmpty)
                            _buildPortfolioCard(context, helper).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),
                          const SizedBox(height: 24),
                          _buildReviewsSection(helper.id).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2),
                          const SizedBox(height: 100), // Space for FAB
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
      // --- Floating Action Button ---
      floatingActionButton: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.helperId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          final helper = HelpifyUser.fromFirestore(snapshot.data!);
          return FloatingActionButton.extended(
            onPressed: _isContacting ? null : () => _onContactPressed(context, helper),
            label: Text('Contact Helper', style: _getTextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            icon: _isContacting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
            backgroundColor: Colors.greenAccent.shade400,
          ).animate().slideY(begin: 2, duration: 500.ms, curve: Curves.easeOut);
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // --- WIDGET BUILDERS ---

  SliverAppBar _buildSliverAppBar(BuildContext context, HelpifyUser helper) {
    return SliverAppBar(
      expandedHeight: 250.0,
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      stretch: true,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text(
          helper.displayName ?? 'Servana Helper',
          style: _getTextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF005C97), Color(0xFF363795)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: helper.photoURL != null ? NetworkImage(helper.photoURL!) : null,
                    child: helper.photoURL == null ? const Icon(Icons.person, size: 50, color: Colors.white70) : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star, color: Colors.amber.shade300, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${helper.averageRating.toStringAsFixed(1)} (${helper.ratingCount} reviews)',
                        style: _getTextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40), // Space for the title to settle
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(HelpifyUser helper) {
    return _GlassmorphicCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Rating', '${helper.averageRating.toStringAsFixed(1)} ★'),
          _buildStatItem('Jobs Done', helper.ratingCount.toString()),
          _buildStatItem('Cancellations', helper.cancellationCount.toString()),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: _getTextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: _getTextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
      ],
    );
  }

  Widget _buildAboutCard(HelpifyUser helper) {
    return _GlassmorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('About Me', style: _getTextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(height: 24, color: Colors.white12),
          Text(
            helper.bio ?? 'No bio provided.',
            style: _getTextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9)).copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsCard(HelpifyUser helper) {
    return _GlassmorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Skills', style: _getTextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(height: 24, color: Colors.white12),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: helper.skills
                .map((skill) => Chip(
              label: Text(skill),
              backgroundColor: Colors.white.withOpacity(0.2),
              labelStyle: _getTextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              side: BorderSide.none,
            ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioCard(BuildContext context, HelpifyUser helper) {
    return _GlassmorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Portfolio', style: _getTextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(height: 24, color: Colors.white12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: helper.portfolioImageUrls.length,
            itemBuilder: (context, index) {
              final imageUrl = helper.portfolioImageUrls[index];
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(imageUrl, fit: BoxFit.cover),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection(String helperId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Reviews', style: _getTextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('reviews')
              .where('ratedUserId', isEqualTo: helperId)
              .orderBy('timestamp', descending: true)
              .limit(5)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            if (snapshot.data!.docs.isEmpty) {
              return _GlassmorphicCard(child: Center(child: Text("No reviews yet.", style: _getTextStyle())));
            }
            final reviews = snapshot.data!.docs.map((doc) => Review.fromFirestore(doc)).toList();
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reviews.length,
              itemBuilder: (context, index) {
                final review = reviews[index];
                return _GlassmorphicCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(review.reviewerName, style: _getTextStyle(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          ...List.generate(5, (starIndex) {
                            return Icon(
                              starIndex < review.rating ? Icons.star : Icons.star_border,
                              color: Colors.amber.shade300,
                              size: 16,
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '"${review.reviewText}"',
                        style: _getTextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8)).copyWith(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

// --- GLASSMORPHIC CARD HELPER ---
class _GlassmorphicCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;
  const _GlassmorphicCard({required this.child, this.margin = EdgeInsets.zero});

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
