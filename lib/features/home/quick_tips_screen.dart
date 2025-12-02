import 'package:flutter/material.dart';

import 'quick_tips_carousel.dart';

class QuickTipsScreen extends StatelessWidget {
  const QuickTipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Quick Tips"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const QuickTipsCarousel(showDismissButton: false),
            const SizedBox(height: 24),
            Text(
              "Follow these steps to get the most out of Swift Speak.",
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
