import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'features/auth/auth_gate.dart';
import 'features/auth/auth_screen.dart';
import 'features/moments/create_moment_screen.dart';
import 'features/profile/edit_profile_screen.dart';
import 'features/chats/chats_screen.dart';
import 'features/chats/chat_screen.dart';
import 'features/coins/wallet_screen.dart';
import 'features/calls/call_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/profile/settings_screen.dart';
import 'features/users/users_tab.dart';
import "features/profile/profile_view_screen.dart";

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (c, s) => const AuthGate(child: HomeTabs()),
      routes: [
        GoRoute(path: 'auth', builder: (c, s) => const AuthScreen()),
        GoRoute(
          path: 'profile/edit',
          builder: (c, s) => const EditProfileScreen(),
        ),
        GoRoute(
          path: 'moments/new',
          builder: (c, s) => const CreateMomentScreen(),
        ),
        GoRoute(path: 'chats', builder: (c, s) => const ChatsScreen()),
        GoRoute(
          path: '/chat/:convId',
          builder: (c, s) {
            final convId = s.pathParameters['convId']!;
            final auto =
                (s.extra is Map && (s.extra as Map)['autofocus'] == true);
            return ChatScreen(convId: convId, autofocusComposer: auto);
          },
        ),
        GoRoute(path: 'wallet', builder: (c, s) => const WalletScreen()),
        GoRoute(
          path: 'call/:peer',
          builder: (c, s) => CallScreen(peerId: s.pathParameters['peer']!),
        ),
        GoRoute(path: 'profile', builder: (c, s) => const ProfileScreen()),
        GoRoute(path: 'settings', builder: (c, s) => const SettingsScreen()),
        // 🔹 New Profile View route
        GoRoute(
          path: 'profile/view/:userId',
          name: 'profileView',
          builder: (c, s) =>
              ProfileViewScreen(userId: s.pathParameters['userId']!),
        ),
      ],
    ),
  ],
);

class HomeTabs extends StatefulWidget {
  const HomeTabs({super.key});
  @override
  State<HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends State<HomeTabs> {
  int idx = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [
      const PeopleTab(),
      const ChatsScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: pages[idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) => setState(() => idx = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            label: 'People',
          ),
          NavigationDestination(
            icon: Icon(Icons.message_outlined),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(Icons.verified_user_outlined),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
