import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../auth/auth_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
          const SizedBox(height: 16),
          const Text(
            'Sylvelter Judin',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Text(
            'sylvelter@siswa.unimas.my',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          const Text('My Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.list_alt),
            title: const Text('My Reports (2)'),
            trailing: const Icon(Icons.chevron_right),
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onTap: () {},
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.handshake),
            title: const Text('My Claims (1 Pending)'),
            trailing: const Icon(Icons.chevron_right),
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onTap: () {},
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () async {
              await AuthService().signOut();
              if (!context.mounted) return;
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const AuthScreen()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}