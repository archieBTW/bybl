import 'dart:async';
import 'package:TheWord/providers/bible_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum SearchType { BibleBooks, Settings }

class DynamicSearchBar extends StatefulWidget {
  final SearchType searchType;
  final Color? fontColor;

  DynamicSearchBar({
    required this.searchType,
    this.fontColor,
  });

  @override
  _DynamicSearchBarState createState() => _DynamicSearchBarState();
}

class _DynamicSearchBarState extends State<DynamicSearchBar> {
  Timer? _debounce;

  void _filterMethod(context, filterString) async {
    if (widget.searchType == SearchType.BibleBooks) {
      Provider.of<BibleProvider>(context, listen: false)
          .filterBooks(filterString);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _filterMethod(context, query);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  String _getPlaceholderText() {
    switch (widget.searchType) {
      case SearchType.BibleBooks:
        return 'Search Bible books...';
      case SearchType.Settings:
        return 'Search Settings...';
      default:
        return 'Search...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        margin: const EdgeInsets.symmetric(horizontal: 0),
        child: TextField(
          onTapOutside: (e) {
            FocusManager.instance.primaryFocus?.unfocus();
          },
          decoration: InputDecoration(
              hintText: _getPlaceholderText(),
              hintStyle: TextStyle(color: widget.fontColor?.withOpacity(0.6)),
              prefixIcon: Icon(Icons.search, color: widget.fontColor),
              filled: true,
              fillColor: widget.fontColor?.withOpacity(0.2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.only(left: 8)),
          onChanged: (filterString) {
            print(filterString);
            _onSearchChanged(filterString); // Use the debounced search function
          },
          style: TextStyle(color: widget.fontColor, fontSize: 16),
        ),
      );

  }
}
