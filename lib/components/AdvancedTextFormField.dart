import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AdvancedTextFormField extends StatefulWidget {
  final TextEditingController? controller;
  final InputDecoration? decoration;
  final Future<List<dynamic>> Function(String)? asyncSuggestions;
  final List<dynamic>? suggestions;
  final Function(String)? onChanged;
  final Function(dynamic, TextEditingController controller)? onSelected;
  final bool dropdownOnlyMode;
  final bool autoFillOnSelection;
  final Duration debounceDuration;
  final Widget Function(BuildContext, dynamic)? suggestionBuilder;
  final bool? enableSuggestions;
  final bool? enableInteractiveSelection;
  final TextInputType? keyboardType;
  final InputDecorationTheme? inputDecorationTheme;
  final String? initialValue;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextDirection? textDirection;
  final TextAlign textAlign;
  final TextAlignVertical? textAlignVertical;
  final bool autofocus;
  final bool readOnly;
  final bool? showCursor;
  final bool autocorrect;
  final SmartDashesType? smartDashesType;
  final SmartQuotesType? smartQuotesType;
  final int? maxLines;
  final int? minLines;
  final bool expands;
  final int? maxLength;
  final MaxLengthEnforcement? maxLengthEnforcement;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldSetter<String>? onSaved;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter>? inputFormatters;
  final bool? enabled;
  final double cursorWidth;
  final double? cursorHeight;
  final Radius? cursorRadius;
  final Color? cursorColor;
  final Brightness? keyboardAppearance;
  final EdgeInsets scrollPadding;
  final TextSelectionControls? selectionControls;
  final InputCounterWidgetBuilder? buildCounter;
  final ScrollPhysics? scrollPhysics;
  final Iterable<String>? autofillHints;
  final AutovalidateMode? autovalidateMode;
  final ScrollController? scrollController;
  final String? restorationId;
  final bool enableIMEPersonalizedLearning;
  final MouseCursor? mouseCursor;
  final EditableTextContextMenuBuilder? contextMenuBuilder;
  final TextCapitalization? textCapitalization;

  const AdvancedTextFormField(
      {Key? key,
      this.controller,
      this.decoration,
      this.asyncSuggestions,
      this.suggestions,
      this.onChanged,
      this.onSelected,
      this.dropdownOnlyMode = false,
      this.autoFillOnSelection = false,
      this.debounceDuration = const Duration(milliseconds: 500),
      this.suggestionBuilder,
      this.initialValue,
      this.focusNode,
      this.keyboardType,
      this.textCapitalization = TextCapitalization.none,
      this.textInputAction,
      this.style,
      this.strutStyle,
      this.textDirection,
      this.textAlign = TextAlign.start,
      this.textAlignVertical,
      this.autofocus = false,
      this.readOnly = false,
      this.showCursor,
      this.autocorrect = true,
      this.smartDashesType,
      this.smartQuotesType,
      this.maxLines = 1,
      this.minLines,
      this.expands = false,
      this.maxLength,
      this.maxLengthEnforcement,
      this.onFieldSubmitted,
      this.onSaved,
      this.validator,
      this.inputFormatters,
      this.enabled,
      this.cursorWidth = 2.0,
      this.cursorHeight,
      this.cursorRadius,
      this.cursorColor,
      this.keyboardAppearance,
      this.scrollPadding = const EdgeInsets.all(20.0),
      this.selectionControls,
      this.buildCounter,
      this.scrollPhysics,
      this.autofillHints,
      this.autovalidateMode,
      this.scrollController,
      this.restorationId,
      this.enableIMEPersonalizedLearning = true,
      this.mouseCursor,
      this.contextMenuBuilder,
      this.enableSuggestions,
      this.enableInteractiveSelection,
      this.inputDecorationTheme})
      : super(key: key);

  @override
  _AdvancedTextFormFieldState createState() => _AdvancedTextFormFieldState();
}

class _AdvancedTextFormFieldState extends State<AdvancedTextFormField> {
  late TextEditingController _controller;
  OverlayEntry? _overlayEntry;
  List<dynamic> _filteredSuggestions = [];
  bool _isLoading = false;
  bool _hasSelected = false;
  final LayerLink _layerLink = LayerLink();
  Timer? _debounceTimer;
  dynamic _lastSelectedSuggestion;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _debounceTimer?.cancel();
    _controller.dispose();
    _overlayEntry?.remove();
    super.dispose();
  }

  String _lastText = ""; // Store the last known text in memory

  void _onTextChanged() {
    // Check if the text actually changed
    final currentText = _controller.text;
    if (currentText == _lastText) return; // Skip if text is unchanged

    _lastText = currentText; // Update memory with the new text
    print("_hasSelected $_hasSelected");

    if (_hasSelected) {
      if (_controller.text.isEmpty ||
          _lastSelectedSuggestion != _controller.text) {
        _hasSelected = false;
        _removeOverlay();
      }

      _removeOverlay();
      return;
    }

    if (widget.asyncSuggestions != null || widget.suggestions != null) {
      _debounce(() {
        if (currentText.isEmpty) {
          _filteredSuggestions = [];
          _removeOverlay();
        } else {
          _fetchSuggestions(currentText);
        }
      });
    }

    if (widget.onChanged != null) {
      widget.onChanged!(currentText);
    }
  }

  void _debounce(VoidCallback callback) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounceDuration, callback);
  }

  Future<void> _fetchSuggestions(String query) async {
    setState(() {
      _isLoading = true;
    });

    if (widget.asyncSuggestions != null) {
      _filteredSuggestions = await widget.asyncSuggestions!(query);
    } else if (widget.suggestions != null) {
      _filteredSuggestions = widget.suggestions!
          .where((item) =>
              item.toString().toLowerCase().contains(query.toLowerCase()))
          .toList();
    }

    setState(() {
      _isLoading = false;
    });

    _showOverlay();
  }

  void _showOverlay() {
    if (_filteredSuggestions.isEmpty) {
      _removeOverlay();
      return;
    }

    _overlayEntry?.remove();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 5),
          child: Material(
            elevation: 4.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _filteredSuggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = _filteredSuggestions[index];
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _hasSelected = true;
                      });
                      _lastSelectedSuggestion = suggestion.toString();
                      if (widget.autoFillOnSelection) {
                        _controller.text = suggestion.toString();
                      }
                      _removeOverlay();
                      if (widget.onSelected != null) {
                        widget.onSelected!(suggestion, _controller);
                      }
                    },
                    child: widget.suggestionBuilder != null
                        ? widget.suggestionBuilder!(context, suggestion)
                        : ListTile(
                            title: Text(suggestion.toString()),
                          ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        onTapOutside: (event) {
          if (_controller.text.isEmpty) {
            _removeOverlay();
            _filteredSuggestions.clear();
            _controller.clear();
          }
        },
        focusNode: widget.focusNode,
        keyboardType: widget.keyboardType,
        textCapitalization:
            widget.textCapitalization ?? TextCapitalization.none,
        textInputAction: widget.textInputAction,
        style: widget.style,
        strutStyle: widget.strutStyle,
        textDirection: widget.textDirection,
        textAlign: widget.textAlign,
        textAlignVertical: widget.textAlignVertical,
        autofocus: widget.autofocus,
        readOnly: widget.readOnly,
        showCursor: widget.showCursor,
        autocorrect: widget.autocorrect,
        smartDashesType: widget.smartDashesType,
        smartQuotesType: widget.smartQuotesType,
        enableSuggestions: widget.enableSuggestions ?? true,
        enableInteractiveSelection: widget.enableInteractiveSelection ?? true,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        expands: widget.expands,
        maxLength: widget.maxLength,
        maxLengthEnforcement: widget.maxLengthEnforcement,
        onSaved: widget.onSaved,
        validator: widget.validator,
        inputFormatters: widget.inputFormatters,
        enabled: widget.enabled,
        cursorWidth: widget.cursorWidth,
        cursorHeight: widget.cursorHeight,
        cursorRadius: widget.cursorRadius,
        cursorColor: widget.cursorColor,
        keyboardAppearance: widget.keyboardAppearance,
        scrollPadding: widget.scrollPadding,
        selectionControls: widget.selectionControls,
        buildCounter: widget.buildCounter,
        scrollPhysics: widget.scrollPhysics,
        scrollController: widget.scrollController,
        autofillHints: widget.autofillHints,
        autovalidateMode: widget.autovalidateMode,
        restorationId: widget.restorationId,
        enableIMEPersonalizedLearning: widget.enableIMEPersonalizedLearning,
        mouseCursor: widget.mouseCursor,
        contextMenuBuilder: widget.contextMenuBuilder,
        controller: _controller,
        decoration: widget.decoration?.copyWith(
          suffixIcon: _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
        ),
        onFieldSubmitted: (value) {
          if (widget.dropdownOnlyMode &&
              !_filteredSuggestions.contains(value)) {
            _controller.clear();
          }
        },
      ),
    );
  }
}
