import 'dart:async';
import 'package:flutter/material.dart';

class MapSearchWidget extends StatefulWidget {
  final ValueChanged<String> onSearch;
  final Function(Map<String, dynamic>)? onSuggestionSelected;
  final List suggestions;
  final VoidCallback onCenterUserLocation; // Add this line

  const MapSearchWidget({
    Key? key,
    required this.onSearch,
    this.onSuggestionSelected,
    required this.suggestions,
    required this.onCenterUserLocation, // Add this line
  }) : super(key: key);

  @override
  _MapSearchWidgetState createState() => _MapSearchWidgetState();
}

class _MapSearchWidgetState extends State<MapSearchWidget> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<dynamic> _suggestions = [];
  bool _showSuggestions = false;

  void _onTextChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      widget.onSearch(query.trim());
      setState(() {
        _suggestions = widget.suggestions;
        _showSuggestions = widget.suggestions.isNotEmpty;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      // Force rebuild to show/hide clear button
      setState(() {});
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 40,
      left: 20,
      right: 20,
      child: Column(
        children: [
          Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            color: Colors.black26,
            child: TextField(
              controller: _controller,
              onChanged: _onTextChanged,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search location...',
                hintStyle: TextStyle(color: Colors.white70),
                prefixIcon: Icon(Icons.search, color: Colors.white),
                suffixIcon:
                    _controller.text.isNotEmpty
                        ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.white70),
                          onPressed: () {
                            _controller.clear();
                            setState(() {
                              _showSuggestions = false;
                              _suggestions = [];
                            });
                            widget.onSearch('');
                            widget.onCenterUserLocation(); // Add this line
                          },
                        )
                        : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onTap: () {
                setState(() {
                  _showSuggestions = true;
                });
              },
            ),
          ),
          if (_showSuggestions && _suggestions.isNotEmpty)
            Container(
              margin: EdgeInsets.only(top: 4),
              constraints: BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = _suggestions[index];
                  return ListTile(
                    title: Text(
                      suggestion['name'] ?? '',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      _controller.text = suggestion['name'];
                      setState(() {
                        _showSuggestions = false;
                        _suggestions = [];
                      });
                      if (widget.onSuggestionSelected != null) {
                        widget.onSuggestionSelected!(suggestion);
                      }
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
