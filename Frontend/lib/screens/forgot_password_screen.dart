import 'package:TheWord/screens/reset_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ForgotPasswordScreen extends StatefulWidget {
  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _loading = false;

  Future<void> _requestReset() async {
    setState(() => _loading = true);
    final response = await http.post(
      Uri.parse('https://api.bybl.dev/api/request-password-reset'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': _emailController.text.trim()}),
    );
    setState(() => _loading = false);

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('If that email exists, a reset code was sent.')),
      );
      Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) =>
                ResetPasswordScreen(email: _emailController.text.trim())),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${response.body}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Enter your email to receive a reset code.'),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 20),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _requestReset,
                    child: const Text('Send Reset Code'),
                  ),
          ],
        ),
      ),
    );
  }
}
