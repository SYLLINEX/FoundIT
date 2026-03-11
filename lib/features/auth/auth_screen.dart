import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../home/main_wrapper.dart';
import '../admin/admin_dashboard_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        body: SafeArea(
          // Ensure it stretches behind the system navigation via Scaffold's background
          bottom: false, 
          child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.travel_explore, size: 80, color: Color(0xFF1E3A8A)),
                const SizedBox(height: 16),
                const Text(
                  'FoundIT',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                ),
                const Text(
                  'Campus Lost & Found System',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 48),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'University Email', prefixIcon: Icon(Icons.email)),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock)),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    // Navigate to Main App
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainWrapper()));
                  },
                  child: Text(isLogin ? 'Login' : 'Register'),
                ),
                TextButton(
                  onPressed: () => setState(() => isLogin = !isLogin),
                  child: Text(isLogin ? 'New here? Create an account' : 'Already have an account? Login'),
                ),
                // Quick Admin Access for Prototype
                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
                  },
                  child: const Text('Login as SRC Admin (Demo)', style: TextStyle(color: Colors.orange)),
                )
              ],
            ),
          ),
        ),
      ),
      )
    );
  }
}