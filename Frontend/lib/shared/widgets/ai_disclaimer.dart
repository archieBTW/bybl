import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AiDisclaimer extends StatelessWidget {
  final bool compact;
  
  const AiDisclaimer({
    Key? key,
    this.compact = false,
  }) : super(key: key);

  Future<void> _sendReportEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'billy@blilyrigdon.dev',
      queryParameters: {
        'subject': 'AI Response Report',
        'body': 'I would like to report an issue with an AI-generated response:\n\n[Please describe the issue here]'
      },
    );
    
    try {
      await launchUrl(emailUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch email: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 12,
            color: Colors.grey[500],
          ),
          const SizedBox(width: 4),
          Text(
            'AI-generated content may include mistakes',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendReportEmail,
            child: Text(
              'Report',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 14,
            color: Colors.grey[500],
          ),
          const SizedBox(width: 6),
          Text(
            'AI-generated content may contain errors',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendReportEmail,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[600]!, width: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Report',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

