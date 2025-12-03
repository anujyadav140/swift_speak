import 'dart:io';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:flutter/foundation.dart';
import 'calendar_service.dart';
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
        '4. Remove filler words (um, ah, like, you know) and stuttering (e.g., "I I went").\n'
        '5. Return ONLY the edited text. Do NOT add quotes or explanations.\n'
        '6. Do NOT convert text to ALL CAPS unless explicitly asked.\n'
        '7. Do NOT wrap the entire output in quotation marks unless the input itself is a quote.\n'
        '8. STREAMLINE REPETITION: If the input contains repetitive phrases back-to-back (e.g., "to get what you want to get what you want"), COMBINE them into a single, concise phrase. Focus on economy of sentences.\n'
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

  final CalendarService _calendarService = CalendarService();

  Future<AnalysisResult> analyzeScreenshot(String path, {Function(String)? onStatusUpdate}) async {
    final file = File(path);
    if (!await file.exists()) return AnalysisResult(text: "Error: Screenshot not found.");
    
    final imageBytes = await file.readAsBytes();
    final now = DateTime.now();

    // Tool definition
    final checkAvailabilityTool = FunctionDeclaration(
      'checkAvailability',
      'Checks the user\'s calendar availability for a specific time range.',
      parameters: {
        'start': Schema.string(description: 'Start time in ISO 8601 format (e.g., 2023-10-27T14:00:00)'),
        'end': Schema.string(description: 'End time in ISO 8601 format'),
      },
    );

    final proposeEventTool = FunctionDeclaration(
      'proposeEvent',
      'Proposes a new calendar event to be added.',
      parameters: {
        'title': Schema.string(description: 'Title of the event'),
        'start': Schema.string(description: 'Start time in ISO 8601 format'),
        'end': Schema.string(description: 'End time in ISO 8601 format'),
      },
    );

    final model = FirebaseVertexAI.instance.generativeModel(
      model: 'gemini-2.0-flash',
      tools: [Tool.functionDeclarations([checkAvailabilityTool, proposeEventTool])],
    );

    final chat = model.startChat();
    
    onStatusUpdate?.call("Reading message...");

    final prompt = Content.multi([
      TextPart("You are a smart scheduling assistant. The user received a message shown in this screenshot. "
               "CRITICAL RULES:\n"
               "1. Identify if there is a scheduling request (e.g., 'Are you free Friday?').\n"
               "2. If a time is mentioned or implied, you MUST use the `checkAvailability` tool. Do NOT guess availability. WAIT for the tool result.\n"
               "3. Infer the date/time from the context (assume current year if not specified). Today is $now.\n"
               "4. If `checkAvailability` shows the user is free, you MUST use `proposeEvent` to suggest adding it. This is MANDATORY for positive replies.\n"
               "5. Return a JSON object with the following fields:\n"
               "   - 'explanation': A brief status (e.g., 'You are free.'). MUST match the `checkAvailability` result. If busy, say 'Busy'.\n"
               "   - 'replyMessage': A definitive, polite reply to send (e.g., 'Yes, I'm free then.'). MUST be consistent with availability.\n"
               "   - 'conflictingEvent': If busy, the title of the conflicting event from the tool result. Otherwise null.\n"
               "6. Do NOT use conversational filler like 'Let me check my availability'. State the answer directly (e.g., 'You are free at 3pm').\n"
               "7. CRITICAL: Do NOT generate the JSON until you have received the `checkAvailability` result. Do NOT contradict the tool result.\n"
               "Do NOT use markdown formatting for the JSON."),
      InlineDataPart('image/png', imageBytes),
    ]);

    var response = await chat.sendMessage(prompt);
    EventProposal? proposedEvent;

    // Handle tool calls loop
    while (response.functionCalls.isNotEmpty) {
      final functionCalls = response.functionCalls;
      debugPrint("GeminiService: Received function calls: ${functionCalls.map((c) => c.name).toList()}");
      final functionResponses = <FunctionResponse>[];

      for (var call in functionCalls) {
        if (call.name == 'checkAvailability') {
          onStatusUpdate?.call("Checking calendar...");
          final startStr = call.args['start'] as String?;
          final endStr = call.args['end'] as String?;
          
          if (startStr != null && endStr != null) {
            final start = DateTime.tryParse(startStr);
            final end = DateTime.tryParse(endStr);
            
            if (start != null && end != null) {
              debugPrint("Checking availability: $start to $end");
              final result = await _calendarService.checkAvailability(start, end);
              debugPrint("Availability result: $result");
              functionResponses.add(FunctionResponse(call.name, {'result': result}));
            } else {
              functionResponses.add(FunctionResponse(call.name, {'error': 'Invalid date format'}));
            }
          } else {
            functionResponses.add(FunctionResponse(call.name, {'error': 'Missing arguments'}));
          }
        } else if (call.name == 'proposeEvent') {
          onStatusUpdate?.call("Drafting event...");
          final title = call.args['title'] as String?;
          final startStr = call.args['start'] as String?;
          final endStr = call.args['end'] as String?;
          
          debugPrint("Proposing event: $title, $startStr, $endStr");
          
          if (title != null && startStr != null && endStr != null) {
            proposedEvent = EventProposal(
              title: title,
              start: DateTime.parse(startStr),
              end: DateTime.parse(endStr),
            );
            functionResponses.add(FunctionResponse(call.name, {'status': 'proposal_captured'}));
          }
        }
      }
      
      onStatusUpdate?.call("Finalizing...");
      response = await chat.sendMessage(Content.functionResponses(functionResponses));
    }

    String explanation = "Could not analyze.";
    String replyMessage = "";
    String? conflictingEvent;

    try {
      final text = response.text?.replaceAll('```json', '').replaceAll('```', '').trim() ?? "{}";
      
      final expMatch = RegExp(r'"explanation":\s*"(.*?)"').firstMatch(text);
      if (expMatch != null) explanation = expMatch.group(1) ?? "";
      
      final replyMatch = RegExp(r'"replyMessage":\s*"(.*?)"').firstMatch(text);
      if (replyMatch != null) replyMessage = replyMatch.group(1) ?? "";
      
      final conflictMatch = RegExp(r'"conflictingEvent":\s*"(.*?)"').firstMatch(text);
      if (conflictMatch != null) conflictingEvent = conflictMatch.group(1);
      
      if (explanation.isEmpty && text.isNotEmpty && !text.startsWith("{")) {
         explanation = text;
      }
      
    } catch (e) {
      debugPrint("Error parsing JSON response: $e");
      explanation = response.text ?? "Error";
    }

    return AnalysisResult(
      text: explanation,
      replyMessage: replyMessage,
      conflictingEvent: conflictingEvent,
      proposedEvent: proposedEvent,
    );
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
    debugPrint("GeminiService: Input Text: $text");

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

      // Repetition Removal Logic (Phrase-level)
      // Detects phrases of 3+ words that repeat consecutively
      // Increased max length to 30 to catch longer sentence repetitions
      final words = cleanedText.split(' ');
      if (words.length > 6) {
        for (int i = 0; i < words.length; i++) {
          for (int len = 3; len <= 30 && i + 2 * len <= words.length; len++) {
             String phrase1 = words.sublist(i, i + len).join(' ');
             String phrase2 = words.sublist(i + len, i + 2 * len).join(' ');
             
             if (phrase1.toLowerCase() == phrase2.toLowerCase()) {
               // Found repetition! Remove the second occurrence.
               cleanedText = words.sublist(0, i + len).join(' ') + " " + words.sublist(i + 2 * len).join(' ');
               break; 
             }
          }
        }
      }
      
      // Sentence-level Deduplication
      cleanedText = _deduplicateSentences(cleanedText);

      return cleanedText;
    } catch (e) {
      debugPrint("Gemini Error: $e");
      return text;
    }
  }

  String _deduplicateSentences(String text) {
    // Split by common sentence terminators
    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
    if (sentences.length < 2) return text;

    final List<String> uniqueSentences = [];
    String? lastSentence;

    for (final sentence in sentences) {
      if (lastSentence == null) {
        uniqueSentences.add(sentence);
        lastSentence = sentence;
        continue;
      }

      // Check similarity
      if (_areSentencesSimilar(lastSentence, sentence)) {
        // Keep the longer one (usually contains more detail)
        if (sentence.length > lastSentence.length) {
          uniqueSentences.removeLast();
          uniqueSentences.add(sentence);
          lastSentence = sentence;
        }
        // Else ignore the new one (it's a subset/duplicate)
      } else {
        uniqueSentences.add(sentence);
        lastSentence = sentence;
      }
    }

    return uniqueSentences.join(' ');
  }

  bool _areSentencesSimilar(String s1, String s2) {
    final w1 = s1.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();
    final w2 = s2.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();

    if (w1.isEmpty || w2.isEmpty) return false;

    final intersection = w1.intersection(w2).length;
    final union = w1.union(w2).length;
    
    // Jaccard Similarity > 0.7 means they are very similar
    // Also check if one is a subset of the other (intersection == smaller set size)
    final smallerSize = w1.length < w2.length ? w1.length : w2.length;
    
    if (union == 0) return false;
    
    double jaccard = intersection / union;
    
    // If one is almost entirely contained in the other
    bool isSubset = intersection >= (smallerSize * 0.9); 

    return jaccard > 0.7 || isSubset;
  }
}

class AnalysisResult {
  final String text;
  final String replyMessage;
  final String? conflictingEvent;
  final EventProposal? proposedEvent;

  AnalysisResult({
    required this.text, 
    this.replyMessage = "",
    this.conflictingEvent,
    this.proposedEvent
  });
}

class EventProposal {
  final String title;
  final DateTime start;
  final DateTime end;

  EventProposal({required this.title, required this.start, required this.end});
}
