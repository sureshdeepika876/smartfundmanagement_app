import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import 'login_screen.dart';
import 'goals_screen.dart';
import 'group_split_screen.dart';
import 'chatbot_screen.dart';

class SettingsScreen extends StatefulWidget {
  final bool embedded;
  const SettingsScreen({super.key, this.embedded = false});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    // Dark mode / currency now come from Firestore (SettingsService) so they
    // survive app restarts and reinstalls instead of resetting every time.
    final settings = context.watch<SettingsService>();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          const Text('Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(user?.displayName ?? 'User'),
              subtitle: Text(user?.email ?? ''),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                // SwitchListTile(
                //   title: const Text('Dark Mode'),
                //   secondary: const Icon(Icons.dark_mode_outlined),
                //   value: settings.darkMode,
                //   onChanged: (v) => settings.setDarkMode(v),
                // ),
                // ListTile(
                //   leading: const Icon(Icons.attach_money),
                //   title: const Text('Currency'),
                //   trailing: DropdownButton<String>(
                //     value: settings.currency,
                //     items: ['INR (₹)', 'USD (\$)', 'EUR (€)'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                //     onChanged: (v) => settings.setCurrency(v!),
                //   ),
                // ),
                // ListTile(
                //   leading: const Icon(Icons.notifications_outlined),
                //   title: const Text('Notification Settings'),
                //   trailing: const Icon(Icons.chevron_right),
                //   onTap: () {},
                // ),
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('Savings Goals'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalsScreen())),
                ),
                ListTile(
                  leading: const Icon(Icons.groups_outlined),
                  title: const Text('Group Expense Split'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupSplitScreen())),
                ),
                ListTile(
                  leading: const Icon(Icons.smart_toy_outlined),
                  title: const Text('AI Finance Assistant'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatbotScreen())),
                ),
                // ListTile(
                //   leading: const Icon(Icons.privacy_tip_outlined),
                //   title: const Text('Privacy'),
                //   trailing: const Icon(Icons.chevron_right),
                //   onTap: () {},
                // ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () async {
                context.read<SettingsService>().reset();
                await context.read<AuthService>().logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
