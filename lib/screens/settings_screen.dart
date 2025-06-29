import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'legal_screen.dart'; // Ensure this file exists too!

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _emailNotifications = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings'),
      ),
      body: ListView(
        children: [
          _buildSectionHeader('Notifications', theme),
          SwitchListTile(
            title: const Text('Push Notifications'),
            subtitle: const Text('Receive alerts for offers, messages, and task updates.'),
            value: _pushNotifications,
            onChanged: (bool value) {
              setState(() {
                _pushNotifications = value;
              });
            },
            secondary: const Icon(Icons.notifications_active_outlined),
          ),
          SwitchListTile(
            title: const Text('Email Notifications'),
            subtitle: const Text('Get summaries and important updates via email.'),
            value: _emailNotifications,
            onChanged: (bool value) {
              setState(() {
                _emailNotifications = value;
              });
            },
            secondary: const Icon(Icons.email_outlined),
          ),
          const Divider(),
          _buildSectionHeader('About & Legal', theme),
          _buildSettingsItem(
            context,
            icon: Icons.info_outline_rounded,
            title: 'About Helpify',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LegalScreen(
                  title: 'About Helpify',
                  contentKey: 'about',
                ),
              ),
            ),
          ),
          _buildSettingsItem(
            context,
            icon: Icons.gavel_rounded,
            title: 'Terms & Conditions',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LegalScreen(
                  title: 'Terms & Conditions',
                  contentKey: 'terms',
                ),
              ),
            ),
          ),
          _buildSettingsItem(
            context,
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LegalScreen(
                  title: 'Privacy Policy',
                  contentKey: 'privacy',
                ),
              ),
            ),
          ),
          const Divider(),
          _buildSectionHeader('Support', theme),
          _buildSettingsItem(
            context,
            icon: Icons.help_outline_rounded,
            title: 'Help & Support Center',
            onTap: () async {
              final url = Uri.parse('https://www.helpify.lk/help');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 8.0),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSettingsItem(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      onTap: onTap,
    );
  }
}
