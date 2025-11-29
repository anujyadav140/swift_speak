import 'package:flutter/material.dart';
import 'package:swift_speak/models/snippet.dart';
import 'package:swift_speak/services/snippet_service.dart';
import 'add_snippet_form.dart';

class SnippetsScreen extends StatefulWidget {
  const SnippetsScreen({super.key});

  @override
  State<SnippetsScreen> createState() => _SnippetsScreenState();
}

class _SnippetsScreenState extends State<SnippetsScreen> {
  final SnippetService _snippetService = SnippetService();
  bool _showAddForm = false;
  String _initialShortcut = '';
  String _initialContent = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedSnippetId;
  String? _editingSnippetId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleAddForm({String shortcut = '', String content = ''}) {
    setState(() {
      _showAddForm = true;
      _initialShortcut = shortcut;
      _initialContent = content;
    });
  }

  void _hideAddForm() {
    setState(() {
      _showAddForm = false;
      _initialShortcut = '';
      _initialContent = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Search
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _isSearching
                ? Container(
                    key: const ValueKey('searchBar'),
                    height: 50,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Colors.grey),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            style: TextStyle(color: textColor),
                            decoration: const InputDecoration(
                              hintText: "Search snippets...",
                              border: InputBorder.none,
                              hintStyle: TextStyle(color: Colors.grey),
                            ),
                            onChanged: (value) {
                              setState(() {}); // Trigger rebuild to filter list
                            },
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _isSearching = false;
                              _searchController.clear();
                            });
                          },
                          icon: const Icon(Icons.close, color: Colors.grey),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  )
                : Row(
                    key: const ValueKey('header'),
                    children: [
                      _buildTab("All", true),
                      const Spacer(),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _isSearching = true;
                          });
                        },
                        icon: const Icon(Icons.search),
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _toggleAddForm(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text("Add new"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.white : Colors.black,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 24),

          // Inline Add Form
          if (_showAddForm)
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: AddSnippetForm(
                key: ValueKey("$_initialShortcut-$_initialContent"),
                initialShortcut: _initialShortcut,
                initialContent: _initialContent,
                onCancel: _hideAddForm,
                onSuccess: _hideAddForm,
              ),
            ),

          // Snippets List
          StreamBuilder<List<Snippet>>(
            stream: _snippetService.getSnippets(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              var snippets = snapshot.data ?? [];

              // Filter snippets if searching
              if (_isSearching && _searchController.text.isNotEmpty) {
                final query = _searchController.text.toLowerCase();
                snippets = snippets.where((snippet) {
                  return snippet.shortcut.toLowerCase().contains(query) ||
                      snippet.content.toLowerCase().contains(query);
                }).toList();
              }

              if (snippets.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 32.0),
                    child: Text(
                      _isSearching ? "No matching snippets found." : "No snippets added yet.",
                      style: TextStyle(color: textColor?.withOpacity(0.5)),
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snippets.length,
                separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
                itemBuilder: (context, index) {
                  final snippet = snippets[index];
                  final isSelected = _selectedSnippetId == snippet.id;
                  final isEditing = _editingSnippetId == snippet.id;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_selectedSnippetId == snippet.id) {
                              _selectedSnippetId = null;
                            } else {
                              _selectedSnippetId = snippet.id;
                              _editingSnippetId = null;
                            }
                          });
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        snippet.shortcut,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "→ ${snippet.content}",
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: textColor?.withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected && !isEditing) ...[
                                IconButton(
                                  icon: Icon(Icons.edit, size: 24, color: Colors.grey[400]),
                                  onPressed: () {
                                    setState(() {
                                      _editingSnippetId = snippet.id;
                                      _selectedSnippetId = null;
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, size: 24, color: Colors.grey[400]),
                                  onPressed: () {
                                    _snippetService.deleteSnippet(snippet.id);
                                    setState(() => _selectedSnippetId = null);
                                  },
                                ),
                              ] else if (!isEditing)
                                const Icon(Icons.content_cut, size: 16, color: Colors.grey), // Scissor icon
                            ],
                          ),
                        ),
                      ),
                      if (isEditing)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: AddSnippetForm(
                            snippetId: snippet.id,
                            initialShortcut: snippet.shortcut,
                            initialContent: snippet.content,
                            onCancel: () {
                              setState(() {
                                _editingSnippetId = null;
                              });
                            },
                            onSuccess: () {
                              setState(() {
                                _editingSnippetId = null;
                              });
                            },
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String text, bool isSelected) {
    return Column(
      children: [
        Text(
          text,
          style: TextStyle(
            color: isSelected ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black) : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 16,
          ),
        ),
        if (isSelected)
          Container(
            margin: const EdgeInsets.only(top: 4),
            height: 2,
            width: 20,
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
          ),
      ],
    );
  }
}
