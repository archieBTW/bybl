import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ApiKeySetupPrompt extends StatelessWidget {
  final VoidCallback? onGoToSettings;

  const ApiKeySetupPrompt({Key? key, this.onGoToSettings}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/icon/archie.png',
              width: 120,
              height: 120,
            ),
            const SizedBox(height: 24),
            Text(
              'Set Up AI Features',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'To chat with Archie and use AI features, you need to add your Gemini API key in Settings.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[400],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How to get an API key:',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  _buildStep(context, '1', 'Go to Google AI Studio'),
                  _buildStep(context, '2', 'Sign in with your Google account'),
                  _buildStep(context, '3', 'Click "Get API Key" and create one'),
                  _buildStep(context, '4', 'Copy the key and paste it in Settings'),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        launchUrl(Uri.parse('https://aistudio.google.com/apikey'));
                      },
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Open Google AI Studio'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (onGoToSettings != null)
              ElevatedButton.icon(
                onPressed: onGoToSettings,
                icon: const Icon(Icons.settings),
                label: const Text('Go to Settings'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
