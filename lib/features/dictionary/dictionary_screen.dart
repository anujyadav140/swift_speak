import 'package:flutter/material.dart';
import 'package:swift_speak/services/dictionary_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_vocabulary_form.dart';
import 'edit_vocabulary_form.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final DictionaryService _dictionaryService = DictionaryService();
  bool _showAddForm = false;
  String _initialOriginal = '';
  String _initialReplacement = '';
  bool _showBanner = false;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedTermId;
  String? _editingTermId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadBannerPreference();
  }

  Future<void> _loadBannerPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final isClosed = prefs.getBool('dictionary_banner_closed') ?? false;
    if (!isClosed) {
      setState(() {
        _showBanner = true;
      });
    }
  }

  void _toggleAddForm({String original = '', String replacement = ''}) {
    setState(() {
      _showAddForm = true;
      _initialOriginal = original;
      _initialReplacement = replacement;
    });
  }

  void _hideAddForm() {
    setState(() {
      _showAddForm = false;
      _initialOriginal = '';
      _initialReplacement = '';
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
                              hintText: "Search vocabulary...",
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

            // Banner
            if (_showBanner && !_isSearching) // Hide banner when searching to focus on results
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9C4), // Light Yellow (like reference)
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: Text(
                            "Add your own words and correct misspellings",
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 20,
                              fontFamily: 'Serif', // Try to match the serif font
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            setState(() {
                              _showBanner = false;
                            });
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('dictionary_banner_closed', true);
                          },
                          icon: const Icon(Icons.close, color: Colors.black54),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Swift Speak learns your unique words and names — automatically or manually. Add personal terms, company jargon, or industry-specific lingo.",
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildChip("Q3 Roadmap"),
                        _buildChip("Arianna → Aryana", original: "Arianna", replacement: "Aryana"),
                        _buildChip("SF MOMA"),
                        _buildChip("Figma Jam"),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => _toggleAddForm(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D2D2D), // Dark button
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: const Text("Add new word"),
                    ),
                  ],
                ),
              ),
            if (_showBanner && !_isSearching) const SizedBox(height: 32),

            // Inline Add Form
            if (_showAddForm)
              AddVocabularyForm(
                key: ValueKey("$_initialOriginal-$_initialReplacement"), // Force rebuild on change
                initialOriginal: _initialOriginal,
                initialReplacement: _initialReplacement,
                onCancel: _hideAddForm,
                onSuccess: _hideAddForm,
              ),

            // Word List
            StreamBuilder<List<DictionaryTerm>>(
              stream: _dictionaryService.getTerms(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                var terms = snapshot.data ?? [];
                
                // Filter terms if searching
                if (_isSearching && _searchController.text.isNotEmpty) {
                  final query = _searchController.text.toLowerCase();
                  terms = terms.where((term) {
                    return term.original.toLowerCase().contains(query) || 
                           term.replacement.toLowerCase().contains(query);
                  }).toList();
                }
                
                if (terms.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 32.0),
                      child: Text(
                        _isSearching ? "No matching words found." : "No words added yet.",
                        style: TextStyle(color: textColor?.withOpacity(0.5)),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: terms.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
                  itemBuilder: (context, index) {
                    final term = terms[index];
                    final isSelected = _selectedTermId == term.id;
                    final isEditing = _editingTermId == term.id;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              // Toggle selection
                              if (_selectedTermId == term.id) {
                                _selectedTermId = null;
                              } else {
                                _selectedTermId = term.id;
                                _editingTermId = null; // Close edit form if selecting another
                              }
                            });
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    term.isCorrection 
                                        ? "${term.original} → ${term.replacement}" 
                                        : term.original,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                                if (isSelected && !isEditing) ...[
                                  IconButton(
                                    icon: Icon(Icons.edit, size: 26, color: Colors.grey[400]),
                                    onPressed: () {
                                      setState(() {
                                        _editingTermId = term.id;
                                        _selectedTermId = null; // Hide icons while editing
                                      });
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, size: 26, color: Colors.grey[400]),
                                    onPressed: () {
                                      _dictionaryService.deleteTerm(term.id);
                                      setState(() => _selectedTermId = null);
                                    },
                                  ),
                                ] else if (!isEditing)
                                  const Icon(Icons.auto_awesome, size: 16, color: Colors.amber), // Sparkle icon
                              ],
                            ),
                          ),
                        ),
                        if (isEditing)
                          EditVocabularyForm(
                            termId: term.id,
                            initialOriginal: term.original,
                            initialReplacement: term.replacement,
                            isCorrection: term.isCorrection,
                            onCancel: () {
                              setState(() {
                                _editingTermId = null;
                              });
                            },
                            onSuccess: () {
                              setState(() {
                                _editingTermId = null;
                              });
                            },
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

  Widget _buildChip(String label, {String? original, String? replacement}) {
    return GestureDetector(
      onTap: () {
        if (original != null && replacement != null) {
          _toggleAddForm(original: original, replacement: replacement);
        } else {
          _toggleAddForm(original: label);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black12),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
