import 'dart:convert';

import 'package:TheWord/providers/settings_provider.dart';
import 'package:TheWord/providers/verse_provider.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main_app.dart';

class ChurchRegistrationScreen extends StatefulWidget {
  const ChurchRegistrationScreen({Key? key}) : super(key: key);

  @override
  State<ChurchRegistrationScreen> createState() =>
      _ChurchRegistrationScreenState();
}

class _ChurchRegistrationScreenState extends State<ChurchRegistrationScreen> {
  // ───────────────────────────────── text controllers
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _user = TextEditingController();
  final _cName = TextEditingController();
  final _cDesc = TextEditingController();
  final _cAddr = TextEditingController();
  final _cCity = TextEditingController();
  final _cZip = TextEditingController();
  final _cPhone = TextEditingController();
  final _cSite = TextEditingController();

  bool _privacyPolicyAgreed = false;
  bool _isLoading = false;
  String? _selectedState;
  final _formKey = GlobalKey<FormState>();

  static const _states = [
    'AL',
    'AK',
    'AZ',
    'AR',
    'CA',
    'CO',
    'CT',
    'DE',
    'FL',
    'GA',
    'HI',
    'ID',
    'IL',
    'IN',
    'IA',
    'KS',
    'KY',
    'LA',
    'ME',
    'MD',
    'MA',
    'MI',
    'MN',
    'MS',
    'MO',
    'MT',
    'NE',
    'NV',
    'NH',
    'NJ',
    'NM',
    'NY',
    'NC',
    'ND',
    'OH',
    'OK',
    'OR',
    'PA',
    'RI',
    'SC',
    'SD',
    'TN',
    'TX',
    'UT',
    'VT',
    'VA',
    'WA',
    'WV',
    'WI',
    'WY'
  ];

  // ───────────────────────────────── validation helpers
  String? _vEmail(String? v) => (v == null || v.isEmpty)
      ? 'Please enter an email address'
      : !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)
          ? 'Please enter a valid email address'
          : null;

  String? _vPass(String? v) => (v == null || v.isEmpty)
      ? 'Please enter a password'
      : v.length < 8
          ? 'Password must be at least 8 characters long'
          : null;

  String? _vReq(String? v, String f) =>
      (v == null || v.isEmpty) ? 'Please enter $f' : null;

  String? _vPhone(String? v) {
    if (v == null || v.isEmpty) return 'Please enter a phone number';
    final d = v.replaceAll(RegExp(r'[^\d]'), '');
    return d.length == 10 ? null : 'Please enter a valid 10-digit phone number';
  }

  String _fmtPhone(String v) {
    final d = v.replaceAll(RegExp(r'[^\d]'), '');
    if (d.length >= 10)
      return '(${d.substring(0, 3)}) ${d.substring(3, 6)}-${d.substring(6, 10)}';
    else if (d.length >= 6)
      return '(${d.substring(0, 3)}) ${d.substring(3, 6)}-${d.substring(6)}';
    else if (d.length >= 3) return '(${d.substring(0, 3)}) ${d.substring(3)}';
    return d;
  }

  String? _vSite(String? v) {
    if (v == null || v.isEmpty) return 'Please enter a website';
    return !RegExp(r'^(https?:\/\/)?([\w-]+\.)+[\w-]+(\/[\w- .\/?%&=]*)?$')
            .hasMatch(v)
        ? 'Please enter a valid website'
        : null;
  }

  String? _vZip(String? v) {
    if (v == null || v.isEmpty) return 'Please enter a ZIP code';
    return !RegExp(r'^\d{5}(-\d{4})?$').hasMatch(v)
        ? 'Please enter a valid ZIP code'
        : null;
  }

  // ───────────────────────────────── auth helpers
  Future<bool> _login() async {
    try {
      final r = await http.post(
        Uri.parse('https://api.bybl.dev/api/login'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'email': _email.text, 'password': _pass.text}),
      );
      if (r.statusCode == 200) {
        final token = jsonDecode(r.body)['token'] as String;
        final p = await SharedPreferences.getInstance();
        await p.setString('token', token);
        await p.setInt(
            'tokenExpiry',
            DateTime.now()
                .add(const Duration(days: 30))
                .millisecondsSinceEpoch);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_privacyPolicyAgreed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('You must agree to the privacy policy.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1️⃣  create church-leader user
      final uRes = await http.post(
        Uri.parse('https://api.bybl.dev/api/church-leaders'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'email': _email.text,
          'password': _pass.text,
          'username': _user.text,
        }),
      );
      if (uRes.statusCode != 200 && uRes.statusCode != 201) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('User registration failed: ${uRes.body}'),
            duration: const Duration(seconds: 5)));
        return;
      }

      // 2️⃣  log them in to get token
      if (!await _login()) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Login failed'), duration: Duration(seconds: 5)));
        return;
      }
      final token = (await SharedPreferences.getInstance()).getString('token');

      // 3️⃣  create church
      final cRes = await http.post(
        Uri.parse('https://api.bybl.dev/api/churches'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': _cName.text,
          'description': _cDesc.text,
          'address': _cAddr.text,
          'city': _cCity.text,
          'state': _selectedState,
          'zipCode': _cZip.text,
          'phone': _cPhone.text,
          'website': _cSite.text,
          'email': _email.text,
        }),
      );
      if (cRes.statusCode != 200 && cRes.statusCode != 201) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Church registration failed: ${cRes.body}'),
            duration: const Duration(seconds: 5)));
        return;
      }

      await context.read<SettingsProvider>().loadSettings();
      await context.read<VerseProvider>().fetchPublicVerses(reset: true);

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
    } catch (e) {
      debugPrint('Registration error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Registration failed: $e'),
          duration: const Duration(seconds: 5)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPrivacyPolicyModal() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(child: Text('''
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

   ''', style: TextStyle(fontSize: 14))),
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
    final theme = Theme.of(context);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: const Text('Church Registration')),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Church Leader Information',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextFormField(
                      controller: _user,
                      decoration: const InputDecoration(labelText: 'Username'),
                      validator: (v) => _vReq(v, 'username')),
                  const SizedBox(height: 8),
                  TextFormField(
                      controller: _email,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      validator: _vEmail),
                  const SizedBox(height: 8),
                  TextFormField(
                      controller: _pass,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      validator: _vPass),
                  const SizedBox(height: 24),
                  const Text('Church Information',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextFormField(
                      controller: _cName,
                      decoration:
                          const InputDecoration(labelText: 'Church Name'),
                      validator: (v) => _vReq(v, 'church name')),
                  const SizedBox(height: 8),
                  TextFormField(
                      controller: _cDesc,
                      decoration: const InputDecoration(
                          labelText: 'Church Description'),
                      maxLines: 3,
                      validator: (v) => _vReq(v, 'church description')),
                  const SizedBox(height: 8),
                  TextFormField(
                      controller: _cAddr,
                      decoration: const InputDecoration(labelText: 'Address'),
                      validator: (v) => _vReq(v, 'address')),
                  const SizedBox(height: 8),
                  TextFormField(
                      controller: _cCity,
                      decoration: const InputDecoration(labelText: 'City'),
                      validator: (v) => _vReq(v, 'city')),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _selectedState,
                        decoration: const InputDecoration(
                            labelText: 'State', border: OutlineInputBorder()),
                        items: _states
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedState = v),
                        validator: (v) => v == null || v.isEmpty
                            ? 'Please select a state'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                          controller: _cZip,
                          decoration:
                              const InputDecoration(labelText: 'ZIP Code'),
                          keyboardType: TextInputType.number,
                          validator: _vZip),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  TextFormField(
                      controller: _cPhone,
                      decoration:
                          const InputDecoration(labelText: 'Phone Number'),
                      keyboardType: TextInputType.phone,
                      validator: _vPhone,
                      onChanged: (v) {
                        final f = _fmtPhone(v);
                        if (f != v) {
                          _cPhone.value = TextEditingValue(
                              text: f,
                              selection:
                                  TextSelection.collapsed(offset: f.length));
                        }
                      }),
                  const SizedBox(height: 8),
                  TextFormField(
                      controller: _cSite,
                      decoration: const InputDecoration(labelText: 'Website'),
                      keyboardType: TextInputType.url,
                      validator: _vSite),
                  const SizedBox(height: 16),
                  Row(children: [
                    Checkbox(
                        value: _privacyPolicyAgreed,
                        onChanged: (v) {
                          if (v == true)
                            _showPrivacyPolicyModal();
                          else
                            setState(() => _privacyPolicyAgreed = false);
                        }),
                    GestureDetector(
                      onTap: _showPrivacyPolicyModal,
                      child: const Text('I agree to the Privacy Policy',
                          style: TextStyle(
                              decoration: TextDecoration.underline,
                              color: Colors.blue)),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    child: const Text('Register Church'),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ─── full-screen loading overlay ────────────────────────────
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
