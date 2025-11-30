import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:llama_cpp/llama_cpp.dart';
import 'package:path_provider/path_provider.dart';

import 'dictionary_service.dart';
import '../models/snippet.dart';

class LocalLLMService {
  LlamaProcessor? _processor;
  bool _isModelLoaded = false;
  String? _loadedModelPath;

  bool get isModelLoaded => _isModelLoaded;

  Future<void> loadModel(String fileName) async {
    if (_isModelLoaded && _loadedModelPath == fileName) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelPath = '${dir.path}/$fileName';
      final file = File(modelPath);

      if (!await file.exists()) {
        throw Exception("Model file not found at $modelPath");
      }

      // Unload existing if any
      unloadModel();

      _processor = LlamaProcessor(modelPath);
      _loadedModelPath = fileName;
      _isModelLoaded = true;
      debugPrint("Local model loaded: $fileName");
    } catch (e) {
      debugPrint("Error loading local model: $e");
      _isModelLoaded = false;
      rethrow;
    }
  }

  void unloadModel() {
    if (_processor != null) {
      _processor!.unloadModel();
      _processor = null;
    }
    _isModelLoaded = false;
    _loadedModelPath = null;
    debugPrint("Local model unloaded");
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
    if (!_isModelLoaded || _processor == null) {
      throw Exception("Model not loaded");
    }
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

    // 3. Construct the final prompt with System Instruction
    // Gemma format: <start_of_turn>user\n{prompt}<end_of_turn>\n<start_of_turn>model\n
    // We embed the system instruction into the user turn for simplicity and effectiveness.
    
    const systemInstruction = 
        'You are a fast and precise text editor. Your goal is to clean up the user\'s speech-to-text input.\n'
        'Rules:\n'
        '1. Remove filler words (e.g., "um", "ah", "hmm", "like").\n'
        '2. Fix spelling and grammar errors.\n'
        '3. Do NOT rewrite sentences or change the user\'s intent. Keep it as close to verbatim as possible.\n'
        '4. Do NOT chat or explain. Return ONLY the edited text.\n'
        '5. Apply corrections and snippet expansions strictly case-insensitively.\n';

    final fullPrompt = 
        '<start_of_turn>user\n'
        '$systemInstruction\n'
        '$contextPrompt'
        'Input: "$text"<end_of_turn>\n'
        '<start_of_turn>model\n';

    debugPrint("LocalLLMService: Sending prompt (Relevant Snippets: ${relevantSnippets.length}, Relevant Terms: ${relevantTerms.length})...");

    StringBuffer buffer = StringBuffer();
    try {
      await for (final token in _processor!.stream(fullPrompt)) {
        buffer.write(token);
      }
      final response = buffer.toString().trim();
      debugPrint("LocalLLMService: Received response: $response");
      return response;
    } catch (e) {
      debugPrint("Local Inference Error: $e");
      return text; // Fallback to original text on error
    }
  }
