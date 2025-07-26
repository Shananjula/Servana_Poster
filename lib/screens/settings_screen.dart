// settings_screen.dart - CORRECTED

import 'package:servana/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servana/providers/locale_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:servana/screens/legal_screen.dart';

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
    final localeProvider = Provider.of<LocaleProvider>(context);

    String getLanguageName(Locale locale) {
      switch (locale.languageCode) {
        case 'en':
          return 'English';
        case 'si':
          return 'Sinhala (සිංහල)';
        case 'ta':
          return 'Tamil (தமிழ்)';
        default:
          return 'English';
      }
    }

    return Scaffold(
      // --- FIX: Removed the extra comma and parenthesis from this section ---
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.settingsTitle),
      ),
      // --- END OF FIX ---
      body: ListView(
        children: [
          _buildSectionHeader('Notifications', theme),
          SwitchListTile(
            title: const Text('Push Notifications'),
            subtitle: const Text('Receive alerts for offers, messages, and task updates.'),
            value: _pushNotifications,
            onChanged: (bool value) {
              setState(() => _pushNotifications = value);
            },
            secondary: const Icon(Icons.notifications_active_outlined),
          ),
          SwitchListTile(
            title: const Text('Email Notifications'),
            subtitle: const Text('Get summaries and important updates via email.'),
            value: _emailNotifications,
            onChanged: (bool value) {
              setState(() => _emailNotifications = value);
            },
            secondary: const Icon(Icons.email_outlined),
          ),
          const Divider(),
          _buildSectionHeader('Language', theme),
          ListTile(
            leading: const Icon(Icons.language_outlined),
            title: const Text('App Language'),
            trailing: DropdownButton<Locale>(
              value: localeProvider.locale,
              underline: const SizedBox(),
              onChanged: (Locale? newLocale) {
                if (newLocale != null) {
                  final provider = Provider.of<LocaleProvider>(context, listen: false);
                  provider.setLocale(newLocale);
                }
              },
              items: L10n.all.map<DropdownMenuItem<Locale>>((locale) {
                return DropdownMenuItem<Locale>(
                  value: locale,
                  child: Text(getLanguageName(locale)),
                );
              }).toList(),
            ),
          ),
          const Divider(),
          _buildSectionHeader('About & Legal', theme),
          _buildSettingsItem(
            context,
            icon: Icons.info_outline_rounded,
            title: 'About Servana',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LegalScreen(title: 'About Servana', contentKey: 'about')),
            ),
          ),
          _buildSettingsItem(
            context,
            icon: Icons.gavel_rounded,
            title: 'Terms & Conditions',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LegalScreen(title: 'Terms & Conditions', contentKey: 'terms')),
            ),
          ),
          _buildSettingsItem(
            context,
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LegalScreen(title: 'Privacy Policy', contentKey: 'privacy')),
            ),
          ),
          const Divider(),
          _buildSectionHeader('Support', theme),
          _buildSettingsItem(
            context,
            icon: Icons.help_outline_rounded,
            title: 'Help & Support Center',
            onTap: () async {
              final url = Uri.parse('https://www.servana.lk/help');
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