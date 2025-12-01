import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:fllama/fllama.dart';
import 'package:fllama/fllama_type.dart';
import 'package:path_provider/path_provider.dart';

import 'dictionary_service.dart';
import '../models/snippet.dart';

class LocalLLMService {
  bool _isModelLoaded = false;
  String? _loadedModelPath;
  double? _contextId;

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

      // Initialize fllama with the model path directly
      // initContext returns a Map with contextId
      final result = await Fllama.instance()!.initContext(modelPath);
      debugPrint("Fllama init result: $result");
      
      if (result != null && result is Map && result.containsKey('contextId')) {
        // API expects double, but native might return int/num. Safely convert.
        _contextId = (result['contextId'] as num?)?.toDouble();
      }

      _loadedModelPath = fileName;
      _isModelLoaded = true;
      debugPrint("Local model loaded: $fileName, Context ID: $_contextId");
    } catch (e) {
      debugPrint("Error loading local model: $e");
      _isModelLoaded = false;
      rethrow;
    }
  }

  void unloadModel() {
    if (_contextId != null) {
        Fllama.instance()!.releaseContext(_contextId!);
    } else {
        Fllama.instance()!.releaseAllContexts();
    }
    _isModelLoaded = false;
    _loadedModelPath = null;
    _contextId = null;
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

  Future<String> formatText(String text, {
    List<DictionaryTerm> userTerms = const [], 
    List<Snippet> snippets = const [],
    String styleInstruction = ""
  }) async {
    if (!_isModelLoaded || _contextId == null) {
      debugPrint("Model not loaded or context ID missing. Loaded: $_isModelLoaded, ContextId: $_contextId");
      if (_isModelLoaded && _contextId == null) {
         // Try to recover context if model is supposedly loaded but ID is missing
         // This is a safe fallback, not a full re-init
         await loadModel(_loadedModelPath ?? 'llama-3.2-1b-q4.gguf');
         if (_contextId == null) throw Exception("Context ID missing despite model being loaded");
      } else {
         throw Exception("Model not loaded");
      }
    }

    if (text.trim().isEmpty) return text;

    // 2. Dynamic Context Injection
    final relevantSnippets = _getRelevantSnippets(text, snippets);
    final relevantTerms = _getRelevantTerms(text, userTerms);



    try {
      // 3. Construct Prompt - Llama 3.2 Chat Template
      // <|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\n{system_prompt}<|eot_id|><|start_header_id|>user<|end_header_id|>\n\n{user_prompt}<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n
      
      // Explicitly mention snippets and corrections to avoid "Do NOT add words" conflict
      String systemInstruction = 'You are a grammar correction engine. Fix the input text to be grammatically correct and coherent. Repair sentence structure and fix spelling errors. Keep the user\'s original vocabulary and meaning. Do NOT converse. Do NOT add commentary. Do NOT repeat phrases. Output ONLY the corrected text.';
      
      if (styleInstruction.isNotEmpty) {
         systemInstruction += " Style: $styleInstruction.";
      } else {
         systemInstruction += " Keep tone verbatim.";
      }

      String userContent = "Text to format:\n$text";
      
      // Add specific context instructions (Snippets/Corrections/Vocabulary) to the user block
      String contextInstructions = "";
      
      final corrections = relevantTerms.where((t) => t.isCorrection).toList();
      final vocabulary = relevantTerms.where((t) => !t.isCorrection).toList();

      if (corrections.isNotEmpty) {
        contextInstructions += "Corrections:\n";
        for (var term in corrections) {
          contextInstructions += "- Replace '${term.original}' with '${term.replacement}'\n";
        }
      }
      
      if (vocabulary.isNotEmpty) {
        contextInstructions += "Vocabulary (Jargon):\n";
        for (var term in vocabulary) {
          contextInstructions += "- Use term: '${term.replacement}'\n";
        }
      }
      if (relevantSnippets.isNotEmpty) {
        contextInstructions += "Snippets:\n";
        for (var snippet in relevantSnippets) {
          contextInstructions += "- ${snippet.shortcut} -> ${snippet.content}\n";
        }
      }

      if (contextInstructions.isNotEmpty) {
        userContent = "Instructions:\n$contextInstructions\n$userContent";
      }

      final fullPrompt = "<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\n$systemInstruction<|eot_id|><|start_header_id|>user<|end_header_id|>\n\n$userContent<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n";

      debugPrint("LocalLLMService: Sending prompt to FRESH Context $_contextId...");
      final response = await Fllama.instance()!.completion(
        _contextId!, 
        prompt: fullPrompt,
      );
      
      debugPrint("LocalLLMService: Raw response: $response");

      String rawText = "";
      if (response != null && response is Map) {
         if (response.containsKey('content')) {
           rawText = response['content'].toString();
         } else if (response.containsKey('text')) {
           rawText = response['text'].toString();
         } else if (response.containsKey('choices')) {
           final choices = response['choices'];
           if (choices is List && choices.isNotEmpty) {
             final first = choices.first;
             if (first is Map && first.containsKey('message')) {
                rawText = first['message']['content'].toString();
             } else if (first is Map && first.containsKey('text')) {
                rawText = first['text'].toString();
             }
           }
         }
      } else {
        rawText = response?.toString() ?? text;
      }

      // 4. Robust Parsing
      String cleanedText = rawText
          .replaceAll(RegExp(r'<\|begin_of_text\|>'), '')
          .replaceAll(RegExp(r'<\|eot_id\|>'), '')
          .replaceAll(RegExp(r'<\|start_header_id\|>.*?<\|end_header_id\|>'), '')
          .replaceAll(RegExp(r'<end_of_turn>'), '') // Legacy cleanup
          .replaceAll(RegExp(r'<eos>'), '') // Legacy cleanup
          .replaceAll(RegExp(r'</s>'), '') // Legacy cleanup
          .trim();

      // Remove "Output:" label if present (and everything before it)
      if (cleanedText.contains("Output:")) {
        cleanedText = cleanedText.split("Output:").last.trim();
      } else if (cleanedText.contains("output:")) {
        cleanedText = cleanedText.split("output:").last.trim();
      }

      // Remove "Input:" label if present (and everything after it, assuming it's hallucinating the next turn)
      if (cleanedText.contains("Input:")) {
        cleanedText = cleanedText.split("Input:").first.trim();
      } else if (cleanedText.contains("input:")) {
        cleanedText = cleanedText.split("input:").first.trim();
      }
      
      // Remove "Style:" label if present
      if (cleanedText.contains("Style:")) {
        cleanedText = cleanedText.split("Style:").first.trim();
      }

      // Aggressively strip the style instruction itself if it leaks into the output
      if (styleInstruction.isNotEmpty) {
        final styleName = styleInstruction.split('(').first.trim();
        if (cleanedText.toLowerCase().startsWith(styleName.toLowerCase())) {
           cleanedText = cleanedText.substring(styleName.length).trim();
           if (cleanedText.startsWith(',') || cleanedText.startsWith(':') || cleanedText.startsWith('-')) {
             cleanedText = cleanedText.substring(1).trim();
           }
        }
      }

      // Remove leading/trailing quotes
      if (cleanedText.startsWith('"') && cleanedText.endsWith('"')) {
        cleanedText = cleanedText.substring(1, cleanedText.length - 1);
      } else if (cleanedText.startsWith("'") && cleanedText.endsWith("'")) {
        cleanedText = cleanedText.substring(1, cleanedText.length - 1);
      }

      // Repetition Removal Logic
      // Detects phrases of 3+ words that repeat consecutively
      // e.g. "and i'm getting so and i'm getting so" -> "and i'm getting so"
      final words = cleanedText.split(' ');
      if (words.length > 6) {
        for (int i = 0; i < words.length; i++) {
          // Check for phrase repetition (length 3 to 10 words)
          for (int len = 3; len <= 10 && i + 2 * len <= words.length; len++) {
             String phrase1 = words.sublist(i, i + len).join(' ');
             String phrase2 = words.sublist(i + len, i + 2 * len).join(' ');
             
             if (phrase1.toLowerCase() == phrase2.toLowerCase()) {
               // Found repetition! Remove the second occurrence.
               // Reconstruct the text without the repeated part
               cleanedText = words.sublist(0, i + len).join(' ') + " " + words.sublist(i + 2 * len).join(' ');
               break; // Only fix the first major repetition to be safe
             }
          }
        }
      }

      return cleanedText.trim();

    } catch (e) {
      debugPrint("Local Inference Error: $e");
      return text; // Fallback
    }
  }
}
