import 'package:chitchat/constants/colors.dart';
import 'package:flutter/material.dart';

/// A reusable bottom sheet component with search functionality
/// for selecting items from a list.
class SelectionBottomSheet<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final String Function(T item) itemLabel;
  final void Function(T item) onSelected;
  final Widget Function(T item, bool isSelected)? itemBuilder;

  const SelectionBottomSheet({
    Key? key,
    required this.title,
    required this.items,
    required this.itemLabel,
    required this.onSelected,
    this.itemBuilder,
  }) : super(key: key);

  @override
  State<SelectionBottomSheet<T>> createState() =>
      _SelectionBottomSheetState<T>();

  /// Shows the bottom sheet and returns the selected item
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required List<T> items,
    required String Function(T item) itemLabel,
    Widget Function(T item, bool isSelected)? itemBuilder,
  }) async {
    T? selectedItem;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SelectionBottomSheet<T>(
        title: title,
        items: items,
        itemLabel: itemLabel,
        itemBuilder: itemBuilder,
        onSelected: (item) {
          selectedItem = item;
          Navigator.pop(context);
        },
      ),
    );
    return selectedItem;
  }
}

class _SelectionBottomSheetState<T> extends State<SelectionBottomSheet<T>> {
  final TextEditingController _searchController = TextEditingController();
  List<T> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredItems = widget.items;
      } else {
        _filteredItems = widget.items
            .where(
                (item) => widget.itemLabel(item).toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.75,
      decoration: BoxDecoration(
        color: AppColors.bottomSheetBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: AppColors.bottomSheetBorder, width: 0.5),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[500],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              widget.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[400]),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Scrollable list
          Expanded(
            child: _filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 48, color: Colors.grey[500]),
                        const SizedBox(height: 8),
                        Text(
                          'No results found',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredItems.length,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];

                      if (widget.itemBuilder != null) {
                        return InkWell(
                          onTap: () => widget.onSelected(item),
                          child: widget.itemBuilder!(item, false),
                        );
                      }

                      return ListTile(
                        title: Text(
                          widget.itemLabel(item),
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right,
                            color: Colors.white70),
                        onTap: () => widget.onSelected(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// A variant that supports async loading of items
class AsyncSelectionBottomSheet<T> extends StatefulWidget {
  final String title;
  final Future<List<T>> Function(String query) fetchItems;
  final String Function(T item) itemLabel;
  final void Function(T item) onSelected;
  final Widget Function(T item)? itemBuilder;
  final Duration debounceDuration;

  const AsyncSelectionBottomSheet({
    Key? key,
    required this.title,
    required this.fetchItems,
    required this.itemLabel,
    required this.onSelected,
    this.itemBuilder,
    this.debounceDuration = const Duration(milliseconds: 500),
  }) : super(key: key);

  @override
  State<AsyncSelectionBottomSheet<T>> createState() =>
      _AsyncSelectionBottomSheetState<T>();

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Future<List<T>> Function(String query) fetchItems,
    required String Function(T item) itemLabel,
    Widget Function(T item)? itemBuilder,
    Duration debounceDuration = const Duration(milliseconds: 500),
  }) async {
    T? selectedItem;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AsyncSelectionBottomSheet<T>(
        title: title,
        fetchItems: fetchItems,
        itemLabel: itemLabel,
        itemBuilder: itemBuilder,
        debounceDuration: debounceDuration,
        onSelected: (item) {
          selectedItem = item;
          Navigator.pop(context);
        },
      ),
    );
    return selectedItem;
  }
}

class _AsyncSelectionBottomSheetState<T>
    extends State<AsyncSelectionBottomSheet<T>> {
  final TextEditingController _searchController = TextEditingController();
  List<T> _items = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastSearch;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;

    // Debounce search
    _lastSearch = DateTime.now();
    Future.delayed(widget.debounceDuration, () {
      if (DateTime.now().difference(_lastSearch!).inMilliseconds >=
          widget.debounceDuration.inMilliseconds - 50) {
        _fetchItems(query);
      }
    });
  }

  Future<void> _fetchItems(String query) async {
    if (query.length < 2) {
      if (mounted) {
        setState(() {
          _items = [];
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final items = await widget.fetchItems(query);
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.75,
      decoration: BoxDecoration(
        color: AppColors.bottomSheetBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: AppColors.bottomSheetBorder, width: 0.5),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[500],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              widget.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Type to search (min 2 characters)...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[400]),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _items = []);
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
            const SizedBox(height: 8),
            Text(
              'Error loading data',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    if (_searchController.text.length < 2) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 48, color: Colors.grey[500]),
            const SizedBox(height: 8),
            Text(
              'Start typing to search',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey[500]),
            const SizedBox(height: 8),
            Text(
              'No results found',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _items.length,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemBuilder: (context, index) {
        final item = _items[index];

        if (widget.itemBuilder != null) {
          return InkWell(
            onTap: () => widget.onSelected(item),
            child: widget.itemBuilder!(item),
          );
        }

        return ListTile(
          title: Text(
            widget.itemLabel(item),
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.white70),
          onTap: () => widget.onSelected(item),
        );
      },
    );
  }
}
