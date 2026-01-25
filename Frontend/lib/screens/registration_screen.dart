import 'dart:convert';

import 'package:TheWord/providers/verse_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/settings_provider.dart';
import 'login_screen.dart';
import 'main_app.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _user = TextEditingController();
  bool _privacyPolicyAgreed = false;
  bool _isLoading = false;

  // ───────────────────────────────── helpers
  Future<bool> _login() async {
    try {
      final res = await http.post(
        Uri.parse('https://api.bybl.dev/api/login'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'email': _email.text, 'password': _pass.text}),
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final token = body['token'];
        if (token == null) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Login failed: no token returned')));
          return false;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        await prefs.setInt(
            'tokenExpiry',
            DateTime.now()
                .add(const Duration(days: 30))
                .millisecondsSinceEpoch);

        // await context.read<SettingsProvider>().loadSettings();
        // await context.read<VerseProvider>().fetchPublicVerses(reset: true);

        return true;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Login failed: ${res.body}')));
      return false;
    } catch (e, stack) {
      debugPrint('🔥 Error: $e\n$stack');
      debugPrint('Login error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login failed due to an error')));
      return false;
    }
  }

  Future<void> _register() async {
    if (!_privacyPolicyAgreed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('You must agree to the privacy policy.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await http.post(
        Uri.parse('https://api.bybl.dev/api/register'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'email': _email.text,
          'password': _pass.text,
          'username': _user.text,
        }),
      );

      if (res.statusCode == 201 || res.statusCode == 200) {
        // small delay to let the DB commit
        await Future.delayed(const Duration(seconds: 1));

        if (await _login()) {
          if (!mounted) return;
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/main', (route) => false);
        } else {
          // registration ok, login failed → bounce to login screen
          if (!mounted) return;
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const LoginScreen()));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Registration failed: ${res.body}')));
      }
    } catch (e, stack) {
      debugPrint('🔥 Error: $e\n$stack');
      debugPrint('Registration error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration failed due to an error')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPrivacyPolicyModal() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text('''
Bybl – Privacy Policy & Terms of Service
Last updated: May 3, 2025

Quick-Read Summary

- We collect only what we need: account info, usage logs, optional crash data, and content you choose to save.
- Your data stays encrypted in-flight and at rest (PostgreSQL, Wasabi S3).
- We never sell personal data. Period.
- Under 13? Please do not use Bybl without verified parental consent (COPPA).
- You control your content and can export or delete it at any time.

This “Quick-Read” is for convenience only. The legally binding document is the full text below.

1. Who We Are

bybl ("App") is an open-source Bible study application maintained by [well-edumacated] ("Company," "we," "our"). Our codebase is available publicly.
Contact: billy@bybl.dev

2. Scope

This combined Privacy Policy ("Policy") and Terms of Service ("Terms") governs your access to and use of the App, our APIs, and any related services (collectively, "Services"). By installing or using the Services you agree to these Terms. If you do not agree, do not use the Services.

3. Information We Collect

We collect the following types of information:
- Account Data: such as email, display name, hashed password, and profile image, to create and manage your account.
- User Content: including saved verses, notes, posts, and messages, to provide core functionality.
- Usage and Device Data: like log files, device model, OS version, and IP address, for debugging, abuse prevention, and analytics.
- Crash and Performance Data: such as stack traces via Sentry and performance metrics via New Relic, for stability and performance.
- Third-Party Content: Bible text via API.Bible and AI prompts via the OpenAI API, to deliver features.

We do not intentionally collect sensitive personal data (e.g., race, religion, health). Any such data appears only if you choose to include it.

4. How We Use Your Information

1. Provide the Services you request (e.g., display scripture, generate AI study aids).
2. Operate, maintain, and improve the App, fix bugs, and analyze performance.
3. Communicate with you about updates, security alerts, and support.
4. Protect the App, our users, and the public (fraud prevention, abuse detection).
5. Comply with legal requirements (e.g., court orders, lawful requests).

5. Legal Bases (GDPR / CCPA / etc.)

- Contract: Providing the Services you request.
- Legitimate Interest: Analytics, security, fraud prevention.
- Consent: Optional features such as marketing emails.
- Legal Obligation: Compliance with applicable laws.

6. Children’s Privacy (COPPA)

We do not knowingly collect personal information from children under 13. If you are a parent or guardian and believe your child has provided personal data, contact us at billy@bybl.dev and we will delete it. Children may use Bybl only with verifiable parental consent in accordance with COPPA.

7. Third-Party Services

We use the following services:
- Sentry: for error and crash reporting (e.g., stack traces, device info).
- New Relic: for performance monitoring (e.g., aggregated metrics).
- Firebase (optional): for push notifications and analytics (e.g., device tokens, event data).
- OpenAI API: for AI summaries and chat (e.g., user prompts, selected verses).
- API.Bible: for scripture text (e.g., anonymous metadata).
- Wasabi S3: for media storage (e.g., uploaded images, backups).

Each service has its own privacy policy. We only share the minimum data needed and have data-processing agreements where applicable.

8. How We Store & Protect Data

- Encryption in transit (TLS 1.2+) and at rest (AES-256) for PostgreSQL and S3.
- Least-privilege access controls and audited server logins.
- Regular security updates including OS patches, dependency scanning, and container hardening.
- Backups are encrypted and stored separately.

No system is 100% secure; use of the Services is at your own risk.

9. Your Rights & Choices

- Access / Portability: You can download a copy of your data.
- Correction: You can update inaccurate information.
- Deletion: You can delete your account and data.
- Opt-Out: You can disable analytics and crash reporting in Settings.
- Do Not Sell: We do not sell personal data.

Contact billy@bybl.dev to exercise your rights. We will verify and respond within the required timeframe.

10. International Transfers

We are based in the United States. If you access the Services from outside the US, you consent to transferring your data to the US and other countries where our providers operate.

11. Data Retention

We keep your data only as long as necessary to provide the Services and for legal or business purposes. Crash logs older than 90 days are automatically deleted unless needed for debugging.

12. Open Source Notice

The bybl client and server code are released under the MIT License. Using the open-source code does not grant you rights to the App’s trademarks or user database. Forks must remove proprietary branding.

13. Acceptable Use

You agree not to:
- Break any laws or regulations.
- Reverse-engineer or interfere with the Service.
- Upload harmful code or infringe intellectual property.
- Harass, abuse, or harm others.

Violations may lead to suspension or termination.

14. Disclaimers & Limitation of Liability

The Services are provided “as is” with no warranties. To the extent permitted by law, the Company is not liable for indirect or consequential damages. Our total liability is capped at the greater of \$50 or the amount you paid us in the past 12 months.

15. Indemnification

You agree to indemnify and hold the Company harmless from any claims related to your misuse of the Services or violation of these Terms.

16. Governing Law & Dispute Resolution

These Terms are governed by Illinois law. Disputes will be resolved by binding arbitration in Chicago, Illinois, except where either party seeks injunctive relief for IP violations.

17. Changes to This Document

We may update these Terms occasionally. You will be notified through the App or email at least 14 days in advance of material changes. Continued use after changes means you accept them.

18. Contact Us

For any questions, concerns, or requests, email billy@bybl.dev

   ''', style: TextStyle(fontSize: 14)),
        ),
        actions: [
          TextButton(
              onPressed: () {
                setState(() => _privacyPolicyAgreed = true);
                Navigator.pop(context);
              },
              child: const Text('Agree')),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Disagree')),
        ],
      ),
    );
  }

  // ───────────────────────────────── UI
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: const Text('Register')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _user,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                TextField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                TextField(
                  controller: _pass,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Checkbox(
                      value: _privacyPolicyAgreed,
                      onChanged: (v) {
                        if (v == true) {
                          _showPrivacyPolicyModal();
                        } else {
                          setState(() => _privacyPolicyAgreed = false);
                        }
                      },
                    ),
                    GestureDetector(
                      onTap: _showPrivacyPolicyModal,
                      child: const Text('I agree to the Privacy Policy',
                          style: TextStyle(
                              decoration: TextDecoration.underline,
                              color: Colors.blue)),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  child: const Text('Register'),
                ),
              ],
            ),
          ),
        ),

        // ─── loading overlay ───────────────────────────────────────
        if (_isLoading)
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
