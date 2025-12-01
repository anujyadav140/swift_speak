import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:flutter/foundation.dart';
import 'dictionary_service.dart';
import '../models/snippet.dart';

class GeminiService {
  late final GenerativeModel _model;

  GeminiService() {
    // Initialize Gemini 1.5 Flash for speed and cost efficiency
    _model = FirebaseVertexAI.instance.generativeModel(
      model: 'gemini-2.0-flash',
      generationConfig: GenerationConfig(
        temperature: 0.0, // Maximize determinism and speed
        maxOutputTokens: 1000,
      ),
      systemInstruction: Content.system(
        'You are a text formatting engine, NOT a creative writer. Your goal is to fix mechanics while preserving the user\'s exact choice of words.\n'
        'Rules:\n'
        '1. Fix grammar, spelling, and punctuation errors ONLY.\n'
        '2. Do NOT change the user\'s vocabulary. Do NOT rewrite sentences to be more "polite" or "formal".\n'
        '3. If the style is "Formal", it refers ONLY to standard capitalization and punctuation. Do NOT change "Bro" to "Sir" or "Thanks" to "Thank you".\n'
        '4. Remove filler words (um, ah) unless the style is "Verbatim".\n'
        '5. Return ONLY the edited text. Do NOT add quotes or explanations.\n'
        '6. Do NOT convert text to ALL CAPS unless explicitly asked.\n'
        '7. Do NOT wrap the entire output in quotation marks unless the input itself is a quote.\n'
      ),
    );

    // Initialize separate model for classification (no system prompt interference)
    _classifierModel = FirebaseVertexAI.instance.generativeModel(
      model: 'gemini-2.0-flash',
      generationConfig: GenerationConfig(
        temperature: 0.0,
        maxOutputTokens: 20,
      ),
    );
  }

  late final GenerativeModel _classifierModel;
  final Map<String, String> _appCache = {};

  Future<String> classifyApp(String packageName) async {
    if (_appCache.containsKey(packageName)) return _appCache[packageName]!;

    final prompt = [
      Content.text(
        'Classify this Android package name into one of these categories: MESSENGER, WORK, EMAIL, SOCIAL, OTHER.\n'
        'Return ONLY the category name.\n'
        'Package: "$packageName"'
      )
    ];

    try {
      final response = await _classifierModel.generateContent(prompt);
      final category = response.text?.trim().toUpperCase() ?? "OTHER";
      
      // Basic validation to ensure it returned a valid category
      final validCategories = ["MESSENGER", "WORK", "EMAIL", "SOCIAL", "OTHER"];
      final finalCategory = validCategories.contains(category) ? category : "OTHER";
      
      _appCache[packageName] = finalCategory;
      debugPrint("App Classified: $packageName -> $finalCategory");
      return finalCategory;
    } catch (e) {
      debugPrint("Gemini Classify Error: $e");
      return "OTHER";
    }
  }

  /// Filters snippets to include only those whose shortcuts appear in the text.
  List<Snippet> _getRelevantSnippets(String text, List<Snippet> allSnippets) {
    if (allSnippets.isEmpty) return [];
    
    final lowerText = text.toLowerCase();
    return allSnippets.where((snippet) {
      final shortcut = snippet.shortcut.toLowerCase();
      // Regex for whole word match: \bshortcut\b
      final RegExp regex = RegExp(r'\b' + RegExp.escape(shortcut) + r'\b', caseSensitive: false);
      return regex.hasMatch(text);
    }).toList();
  }

  /// Filters dictionary terms to include only those whose original words appear in the text.
  List<DictionaryTerm> _getRelevantTerms(String text, List<DictionaryTerm> allTerms) {
    if (allTerms.isEmpty) return [];

    return allTerms.where((term) {
      final original = term.original.toLowerCase();
      final RegExp regex = RegExp(r'\b' + RegExp.escape(original) + r'\b', caseSensitive: false);
      return regex.hasMatch(text);
    }).toList();
  }

  Future<String> formatText(String text, {
    List<DictionaryTerm> userTerms = const [], 
    List<Snippet> snippets = const [],
    String styleInstruction = ""
  }) async {
    if (text.trim().isEmpty) return text;

    // 1. Dynamic Context Injection: Filter locally first
    final relevantSnippets = _getRelevantSnippets(text, snippets);
    final relevantTerms = _getRelevantTerms(text, userTerms);

    String contextPrompt = "";
    
    // 2. Build Prompt with ONLY relevant data
    if (relevantTerms.isNotEmpty) {
      contextPrompt += "CORRECTIONS:\n";
      for (var term in relevantTerms) {
        contextPrompt += "- Replace '${term.original}' with '${term.replacement}'\n";
      }
      contextPrompt += "\n";
    }

    if (relevantSnippets.isNotEmpty) {
      contextPrompt += "SNIPPETS (Expand these shortcuts):\n";
      for (var snippet in relevantSnippets) {
        contextPrompt += "- '${snippet.shortcut}' -> '${snippet.content}'\n";
      }
      contextPrompt += "\n";
    }

    if (styleInstruction.isNotEmpty) {
      contextPrompt += "$styleInstruction\n\n";
    }

    // 3. Construct the final prompt
    final prompt = [
      Content.text(
        '$contextPrompt'
        'Input: "$text"',
      )
    ];

    debugPrint("GeminiService: Sending prompt (Relevant Snippets: ${relevantSnippets.length}, Relevant Terms: ${relevantTerms.length}, Style: ${styleInstruction.isNotEmpty})...");

    try {
      final response = await _model.generateContent(prompt);
      debugPrint("GeminiService: Received response: ${response.text}");
      
      String cleanedText = response.text?.trim() ?? text;

      // Robust cleanup for unnecessary quotes
      // Only remove if BOTH start and end with quotes, AND the original input didn't start with quotes
      // This preserves intentional quotes but removes "wrapper" quotes from the LLM
      if (cleanedText.length > 1) {
         bool startsWithQuote = cleanedText.startsWith('"') || cleanedText.startsWith("'");
         bool endsWithQuote = cleanedText.endsWith('"') || cleanedText.endsWith("'");
         
         if (startsWithQuote && endsWithQuote) {
             // Check if original input was quoted. If not, this is likely an LLM artifact.
             bool originalStartedWithQuote = text.trim().startsWith('"') || text.trim().startsWith("'");
             
             if (!originalStartedWithQuote) {
                cleanedText = cleanedText.substring(1, cleanedText.length - 1);
             }
         }
      }

      return cleanedText;
    } catch (e) {
      debugPrint("Gemini Error: $e");
      return text;
    }
  }
}
