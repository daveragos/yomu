import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Keyboard shortcuts for a whole screen that keep working however focus
/// moves around it.
///
/// Flutter's `Shortcuts` only see keys while focus is inside them, and on a
/// desktop focus often comes to rest on nothing in particular (after a
/// click on plain text, or when the window comes back to the front). Then
/// keys go to Flutter's defaults instead, where an arrow moves focus to some
/// button and Space presses it.
///
/// This screen-wide focus node takes focus back whenever it is left resting
/// on nothing, and handles its keys itself, so the defaults never act on
/// them too. It stands aside while a text field has focus, so Space and the
/// arrows still type and move the caret, and while a dialog or panel covers
/// the screen.
class RouteShortcuts extends StatefulWidget {
  final Map<ShortcutActivator, VoidCallback> bindings;
  final Widget child;

  const RouteShortcuts({
    super.key,
    required this.bindings,
    required this.child,
  });

  @override
  State<RouteShortcuts> createState() => _RouteShortcutsState();
}

class _RouteShortcutsState extends State<RouteShortcuts> {
  final FocusNode _node = FocusNode(debugLabel: 'RouteShortcuts');
  ModalRoute<Object?>? _route;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_reclaimIdleFocus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_reclaimIdleFocus);
    _node.dispose();
    super.dispose();
  }

  bool get _isOnTop => _route == null || _route!.isCurrent;

  /// When focus lands on a scope (nothing specific focused), take it.
  void _reclaimIdleFocus() {
    if (!mounted || !_isOnTop) return;
    final primary = FocusManager.instance.primaryFocus;
    if (primary == _node) return;
    if (primary != null && primary is! FocusScopeNode) return;
    scheduleMicrotask(() {
      if (mounted && _isOnTop && !_node.hasFocus) _node.requestFocus();
    });
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || _isEditingText) return KeyEventResult.ignored;
    for (final entry in widget.bindings.entries) {
      if (entry.key.accepts(event, HardwareKeyboard.instance)) {
        entry.value();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  /// Whether a text field has focus. Then the key belongs to it.
  bool get _isEditingText {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null) return false;
    return focused.widget is EditableText ||
        focused.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: widget.child,
    );
  }
}
