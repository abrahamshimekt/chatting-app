import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: const [
          ListTile(leading: Icon(Icons.lock), title: Text('Privacy')),
          Divider(height: 1),
          ListTile(leading: Icon(Icons.notifications), title: Text('Notifications')),
        ],
      ),
    );
  }
}
