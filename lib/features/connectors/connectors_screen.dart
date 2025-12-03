import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swift_speak/features/connectors/google_calendar_connector_screen.dart';

class ConnectorsScreen extends StatelessWidget {
  const ConnectorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          "Connectors",
          style: GoogleFonts.ebGaramond(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            "Integrate with your favorite apps",
            style: TextStyle(
              color: isDark ? Colors.grey : Colors.black54,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          _buildConnectorTile(
            context,
            title: "Google Calendar",
            description: "Sync events and schedule meetings directly from your keyboard.",
            imagePath: "assets/images/google_calendar_icon.png", // Use new icon
            color: Colors.blue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GoogleCalendarConnectorScreen()),
              );
            },
          ),
          // Add more connectors here in the future
        ],
      ),
    );
  }

  Widget _buildConnectorTile(
    BuildContext context, {
    required String title,
    required String description,
    String? imagePath, // Optional image path
    IconData? icon,    // Optional icon
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      color: isDark ? Colors.grey[900] : Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: imagePath != null 
                    ? Image.asset(imagePath, width: 32, height: 32)
                    : Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: isDark ? Colors.grey : Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: isDark ? Colors.grey : Colors.grey[400], size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
