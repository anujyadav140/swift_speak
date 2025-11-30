import 'package:shared_preferences/shared_preferences.dart';

class StyleService {
  static final StyleService _instance = StyleService._internal();
  factory StyleService() => _instance;
  StyleService._internal();

  // Mapping of App Context (Category) to Style Key
  // Categories: MESSENGER, WORK, EMAIL, SOCIAL, OTHER
  // Note: SOCIAL maps to OTHER or MESSENGER depending on preference, defaulting to OTHER for now.
  
  Future<void> saveStyle(String category, String styleName, String styleDescription) async {
    final prefs = await SharedPreferences.getInstance();
    // Save both name and description to reconstruct the instruction
    await prefs.setString('style_name_$category', styleName);
    await prefs.setString('style_desc_$category', styleDescription);
  }

  Future<Map<String, String>?> getStyle(String category) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Map SOCIAL to OTHER for simplicity unless we add a specific Social category later
    final lookupCategory = category == 'SOCIAL' ? 'OTHER' : category;

    final name = prefs.getString('style_name_$lookupCategory');
    final desc = prefs.getString('style_desc_$lookupCategory');

    if (name != null && desc != null) {
      return {'name': name, 'description': desc};
    }
    return null; // Return null to use default (Formal/Standard)
  }
  
  // Helper to get the instruction string directly
  Future<String> getStyleInstruction(String category) async {
    final style = await getStyle(category);
    if (style != null) {
      return "STYLE: ${style['name']} (${style['description']})";
    }
    return ""; // No specific style instruction
  }
}
