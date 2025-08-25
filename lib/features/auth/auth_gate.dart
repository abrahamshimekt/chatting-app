import 'package:flutter/material.dart';
import '../../core/supa.dart';
import 'auth_screen.dart';

class AuthGate extends StatelessWidget {
  final Widget child;
  const AuthGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: supa.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supa.auth.currentSession;
        if (session == null) return const AuthScreen();
        return child;
      },
    );
  }
}
