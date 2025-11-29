import 'package:flutter/material.dart';
import 'package:swift_speak/services/snippet_service.dart';

class AddSnippetForm extends StatefulWidget {
  final String? snippetId;
  final String initialShortcut;
  final String initialContent;
  final VoidCallback onCancel;
  final VoidCallback onSuccess;

  const AddSnippetForm({
    super.key,
    this.snippetId,
    this.initialShortcut = '',
    this.initialContent = '',
    required this.onCancel,
    required this.onSuccess,
  });

  @override
  State<AddSnippetForm> createState() => _AddSnippetFormState();
}

class _AddSnippetFormState extends State<AddSnippetForm> {
  late TextEditingController _shortcutController;
  late TextEditingController _contentController;
  final SnippetService _snippetService = SnippetService();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _shortcutController = TextEditingController(text: widget.initialShortcut);
    _contentController = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _shortcutController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveSnippet() async {
    final shortcut = _shortcutController.text.trim();
    final content = _contentController.text.trim();

    if (shortcut.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in both fields")),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (widget.snippetId != null) {
        await _snippetService.updateSnippet(widget.snippetId!, shortcut, content);
      } else {
        await _snippetService.addSnippet(shortcut, content);
      }
      widget.onSuccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving snippet: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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
            widget.snippetId != null ? "Edit snippet" : "Add snippet",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 24),

          const SizedBox(height: 24),

          // Shortcut Field
          _buildTextField(_shortcutController, "Shortcut (e.g., 'addr')"),
          const SizedBox(height: 12),

          // Content Field
          _buildTextField(_contentController, "Content to expand to...", maxLines: 4),
          
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
                onPressed: _isSaving ? null : _saveSnippet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D2D2D), // Dark button
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(widget.snippetId != null ? "Save" : "Add snippet"),
              ),
            ],
          ),
        ],
      ),
    );
  }



  Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
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
