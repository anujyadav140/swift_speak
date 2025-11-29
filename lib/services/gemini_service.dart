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
        'You are a fast and precise text editor. Your goal is to clean up the user\'s speech-to-text input.\n'
        'Rules:\n'
        '1. Remove filler words (e.g., "um", "ah", "hmm", "like").\n'
        '2. Fix spelling and grammar errors.\n'
        '3. Do NOT rewrite sentences or change the user\'s intent. Keep it as close to verbatim as possible.\n'
        '4. Do NOT chat or explain. Return ONLY the edited text.\n'
        '5. Apply corrections and snippet expansions strictly case-insensitively.\n'
      ),
    );
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

  Future<String> formatText(String text, {List<DictionaryTerm> userTerms = const [], List<Snippet> snippets = const []}) async {
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

    // 3. Construct the final prompt
    final prompt = [
      Content.text(
        '$contextPrompt'
        'Input: "$text"',
      )
    ];

    debugPrint("GeminiService: Sending prompt (Relevant Snippets: ${relevantSnippets.length}, Relevant Terms: ${relevantTerms.length})...");

    try {
      final response = await _model.generateContent(prompt);
      debugPrint("GeminiService: Received response: ${response.text}");
      return response.text?.trim() ?? text;
    } catch (e) {
      debugPrint("Gemini Error: $e");
      return text;
    }
  }
}
