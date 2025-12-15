import 'package:flutter/material.dart';

class TipsData {
  static const List<Map<String, dynamic>> setupTips = [
    {
      "title": "Enable Swift Speak",
      "description": "Tap 'Open Settings' below, then toggle 'Swift Speak' ON to start using the keyboard.",
      "showSettingsButton": true,
    },
  ];

  static const List<Map<String, dynamic>> featureTips = [
    {
      "title": "Change AI Model",
      "description": "Tap 'AI Model' in the menu to switch between Cloud and Local models.",
      "icon": Icons.psychology,
    },
    // Add more feature tips here in the future
  ];
}
