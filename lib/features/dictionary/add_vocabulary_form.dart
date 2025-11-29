import 'package:flutter/material.dart';
import 'package:swift_speak/services/dictionary_service.dart';

class AddVocabularyForm extends StatefulWidget {
  final String initialOriginal;
  final String initialReplacement;
  final VoidCallback onCancel;
  final VoidCallback onSuccess;

  const AddVocabularyForm({
    super.key,
    this.initialOriginal = '',
    this.initialReplacement = '',
    required this.onCancel,
    required this.onSuccess,
  });

  @override
  State<AddVocabularyForm> createState() => _AddVocabularyFormState();
}

class _AddVocabularyFormState extends State<AddVocabularyForm> {
  late TextEditingController _originalController;
  late TextEditingController _replacementController;
  bool _isCorrection = true;
  bool _shareWithTeam = false;
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

  Future<void> _addWord() async {
    final original = _originalController.text.trim();
    // If not a correction, use the original word as the replacement too (or handle as needed)
    final replacement = _isCorrection ? _replacementController.text.trim() : original;

    if (original.isEmpty || replacement.isEmpty) {
      return;
    }

    await _dictionaryService.addTerm(
      original,
      replacement,
      isCorrection: _isCorrection,
    );

    widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Add to vocabulary",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 24),
          
          // Toggles
          _buildToggleRow("Correct a misspelling", _isCorrection, (val) {
            setState(() => _isCorrection = val);
          }),
          // const SizedBox(height: 12),
          // _buildToggleRow("Share with team", _shareWithTeam, (val) {
          //   setState(() => _shareWithTeam = val);
          // }),
          
          const SizedBox(height: 24),

          // Input Fields
          if (_isCorrection)
            Row(
              children: [
                Expanded(
                  child: _buildTextField(_originalController, "Original"),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.0),
                  child: Icon(Icons.arrow_forward, color: Colors.grey),
                ),
                Expanded(
                  child: _buildTextField(_replacementController, "Replacement"),
                ),
              ],
            )
          else
            _buildTextField(_originalController, "Word or phrase"),

          const SizedBox(height: 32),

          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: widget.onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: textColor,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text("Cancel"),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _addWord,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D2D2D), // Dark button
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(_isCorrection ? "Add correction" : "Add word"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.info_outline, size: 18, color: Colors.grey[400]),
          ],
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.white,
          activeTrackColor: const Color(0xFF4CAF50), // Green
        ),
      ],
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
