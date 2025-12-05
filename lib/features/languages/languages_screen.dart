import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swift_speak/services/language_service.dart';
import 'package:country_flags/country_flags.dart';

class LanguagesScreen extends StatefulWidget {
  const LanguagesScreen({super.key});

  @override
  State<LanguagesScreen> createState() => _LanguagesScreenState();
}

class _LanguagesScreenState extends State<LanguagesScreen> {
  final LanguageService _languageService = LanguageService();
  String _currentLanguageCode = 'en_US';

  @override
  void initState() {
    super.initState();
    _loadCurrentLanguage();
  }

  Future<void> _loadCurrentLanguage() async {
    final code = await _languageService.getSelectedLanguageCode();
    if (mounted) {
      setState(() {
        _currentLanguageCode = code;
      });
    }
  }

  Future<void> _selectLanguage(String code) async {
    await _languageService.setLanguage(code);
    if (mounted) {
      setState(() {
        _currentLanguageCode = code;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Languages",
          style: GoogleFonts.ebGaramond(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: Theme.of(context).iconTheme.color,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _languageService.supportedLanguages.length,
        itemBuilder: (context, index) {
          final language = _languageService.supportedLanguages[index];
          final name = language['name']!;
          final code = language['code']!;
          final countryCode = language['countryCode']!;
          final isSelected = code == _currentLanguageCode;
          final isDark = Theme.of(context).brightness == Brightness.dark;

          // Selection Colors
          final Color borderColor = isSelected 
              ? (isDark ? Colors.white : Theme.of(context).primaryColor)
              : Colors.transparent;
          
          final Color checkColor = isDark ? Colors.white : Theme.of(context).primaryColor;

          return Card(
            elevation: isSelected ? 4 : 1,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: borderColor, 
                width: 2
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: Container(
                width: 32,
                height: 24, // Standard flag aspect ratio
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4), // Subtle rounded corners for flag
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 2,
                      spreadRadius: 0,
                    )
                  ]
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CountryFlag.fromCountryCode(
                    countryCode,
                  ),
                ),
              ),
              title: Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(code),
              trailing: isSelected
                  ? Icon(Icons.check_circle, color: checkColor)
                  : null,
              onTap: () => _selectLanguage(code),
            ),
          );
        },
      ),
    );
  }
}
