// lib/features/profile/profile_button.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/supa.dart';

/// Call this from your AppBar gear:
/// showProfilePopup(context);
Future<void> showProfilePopup(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const ProfilePopup(), // just the menu
  );
}

/// The popup content with only Settings and Logout.
class ProfilePopup extends StatelessWidget {
  const ProfilePopup({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              context.push('/settings');
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () async {
              Navigator.pop(context);
              await supa.auth.signOut();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Signed out')),
                );
                // Optional: send user back to auth screen
                // context.go('/auth');
              }
            },
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
