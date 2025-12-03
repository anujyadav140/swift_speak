import 'package:flutter/material.dart';
import 'quick_tips_carousel.dart';
import 'tips_data.dart';

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
      body: SingleChildScrollView( // Added SingleChildScrollView for better layout
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Setup Guide",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const QuickTipsCarousel(
              showDismissButton: false,
              tips: TipsData.setupTips,
            ),
            const SizedBox(height: 32),
            
            Text(
              "Feature Tips",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const QuickTipsCarousel(
              showDismissButton: false,
              tips: TipsData.featureTips,
            ),
            
            const SizedBox(height: 24),
            Center(
              child: Text(
                "Follow these steps to get the most out of Swift Speak.",
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
