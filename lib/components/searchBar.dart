import 'dart:async';

import 'package:chitchat/components/friendcircle.dart';
import 'package:chitchat/services/groups.dart';
import 'package:chitchat/services/search.dart';
import 'package:flutter/material.dart';

class ImprovedSearchBar extends StatefulWidget {
  final Duration debounceDuration;
  String selectedType;
  final Function(bool) onLoading;
  final Function(String) onSelectedType;

  final Function(List<FriendCircleGroup>) onGroupSearchResult;
  final Function(List<Map<String, dynamic>>) onUserSearchResult;
  final Function(List<Map<String, dynamic>>) onCollegeSearchResult;
  final Function(List<Map<String, dynamic>>) onUniversitySearchResult;
  final Function(List<Map<String, dynamic>>) onSchoolSearchResult;

  ImprovedSearchBar({
    super.key,
    required this.selectedType,
    required this.onLoading,
    required this.onSelectedType,
    required this.onGroupSearchResult,
    required this.onUserSearchResult,
    required this.onCollegeSearchResult,
    required this.onUniversitySearchResult,
    required this.onSchoolSearchResult,
    this.debounceDuration = const Duration(milliseconds: 500),
  });

  @override
  State<ImprovedSearchBar> createState() => _ImprovedSearchBarState();
}

class _ImprovedSearchBarState extends State<ImprovedSearchBar> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;
  List<FriendCircleGroup> searchResultGroups = [];

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();

    super.dispose();
  }

  void _performSearch(String query) {
    // Cancel any existing timer
    _debounceTimer?.cancel();

    // Set a new timer to delay the search
    _debounceTimer = Timer(widget.debounceDuration, () async {
      try {
        // Perform the search here
        if (widget.selectedType == "Groups") {
          print('Searching for: $query');
          widget.onLoading(true);
          searchResultGroups = await SearchService.searchByGroup(query);
          // Update the UI with the search results
          setState(() {});
          print(searchResultGroups);
          widget.onLoading(false);

          // Call the callback function with the search results
          widget.onGroupSearchResult(searchResultGroups);
        } else if (widget.selectedType == "Name") {
          print('Searching for: $query');
          widget.onLoading(true);
          var searchResultGroups = await SearchService.searchByUser(query);
          // Update the UI with the search results
          setState(() {});
          print(searchResultGroups);
          widget.onLoading(false);

          // Call the callback function with the search results
          widget.onUserSearchResult(searchResultGroups);
        } else if (widget.selectedType == "College") {
          print('Searching for: $query');
          widget.onLoading(true);
          var searchResultGroups = await SearchService.searchByCollege(query);
          // Update the UI with the search results
          setState(() {});
          print(searchResultGroups);
          widget.onLoading(false);

          // Call the callback function with the search results
          widget.onCollegeSearchResult(searchResultGroups);
        } else if (widget.selectedType == "University") {
          print('Searching for: $query');
          widget.onLoading(true);
          var searchResultGroups =
              await SearchService.searchByUniversity(query);
          // Update the UI with the search results
          setState(() {});
          print(searchResultGroups);
          widget.onLoading(false);

          // Call the callback function with the search results
          widget.onUniversitySearchResult(searchResultGroups);
        } else if (widget.selectedType == "School") {
          print('Searching for: $query');
          widget.onLoading(true);
          var searchResultGroups = await SearchService.searchBySchool(query);
          setState(() {});
          print(searchResultGroups);
          widget.onLoading(false);
          widget.onSchoolSearchResult(searchResultGroups);
        } else if (widget.selectedType == "Passout") {
          print('Searching passout groups for: $query');
          widget.onLoading(true);
          searchResultGroups = await SearchService.searchByGroup(query);
          setState(() {});
          print(searchResultGroups);
          widget.onLoading(false);
          widget.onGroupSearchResult(searchResultGroups);
        }
      } catch (e) {
        print("Error during search: $e");
        widget.onLoading(false);
        widget.onGroupSearchResult([]);
        widget.onUserSearchResult([]);
        widget.onCollegeSearchResult([]);
        widget.onUniversitySearchResult([]);
        widget.onSchoolSearchResult([]);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          // Search Icon
          const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Icon(Icons.search, color: Colors.grey),
          ),

          // Search TextField
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: _getHintText(),
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (value) {
                // Implement search functionality
                _performSearch(value);
              },
            ),
          ),

          // Clear button - only shows when text is entered
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
              onPressed: () {
                _searchController.clear();
                _debounceTimer?.cancel(); // Cancel any pending search
                widget.onGroupSearchResult([]); // Clear the search results
                widget.onLoading(false);
                widget.onUserSearchResult([]);
                widget.onCollegeSearchResult([]);
                widget.onUniversitySearchResult([]);
                widget.onSchoolSearchResult([]);
                setState(() {});
              },
            ),

          // Vertical divider
          Container(
            height: 24,
            width: 1,
            color: Colors.grey.withOpacity(0.3),
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),

          // Dropdown for search type
          PopupMenuButton<String>(
            initialValue: widget.selectedType,
            tooltip: 'Select search type',
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.selectedType,
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down,
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
            onSelected: (String value) {
              setState(() {
                widget.selectedType = value;
                // Clear text when switching search type
                _searchController.clear();
                widget.onSelectedType(value);
              });
              // Return focus to search field
              _searchFocusNode.requestFocus();
            },
            itemBuilder: (BuildContext context) {
              return <String>[
                'Name',
                'Groups',
                'School',
                'College',
                'University',
                'Passout'
              ].map<PopupMenuItem<String>>((String value) {
                return PopupMenuItem<String>(
                  value: value,
                  child: Row(
                    children: [
                      _getIconForType(value),
                      const SizedBox(width: 12),
                      Text(value),
                    ],
                  ),
                );
              }).toList();
            },
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ],
      ),
    );
  }

  String _getHintText() {
    switch (widget.selectedType) {
      case 'Name':
        return 'Search by name...';
      case 'Groups':
        return 'Search friend groups...';
      case 'School':
        return 'Search by school...';
      case 'College':
        return 'Search by college...';
      case 'University':
        return 'Search by university...';
      case 'Passout':
        return 'Search passout groups...';
      default:
        return 'Search...';
    }
  }

  Widget _getIconForType(String type) {
    switch (type) {
      case 'Name':
        return const Icon(Icons.person_outline, size: 20);
      case 'Groups':
        return const Icon(Icons.group_outlined, size: 20);
      case 'School':
        return const Icon(Icons.menu_book_outlined, size: 20);
      case 'College':
        return const Icon(Icons.school_outlined, size: 20);
      case 'University':
        return const Icon(Icons.account_balance_outlined, size: 20);
      case 'Passout':
        return const Icon(Icons.card_membership_outlined, size: 20);
      default:
        return const Icon(Icons.search, size: 20);
    }
  }
}

// // Example usage in a page
// class SearchPage extends StatelessWidget {
//   const SearchPage({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Friend Circles'),
//         elevation: 0,
//       ),
//       body: Column(
//         children: [
//           const ImprovedSearchBar(),
//           Expanded(
//             child: Center(
//               child: Text(
//                 'Search results will appear here',
//                 style: TextStyle(color: Colors.grey.shade600),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
