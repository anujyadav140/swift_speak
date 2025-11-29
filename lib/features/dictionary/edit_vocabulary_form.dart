import 'package:flutter/material.dart';
import 'package:swift_speak/services/dictionary_service.dart';

class EditVocabularyForm extends StatefulWidget {
  final String termId;
  final String initialOriginal;
  final String initialReplacement;
  final bool isCorrection;
  final VoidCallback onCancel;
  final VoidCallback onSuccess;

  const EditVocabularyForm({
    super.key,
    required this.termId,
    required this.initialOriginal,
    required this.initialReplacement,
    required this.isCorrection,
    required this.onCancel,
    required this.onSuccess,
  });

  @override
  State<EditVocabularyForm> createState() => _EditVocabularyFormState();
}

class _EditVocabularyFormState extends State<EditVocabularyForm> {
  late TextEditingController _originalController;
  late TextEditingController _replacementController;
  final DictionaryService _dictionaryService = DictionaryService();

  @override
  void initState() {
    super.initState();
    _originalController = TextEditingController(text: widget.initialOriginal);
    _replacementController = TextEditingController(text: widget.initialReplacement);
  }

  @override
  void dispose() {
    _originalController.dispose();
    _replacementController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final original = _originalController.text.trim();
    final replacement = widget.isCorrection ? _replacementController.text.trim() : original;

    if (original.isEmpty || (widget.isCorrection && replacement.isEmpty)) {
      return;
    }

    // We can't update directly with addTerm, so we delete and add (or update if we had an update method)
    // For now, let's assume we delete the old one and add a new one to keep IDs simple or just update fields.
    // Since DictionaryService doesn't have update, let's add updateTerm to it later.
    // For now, we'll use delete + add, but ideally we should update.
    // Let's assume we will add updateTerm to DictionaryService.
    
    // Actually, let's just use delete and add for now to be safe with the current service.
    await _dictionaryService.deleteTerm(widget.termId);
    await _dictionaryService.addTerm(original, replacement, isCorrection: widget.isCorrection);

    widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.isCorrection ? "Edit replacement" : "Edit word",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              IconButton(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Inputs
          if (widget.isCorrection)
            Row(
              children: [
                Expanded(
                  child: _buildTextField(_originalController, "Original"),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.0),
                  child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                ),
                Expanded(
                  child: _buildTextField(_replacementController, "Replacement"),
                ),
              ],
            )
          else
            _buildTextField(_originalController, "Word or phrase"),

          const SizedBox(height: 24),

          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: widget.onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: textColor,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text("Cancel"),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D2D2D), // Dark button
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text("Save changes"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }
}
