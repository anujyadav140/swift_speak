import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuickTipsCarousel extends StatefulWidget {
  final bool showDismissButton;
  final VoidCallback? onDismiss;

  const QuickTipsCarousel({
    super.key, 
    this.showDismissButton = true,
    this.onDismiss,
  });

  @override
  State<QuickTipsCarousel> createState() => _QuickTipsCarouselState();
}

class _QuickTipsCarouselState extends State<QuickTipsCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _tips = [
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
      height: 220,
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
            itemCount: _tips.length,
            itemBuilder: (context, index) {
              final tip = _tips[index];
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 50), // Increased bottom padding for dots/icon
                child: Stack(
                  children: [
                    Column(
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
                        const SizedBox(height: 12),
                        Expanded(
                          child: Text(
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
                        ),
                      ],
                    ),
                    // Icon or Image aligned above dots
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: tip.containsKey("image")
                            ? Padding(
                                padding: const EdgeInsets.only(top:30),
                                child: Image.asset(
                                  tip["image"] as String,
                                  height: screenWidth * 0.21,
                                  fit: BoxFit.contain,
                                ),
                              )
                            : Icon(
                                tip["icon"] as IconData,
                                size: iconSize,
                                color: Colors.white24,
                              ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          
          // Dots Indicator
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_tips.length, (index) {
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
          Positioned(
            bottom: 12,
            right: 16,
            child: TextButton(
              onPressed: () {
                if (_currentPage < _tips.length - 1) {
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
              child: Text(_currentPage == _tips.length - 1 ? "Finish" : "Next"),
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
