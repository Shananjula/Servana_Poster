// lib/screens/settings_screen.dart
//
// Poster Settings (with Language + Theme)
// - Header (name, phone, balance)
// - Edit Profile (inline)
// - Connect to Servana Helper (Play Store link copy)
// - Notifications toggles
// - Appearance & Language (System/Light/Dark + EN/SI/TA) via AppSettings
// - Safety & Privacy (emergency contacts)
// - Legal & About
// - Logout (presence off + FirebaseAuth.signOut + nav reset)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:servana/screens/notifications_screen.dart';
import 'package:servana/screens/legal_screen.dart';
import 'package:servana/utils/app_settings.dart';
import 'package:servana/screens/dispute_center_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _themePref = 'system'; // 'system' | 'light' | 'dark'
  String _langPref = '';        // ''(system) | 'en' | 'si' | 'ta'
  bool _loadingPrefs = true;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() => _loadingPrefs = false);
        return;
      }
      final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final s = (snap.data()?['settings'] ?? {}) as Map<String, dynamic>;
      final theme = (s['theme'] ?? 'system').toString();
      final locale = (s['locale'] ?? '').toString();

      _themePref = (theme == 'light' || theme == 'dark' || theme == 'system') ? theme : 'system';
      _langPref = (['', 'en', 'si', 'ta'].contains(locale)) ? locale : '';

      // live apply
      AppSettings.setTheme(_themeFromString(_themePref));
      AppSettings.setLocale(_langPref);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loadingPrefs = false);
    }
  }

  ThemeMode _themeFromString(String s) {
    switch (s) {
      case 'light': return ThemeMode.light;
      case 'dark': return ThemeMode.dark;
      default: return ThemeMode.system;
    }
  }

  Future<void> _savePrefs() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'settings': {
        'theme': _themePref,
        'locale': _langPref,
      }
    }, SetOptions(merge: true));
  }

  void _onThemeChange(String value) {
    setState(() => _themePref = value);
    AppSettings.setTheme(_themeFromString(value)); // live apply
    _savePrefs();
  }

  void _onLangChange(String value) {
    setState(() => _langPref = value);             // '' => system
    AppSettings.setLocale(value);                  // live apply
    _savePrefs();
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    final nav = Navigator.of(context);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    try {
      // best-effort: mark presence offline
      if (uid != null) {
        await FirebaseFirestore.instance.collection('presence').doc(uid).set({
          'isLive': false,
          'lastSeen': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // FirebaseAuth sign out (authStateChanges -> null)
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        // hard reset to sign-in route
        nav.pushNamedAndRemoveUntil('/signin', (_) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign out failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _HeaderCard(uid: uid),

          const SizedBox(height: 16),
          Text('Account', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          _tile(
            context,
            icon: Icons.person_rounded,
            title: 'Edit profile',
            subtitle: 'Name, photo',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            ),
          ),
          const SizedBox(height: 8),
          _tile(
            context,
            icon: Icons.phone_iphone_rounded,
            title: 'Connect to Servana Helper',
            subtitle: 'Open Helper app on Play Store',
            onTap: () => _showHelperConnectSheet(context),
          ),

          const SizedBox(height: 16),
          Text('Notifications', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          _NotificationsToggles(uid: uid),

          const SizedBox(height: 16),
          Text('Appearance & language', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          _appearanceSection(cs),

          const SizedBox(height: 16),
          Text('Safety & privacy', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          _tile(
            context,
            icon: Icons.shield_rounded,
            title: 'Emergency contacts',
            subtitle: 'Add a contact to notify in emergencies',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EmergencyContactsScreen()),
            ),
          ),

          const SizedBox(height: 16),
          Text('Legal & about', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          // ADD — Dispute Center entry
          _tile(
            context,
            icon: Icons.balance_rounded,
            title: 'Dispute Center',
            subtitle: 'View & resolve disputes, add evidence',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DisputeCenterScreen()),
            ),
          ),
          _tile(
            context,
            icon: Icons.description_rounded,
            title: 'Legal & terms',
            subtitle: 'View privacy policy and terms',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LegalScreen()),
            ),
          ),
          _tile(
            context,
            icon: Icons.info_rounded,
            title: 'About',
            subtitle: 'Version info',
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'Servana',
              applicationVersion: '1.0.0',
              applicationLegalese: '© ${DateTime.now().year} Servana',
            ),
          ),

          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            icon: _signingOut
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.logout_rounded),
            label: Text(_signingOut ? 'Logging out…' : 'Log out'),
            onPressed: _signingOut ? null : _signOut,
          ),
        ],
      ),
    );
  }

  Widget _appearanceSection(ColorScheme cs) {
    if (_loadingPrefs) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withOpacity(0.12)),
        ),
        child: const LinearProgressIndicator(),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Theme', style: TextStyle(fontWeight: FontWeight.w800)),
          RadioListTile<String>(
            title: const Text('System default'),
            value: 'system',
            groupValue: _themePref,
            onChanged: (v) => _onThemeChange(v!),
          ),
          RadioListTile<String>(
            title: const Text('Light'),
            value: 'light',
            groupValue: _themePref,
            onChanged: (v) => _onThemeChange(v!),
          ),
          RadioListTile<String>(
            title: const Text('Dark'),
            value: 'dark',
            groupValue: _themePref,
            onChanged: (v) => _onThemeChange(v!),
          ),
          const SizedBox(height: 12),
          const Text('Language', style: TextStyle(fontWeight: FontWeight.w800)),
          RadioListTile<String>(
            title: const Text('System default'),
            value: '',
            groupValue: _langPref,
            onChanged: (v) => _onLangChange(v!),
          ),
          RadioListTile<String>(
            title: const Text('English'),
            value: 'en',
            groupValue: _langPref,
            onChanged: (v) => _onLangChange(v!),
          ),
          RadioListTile<String>(
            title: const Text('සිංහල (Sinhala)'),
            value: 'si',
            groupValue: _langPref,
            onChanged: (v) => _onLangChange(v!),
          ),
          RadioListTile<String>(
            title: const Text('தமிழ் (Tamil)'),
            value: 'ta',
            groupValue: _langPref,
            onChanged: (v) => _onLangChange(v!),
          ),
        ],
      ),
    );
  }

  Widget _tile(
      BuildContext context, {
        required IconData icon,
        required String title,
        String? subtitle,
        required VoidCallback onTap,
      }) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outline.withOpacity(0.12)),
      ),
      tileColor: cs.surface,
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: subtitle == null ? null : Text(subtitle),
      onTap: onTap,
    );
  }
}

// ===== Header (name, phone, balance) =====

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.uid});
  final String? uid;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final userDoc = uid == null
        ? null
        : FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
    final walletDoc = uid == null
        ? null
        : FirebaseFirestore.instance.collection('wallets').doc(uid).snapshots();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          const CircleAvatar(radius: 26, child: Icon(Icons.person)),
          const SizedBox(width: 12),
          Expanded(
            child: uid == null
                ? const Text('Not signed in', style: TextStyle(fontWeight: FontWeight.w700))
                : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: userDoc,
              builder: (context, snap) {
                final data = snap.data?.data();
                final name = (data?['displayName'] ?? '').toString();
                final phone = (data?['phone'] ?? '').toString();
                final displayName = name.isEmpty ? 'Your account' : name;
                final displayPhone = phone.isEmpty
                    ? (FirebaseAuth.instance.currentUser?.phoneNumber ?? '')
                    : phone;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(displayPhone, style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          if (uid != null)
            _BalancePill(userDoc: userDoc!, walletDoc: walletDoc),
        ],
      ),
    );
  }
}

class _BalancePill extends StatelessWidget {
  const _BalancePill({required this.userDoc, required this.walletDoc});
  final Stream<DocumentSnapshot<Map<String, dynamic>>> userDoc;
  final Stream<DocumentSnapshot<Map<String, dynamic>>>? walletDoc;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userDoc,
      builder: (context, snap) {
        int? walletBalance;
        if (snap.hasData) {
          final u = snap.data!.data();
          final v = u?['walletBalance'];
          if (v is num) walletBalance = v.toInt();
        }
        if (walletBalance != null) {
          return _coinsColumn(walletBalance!);
        }
        // fallback to legacy wallets/{uid}.coins
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: walletDoc,
          builder: (context, wSnap) {
            final coins = (wSnap.data?.data()?['coins'] ?? 0);
            final c = (coins is num) ? coins.toInt() : 0;
            return _coinsColumn(c);
          },
        );
      },
    );
  }

  Widget _coinsColumn(int amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text('Balance', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        Text(
          '$amount',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

// ===== Notifications Toggles =====

class _NotificationsToggles extends StatefulWidget {
  const _NotificationsToggles({required this.uid});
  final String? uid;

  @override
  State<_NotificationsToggles> createState() => _NotificationsTogglesState();
}

class _NotificationsTogglesState extends State<_NotificationsToggles> {
  bool _push = true;
  bool _email = false;
  bool _sms = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = widget.uid;
      if (uid == null) return;
      final snap =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final s = snap.data()?['settings'] as Map<String, dynamic>?;

      setState(() {
        _push = (s?['push'] ?? true) == true;
        _email = (s?['email'] ?? false) == true;
        _sms = (s?['sms'] ?? false) == true;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    try {
      final uid = widget.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'settings': {'push': _push, 'email': _email, 'sms': _sms}
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification settings saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withOpacity(0.12)),
        ),
        child: const LinearProgressIndicator(),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Push notifications'),
            value: _push,
            onChanged: (v) => setState(() => _push = v),
          ),
          SwitchListTile(
            title: const Text('Email updates'),
            value: _email,
            onChanged: (v) => setState(() => _email = v),
          ),
          SwitchListTile(
            title: const Text('SMS updates'),
            value: _sms,
            onChanged: (v) => setState(() => _sms = v),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save'),
              onPressed: _save,
            ),
          ),
        ],
      ),
    );
  }
}

// ===== Edit Profile (inline) =====

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snap =
    await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final name = (snap.data()?['displayName'] ?? '').toString();
    _nameCtrl.text = name;
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {'displayName': name, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                icon: _saving
                    ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_rounded),
                label: const Text('Save'),
                onPressed: _saving ? null : _save,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline.withOpacity(0.12)),
              ),
              child: const Text(
                'Tip: Add more fields here later (photo, bio, languages, etc.).',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== Emergency Contacts (inline) =====

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});
  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _addContact() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) return;

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('emergencyContacts')
          .add({
        'name': name,
        'phone': phone,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _nameCtrl.clear();
      _phoneCtrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Emergency contacts')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone number'),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    icon: _saving
                        ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add_rounded),
                    label: const Text('Add'),
                    onPressed: _saving ? null : _addContact,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: uid == null
                ? const Center(child: Text('Not signed in'))
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('emergencyContacts')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('No contacts yet.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final c = docs[i].data();
                    final name = (c['name'] ?? '').toString();
                    final phone = (c['phone'] ?? '').toString();
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: cs.outline.withOpacity(0.12)),
                      ),
                      tileColor: cs.surface,
                      leading: const Icon(Icons.person_rounded),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(phone),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ===== Helper App Connect (Play Store) =====

const String _helperPackageId = 'com.servana.helper'; // TODO: real helper app id
final Uri _playStoreWebUri =
Uri.parse('https://play.google.com/store/apps/details?id=$_helperPackageId');

void _showHelperConnectSheet(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Connect to Servana Helper',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('Install/Update the Helper app from the Play Store.',
              style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          _helperLinkTile(
            context,
            icon: Icons.open_in_new_rounded,
            title: 'Copy Play Store link',
            subtitle: _playStoreWebUri.toString(),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: _playStoreWebUri.toString()));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied to clipboard')),
                );
              }
            },
          ),
        ],
      ),
    ),
  );
}

Widget _helperLinkTile(
    BuildContext context, {
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
    }) {
  final cs = Theme.of(context).colorScheme;
  return ListTile(
    onTap: onTap,
    leading: Icon(icon),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: cs.outline.withOpacity(0.12)),
    ),
    tileColor: cs.surface,
  );
}
