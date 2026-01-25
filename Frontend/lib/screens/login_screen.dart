import 'dart:convert';

import 'package:TheWord/providers/bible_provider.dart';
import 'package:TheWord/providers/settings_provider.dart';
import 'package:TheWord/screens/forgot_password_screen.dart';
import 'package:TheWord/screens/registration_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/verse_provider.dart';
import 'main_app.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoggingIn = false; // ← new

  Future<bool> _login() async {
    try {
      final response = await http.post(
        Uri.parse('https://api.bybl.dev/api/login'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'email': _emailController.text,
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final token = body['token'] as String;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        await prefs.setInt(
          'tokenExpiry',
          DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
        );

        final settings = context.read<SettingsProvider>();

        await context
            .read<BibleProvider>()
            .fetchBooks(settings.currentTranslationId!);


        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  void _navigateTo(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: const Text('Login')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoggingIn
                      ? null
                      : () async {
                          setState(() => _isLoggingIn = true);
                          final ok = await _login();
                          setState(() => _isLoggingIn = false);

                          if (ok) {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                                '/main', (route) => false);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Login failed. Please check your credentials.'),
                                duration: Duration(seconds: 3),
                              ),
                            );
                          }
                        },
                  child: const Text('Login'),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => _navigateTo(RegistrationScreen()),
                  child: Text(
                    'Don\'t have an account?\n         Sign up here',
                    style: TextStyle(
                        color: theme.primaryTextTheme.bodyMedium?.color),
                    textAlign: TextAlign.left,
                  ),
                ),
                TextButton(
                  onPressed: () => _navigateTo(ForgotPasswordScreen()),
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(decoration: TextDecoration.underline),
                  ),
                ),
                const Spacer(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),

        // 🔽 overlay during login
        if (_isLoggingIn)
          Positioned.fill(
            child: Container(
              color: Colors.black45,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }
}
