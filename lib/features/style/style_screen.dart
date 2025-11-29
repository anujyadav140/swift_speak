import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/border_beam_painter.dart';

class StyleScreen extends StatefulWidget {
  const StyleScreen({super.key});

  @override
  State<StyleScreen> createState() => _StyleScreenState();
}

class _StyleScreenState extends State<StyleScreen> with TickerProviderStateMixin {
  int _selectedStyleIndex = 0;
  int _selectedCategoryIndex = 0;
  int? _expandedIndex;
  late final List<StyleCategory> _categories;
  late AnimationController _beamController;

  @override
  void initState() {
    super.initState();
    _beamController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    _categories = [
      StyleCategory(
        title: "DMs",
        bannerText: "This style applies in personal messengers",
        bannerIcons: [Icons.facebook, Icons.chat_bubble, Icons.telegram],
        bannerColors: [Colors.blue, Colors.greenAccent, Colors.lightBlue],
        options: [
          StyleOption(
            title: "Formal.",
            description: "Caps + Punctuation",
            sampleText: "Hey, are you free for lunch tomorrow? Let's do 12 if that works for you.",
            highlights: [
              TextHighlight(0, 1, Colors.black), // H
              TextHighlight(3, 4, Colors.black), // ,
              TextHighlight(36, 37, Colors.black), // ?
              TextHighlight(38, 39, Colors.black), // L
              TextHighlight(41, 42, Colors.black), // '
              TextHighlight(71, 72, Colors.black), // .
            ],
            avatarColor: const Color(0xFFE1BEE7),
          ),
          StyleOption(
            title: "Casual",
            description: "Caps + Less punctuation",
            sampleText: "Hey are you free for lunch tomorrow? Let's do 12 if that works for you",
            highlights: [
              TextHighlight(0, 1, Colors.black), // H
              TextHighlight(37, 38, Colors.black), // L
            ],
            avatarColor: const Color(0xFFF8BBD0),
          ),
          StyleOption(
            title: "very casual",
            description: "No Caps + Less punctuation",
            sampleText: "hey are you free for lunch tomorrow? let's do 12 if that works for you",
            highlights: [
              TextHighlight(0, 1, Colors.black), // h
            ],
            avatarColor: const Color(0xFF7E57C2),
          ),
        ],
      ),
      StyleCategory(
        title: "Work messages",
        bannerText: "This style applies in workplace messengers",
        bannerIcons: [Icons.work, Icons.group_work, Icons.business],
        bannerColors: [Colors.deepPurple, Colors.teal, Colors.blueGrey],
        options: [
          StyleOption(
            title: "Formal.",
            description: "Caps + Punctuation",
            sampleText: "Hey, if you're free, let's chat about the great results.",
            highlights: [
              TextHighlight(0, 1, Colors.black), // H
              TextHighlight(3, 4, Colors.black), // ,
              TextHighlight(19, 20, Colors.black), // ,
              TextHighlight(55, 56, Colors.black), // .
            ],
            senderName: "John Doe",
            time: "9:45 AM",
            avatarColor: const Color(0xFFE1BEE7),
          ),
          StyleOption(
            title: "Casual",
            description: "Caps + Less punctuation",
            sampleText: "Hey, if you're free let's chat about the great results",
            highlights: [
              TextHighlight(0, 1, Colors.black), // H
            ],
            senderName: "John Doe",
            time: "9:45 AM",
            avatarColor: const Color(0xFFF8BBD0),
          ),
          StyleOption(
            title: "Excited!",
            description: "More exclamations",
            sampleText: "Hey, if you're free, let's chat about the great results!",
            highlights: [
              TextHighlight(55, 56, Colors.black), // !
            ],
            senderName: "John Doe",
            time: "9:45 AM",
            avatarColor: const Color(0xFF7E57C2),
          ),
        ],
      ),
      StyleCategory(
        title: "Email",
        bannerText: "This style applies in all major email apps",
        bannerIcons: [Icons.mail, Icons.email, Icons.mark_email_read],
        bannerColors: [Colors.red, Colors.blue, Colors.orange],
        options: [
          StyleOption(
            title: "Formal.",
            description: "Caps + Punctuation",
            sampleText: "Hi Alex,\n\nIt was great talking with you today. Looking forward to our next chat.\n\nBest,\nMary",
            highlights: [
              TextHighlight(0, 1, Colors.black), // H
              TextHighlight(7, 8, Colors.black), // ,
              TextHighlight(10, 11, Colors.black), // I
              TextHighlight(45, 46, Colors.black), // .
              TextHighlight(47, 48, Colors.black), // L
              TextHighlight(79, 80, Colors.black), // .
              TextHighlight(81, 82, Colors.black), // B
              TextHighlight(86, 87, Colors.black), // ,
            ],
            recipient: "Alex Doe",
            avatarColor: const Color(0xFFE1BEE7),
          ),
          StyleOption(
            title: "Casual",
            description: "Caps + Less punctuation",
            sampleText: "Hi Alex, it was great talking with you today. Looking forward to our next chat.\n\nBest,\nMary",
            highlights: [
              TextHighlight(0, 1, Colors.black), // H
            ],
            recipient: "Alex Doe",
            avatarColor: const Color(0xFFF8BBD0),
          ),
          StyleOption(
            title: "Excited!",
            description: "More exclamations",
            sampleText: "Hi Alex!\n\nIt was great talking with you today. Looking forward to our next chat!\n\nBest,\nMary",
            highlights: [
              TextHighlight(7, 8, Colors.black), // !
            ],
            recipient: "Alex Doe",
            avatarColor: const Color(0xFF7E57C2),
          ),
        ],
      ),
      StyleCategory(
        title: "Other",
        bannerText: "This style applies in all other apps",
        bannerIcons: [Icons.description, Icons.article, Icons.note],
        bannerColors: [Colors.blue, Colors.grey, Colors.amber],
        options: [
          StyleOption(
            title: "Formal.",
            description: "Caps + Punctuation",
            sampleText: "So far, I am enjoying the new workout routine.\n\nI am excited for tomorrow's workout, especially after a full night of rest.",
            highlights: [
              TextHighlight(6, 7, Colors.black), // ,
              TextHighlight(45, 46, Colors.black), // .
              TextHighlight(83, 84, Colors.black), // ,
              TextHighlight(122, 123, Colors.black), // .
            ],
            avatarColor: const Color(0xFFE1BEE7),
          ),
          StyleOption(
            title: "Casual",
            description: "Caps + Less punctuation",
            sampleText: "So far I am enjoying the new workout routine.\n\nI am excited for tomorrow's workout especially after a full night of rest.",
            highlights: [
              TextHighlight(0, 1, Colors.black), // S
            ],
            avatarColor: const Color(0xFFF8BBD0),
          ),
          StyleOption(
            title: "Excited!",
            description: "More exclamations",
            sampleText: "So far, I am enjoying the new workout routine.\n\nI am excited for tomorrow's workout, especially after a full night of rest!",
            highlights: [
              TextHighlight(122, 123, Colors.black), // !
            ],
            avatarColor: const Color(0xFF7E57C2),
          ),
        ],
      ),
    ];
  }

  @override
  void dispose() {
    _beamController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final currentCategory = _categories[_selectedCategoryIndex];
    final currentStyles = currentCategory.options;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Row(
                children: [
                  ..._categories.asMap().entries.map((entry) {
                    final index = entry.key;
                    final category = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(right: 24),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCategoryIndex = index;
                            _selectedStyleIndex = 0; // Reset style selection on category change
                            _expandedIndex = null; // Collapse any expanded item
                          });
                        },
                        child: _buildTab(category.title, _selectedCategoryIndex == index, isDark),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Info Banner
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  // Info Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FBE7), // Light Lime/Yellow
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Row(
                      children: [
                        // Icons stack
                        SizedBox(
                          width: 80,
                          height: 40,
                          child: Stack(
                            children: [
                              _buildAppIcon(currentCategory.bannerIcons[0], currentCategory.bannerColors[0], 0),
                              _buildAppIcon(currentCategory.bannerIcons[1], currentCategory.bannerColors[1], 20),
                              _buildAppIcon(currentCategory.bannerIcons[2], currentCategory.bannerColors[2], 40),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentCategory.bannerText,
                                style: GoogleFonts.ebGaramond(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                "Available on desktop in English. iOS and more languages coming soon",
                                style: GoogleFonts.ebGaramond(
                                  fontSize: 14,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // List Items
                  ...currentStyles.asMap().entries.map((entry) {
                    final index = entry.key;
                    final style = entry.value;
                    final isSelected = _selectedStyleIndex == index;
                    final isExpanded = _expandedIndex == index;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_expandedIndex == index) {
                              _expandedIndex = null;
                            } else {
                              _expandedIndex = index;
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[900] : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected 
                                  ? (isDark ? Colors.white : Colors.black) 
                                  : Colors.grey.withOpacity(0.2),
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: [
                              if (!isDark)
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          style.title,
                                          style: GoogleFonts.ebGaramond(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          style.description.toUpperCase(),
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white54 : Colors.black54,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected && !isExpanded)
                                    Icon(Icons.check_circle, color: isDark ? Colors.white : Colors.black)
                                  else
                                    AnimatedRotation(
                                      turns: isExpanded ? 0.25 : 0,
                                      duration: const Duration(milliseconds: 200),
                                      child: Icon(Icons.chevron_right, color: Colors.grey),
                                    ),
                                ],
                              ),
                              
                              // Expanded Content
                              AnimatedSize(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                alignment: Alignment.topCenter,
                                child: isExpanded
                                    ? Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 20),
                                          Divider(color: Colors.grey.withOpacity(0.2)),
                                          const SizedBox(height: 20),
                                          _buildStyleContent(style, isDark, currentCategory.title),
                                          const SizedBox(height: 20),
                                          // Select Button
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _selectedStyleIndex = index;
                                                  });
                                                },
                                                child: CustomPaint(
                                                  foregroundPainter: isSelected 
                                                      ? BorderBeamPainter(
                                                          animation: _beamController, 
                                                          borderRadius: 30,
                                                          color: isDark ? Colors.white : Colors.black,
                                                        ) 
                                                      : null,
                                                  child: AnimatedContainer(
                                                    duration: const Duration(milliseconds: 200),
                                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                                    decoration: BoxDecoration(
                                                      color: isSelected 
                                                          ? (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)) 
                                                          : Colors.transparent,
                                                      borderRadius: BorderRadius.circular(30),
                                                      border: isSelected 
                                                          ? Border.all(color: Colors.transparent)
                                                          : Border.all(color: Colors.grey.withOpacity(0.5), width: 1.5),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        if (isSelected) ...[
                                                          Icon(
                                                            Icons.check,
                                                            color: isDark ? Colors.white : Colors.black,
                                                            size: 18,
                                                          ),
                                                          const SizedBox(width: 8),
                                                        ],
                                                        Text(
                                                          isSelected ? "Selected" : "Select",
                                                          style: GoogleFonts.ebGaramond(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.w600,
                                                            color: isDark ? Colors.white : Colors.black,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String text, bool isSelected, bool isDark) {
    return IntrinsicWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            text,
            style: GoogleFonts.ebGaramond(
              fontSize: 18,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected 
                  ? (isDark ? Colors.white : Colors.black) 
                  : Colors.grey,
            ),
          ),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 2,
              color: isDark ? Colors.white : Colors.black,
            ),
        ],
      ),
    );
  }

  Widget _buildAppIcon(IconData icon, Color color, double leftMargin) {
    return Positioned(
      left: leftMargin,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  Widget _buildStyleContent(StyleOption style, bool isDark, String categoryTitle) {
    if (style.recipient != null) {
      // Email Layout
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
            ),
            child: Text(
              "To: ${style.recipient}",
              style: GoogleFonts.ebGaramond(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              children: _buildTextSpans(style, isDark),
              style: GoogleFonts.ebGaramond(
                fontSize: 16,
                height: 1.4,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      );
    } else if (style.senderName != null) {
      // Work Message Layout
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: style.avatarColor,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              style.senderName![0],
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      style.senderName!,
                      style: GoogleFonts.ebGaramond(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      style.time!,
                      style: GoogleFonts.ebGaramond(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    children: _buildTextSpans(style, isDark),
                    style: GoogleFonts.ebGaramond(
                      fontSize: 16,
                      height: 1.4,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else if (categoryTitle == "Other") {
      // Document/Other Layout
      return RichText(
        text: TextSpan(
          children: _buildTextSpans(style, isDark),
          style: GoogleFonts.ebGaramond(
            fontSize: 16,
            height: 1.4,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      );
    } else {
      // Default DM Bubble Layout
      return Align(
        alignment: Alignment.bottomLeft,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
            ),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: RichText(
            text: TextSpan(
              children: _buildTextSpans(style, isDark),
              style: GoogleFonts.ebGaramond(
                fontSize: 18,
                height: 1.4,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
      );
    }
  }

  List<TextSpan> _buildTextSpans(StyleOption style, bool isDark) {
    List<TextSpan> spans = [];
    String text = style.sampleText;
    int currentIndex = 0;

    // Sort highlights by start index to be safe
    style.highlights.sort((a, b) => a.start.compareTo(b.start));

    for (var highlight in style.highlights) {
      // Add non-highlighted text before the highlight
      if (highlight.start > currentIndex) {
        spans.add(TextSpan(text: text.substring(currentIndex, highlight.start)));
      }

      // Add highlighted text
      spans.add(TextSpan(
        text: text.substring(highlight.start, highlight.end),
        style: TextStyle(
          backgroundColor: isDark ? Colors.white : Colors.black,
          color: isDark ? Colors.black : Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ));

      currentIndex = highlight.end;
    }

    // Add remaining text
    if (currentIndex < text.length) {
      spans.add(TextSpan(text: text.substring(currentIndex)));
    }

    return spans;
  }
}

class StyleCategory {
  final String title;
  final String bannerText;
  final List<IconData> bannerIcons;
  final List<Color> bannerColors;
  final List<StyleOption> options;

  StyleCategory({
    required this.title,
    required this.bannerText,
    required this.bannerIcons,
    required this.bannerColors,
    required this.options,
  });
}

class StyleOption {
  final String title;
  final String description;
  final String sampleText;
  final List<TextHighlight> highlights;
  final Color avatarColor;
  final String? senderName;
  final String? time;
  final String? recipient;

  StyleOption({
    required this.title,
    required this.description,
    required this.sampleText,
    required this.highlights,
    required this.avatarColor,
    this.senderName,
    this.time,
    this.recipient,
  });
}

class TextHighlight {
  final int start;
  final int end;
  final Color color;

  TextHighlight(this.start, this.end, this.color);
}
