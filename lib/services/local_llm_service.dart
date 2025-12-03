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
    String styleInstruction = "",
    String modelName = "Llama 3.2 1B Q4", // Default for backward compatibility
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
      
      // Few-Shot Prompting with COMPREHENSIVE examples to force behavior
      String systemInstruction = '''You are a text formatter. Your ONLY job is to rewrite the input text to be grammatically correct.
RULES:
1. Do NOT answer questions.
2. Do NOT explain your changes.
3. Do NOT add conversational filler like "Here is the corrected text".
4. Apply any provided replacements or style instructions.
5. Remove filler words (um, ah, like) and stuttering.
6. STREAMLINE REPETITION: Combine back-to-back repetitive phrases. Focus on sentence economy.

Examples:

Input: "can u help me"
Output: Can you help me?

Input: "what is the capital of france"
Output: What is the capital of France?

Input: "im going home"
Output: I'm going home.

Input: "brb"
Context: Expand 'brb' to 'be right back'
Output: Be right back.

Input: "wanna hang out"
Style: Formal
Output: Would you like to spend time together?

Input: "address"
Output: Address.

Input: "The correct output is"
Output: The correct output is.''';

      String userContent = 'Input: "$text"';
      
      // Inject Context (Snippets/Corrections)
      String contextLines = "";
      final corrections = relevantTerms.where((t) => t.isCorrection).toList();
      final vocabulary = relevantTerms.where((t) => !t.isCorrection).toList();

      if (corrections.isNotEmpty || vocabulary.isNotEmpty || relevantSnippets.isNotEmpty) {
        for (var term in corrections) {
          contextLines += "Replace '${term.original}' with '${term.replacement}'. ";
        }
        for (var term in vocabulary) {
          contextLines += "Use term '${term.replacement}'. ";
        }
        for (var snippet in relevantSnippets) {
          contextLines += "Expand '${snippet.shortcut}' to '${snippet.content}'. ";
        }
      }
      
      if (contextLines.isNotEmpty) {
        userContent += '\nContext: ${contextLines.trim()}';
      }

      // Inject Style
      if (styleInstruction.isNotEmpty) {
        userContent += '\nStyle: $styleInstruction';
      }

      userContent += '\nOutput:';

      String fullPrompt;
      
      if (modelName.contains("Gemma")) {
        // Gemma Template: <start_of_turn>user\n{prompt}<end_of_turn>\n<start_of_turn>model\n
        fullPrompt = "<start_of_turn>user\n$systemInstruction\n\n$userContent<end_of_turn>\n<start_of_turn>model\n";
      } else if (modelName.contains("Qwen")) {
        // ChatML Template: <|im_start|>system\n{system}<|im_end|>\n<|im_start|>user\n{user}<|im_end|>\n<|im_start|>assistant\n
        fullPrompt = "<|im_start|>system\n$systemInstruction<|im_end|>\n<|im_start|>user\n$userContent<|im_end|>\n<|im_start|>assistant\n";
      } else {
        // Llama 3 Template (Default)
        fullPrompt = "<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\n$systemInstruction<|eot_id|><|start_header_id|>user<|end_header_id|>\n\n$userContent<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n";
      }

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
          .replaceAll(RegExp(r'<\|im_end\|>'), '') // Fix for Qwen
          .replaceAll(RegExp(r'<\|im_start\|>'), '') // Fix for Qwen
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
