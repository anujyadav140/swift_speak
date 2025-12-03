import 'package:flutter/material.dart';

class TipsData {
  static const List<Map<String, dynamic>> setupTips = [
    {
      "title": "Step 1: Settings",
      "description": "Go to Settings > System",
      "icon": Icons.settings,
    },
    {
      "title": "Step 2: Manage Keyboards",
      "description": "Tap 'Keyboard' > 'On-screen keyboard'",
      "icon": Icons.keyboard,
    },
    {
      "title": "Step 3: Enable Swift Speak",
      "description": "Toggle 'Swift Speak' ON",
      "icon": Icons.toggle_on,
    },
    {
      "title": "Step 4: Trust",
      "description": "Tap 'OK' to trust the keyboard",
      "icon": Icons.check_circle,
    },
    {
      "title": "Step 5: Switch Keyboard",
      "description": "Tap 🌐 icon below the Gboard to switch to Swift Speak",
      "icon": Icons.language,
      "image": "assets/images/globe_instruction.png",
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
