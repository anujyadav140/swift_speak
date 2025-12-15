import 'package:flutter/material.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuickTipsCarousel extends StatefulWidget {
  final bool showDismissButton;
  final VoidCallback? onDismiss;
  final List<Map<String, dynamic>> tips;

  const QuickTipsCarousel({
    super.key, 
    this.showDismissButton = true,
    this.onDismiss,
    required this.tips,
  });

  @override
  State<QuickTipsCarousel> createState() => _QuickTipsCarouselState();
}

class _QuickTipsCarouselState extends State<QuickTipsCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleDismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showQuickTips', false);
    if (widget.onDismiss != null) {
      widget.onDismiss!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double titleSize = screenWidth * 0.05; // Reduced from 0.06
    final double descSize = screenWidth * 0.04; // Reduced from 0.045
    final double iconSize = screenWidth * 0.15; // Increased from 0.12

    return Container(
      height: 200, // Increased height
      decoration: BoxDecoration(
        color: const Color(0xFF263238),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: widget.tips.length,
            itemBuilder: (context, index) {
              final tip = widget.tips[index];
              return Padding(
                padding: const EdgeInsets.all(20), // Reduced padding
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tip["title"] as String,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: titleSize,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.left,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tip["description"] as String,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: descSize,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.left,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (tip["showSettingsButton"] == true) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 36,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (Theme.of(context).platform == TargetPlatform.android) {
                              const intent = AndroidIntent(
                                action: 'android.settings.INPUT_METHOD_SETTINGS',
                              );
                              await intent.launch();
                            }
                          },
                          icon: const Icon(Icons.settings, size: 18),
                          label: const Text("Open Settings"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.15),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          
          // Dots Indicator
          if (widget.tips.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.tips.length, (index) {
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.3),
                    ),
                  );
                }),
              ),
            ),

          // Next/Finish Button (Bottom Right)
          if (widget.tips.length > 1)
            Positioned(
              bottom: 12,
              right: 16,
              child: TextButton(
                onPressed: () {
                  if (_currentPage < widget.tips.length - 1) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  } else {
                    // Finish action: Redirect to first page
                    _pageController.animateToPage(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  textStyle: TextStyle(
                    fontSize: descSize, // Match description size
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: Text(_currentPage == widget.tips.length - 1 ? "Finish" : "Next"),
              ),
            ),

          // Dismiss Button (Top Right) - Bigger 'X' Icon
          if (widget.showDismissButton)
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                onPressed: _handleDismiss,
                icon: const Icon(Icons.close, color: Colors.white70, size: 28), // Bigger size
                tooltip: "Don't show again",
              ),
            ),
        ],
      ),
    );
  }
}
