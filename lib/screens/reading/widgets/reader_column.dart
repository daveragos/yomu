import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../components/desktop/page_header.dart';
import '../../../core/breakpoints.dart';
import '../../../core/constants.dart';
import '../../../models/reader_settings_model.dart';

/// Shows a book at a readable width in a wide window, with clickable
/// gutters on either side that turn the page (an arrow appears on hover).
///
/// The child sees the column's width as the screen width, so layout that
/// measures `MediaQuery` (images, tables, selection toolbars) stays inside
/// the column. In narrow windows the column is the full width.
///
/// [zoom] magnifies the page, as a pinch does: the column is laid out at
/// its normal width and drawn [zoom] times larger, growing into the gutters
/// until it fills the window, then enlarging within it.
///
/// The widget tree has the same shape at every width. Swapping shapes when
/// the window crosses a breakpoint would rebuild the book from scratch.
class ReaderColumn extends StatelessWidget {
  final double maxWidth;
  final double zoom;
  final Color color;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final Widget child;

  /// Gutters narrower than this don't get page-turn arrows.
  static const double _minGutterForArrows = 72;

  const ReaderColumn({
    super.key,
    required this.maxWidth,
    this.zoom = 1,
    required this.color,
    required this.onPrevious,
    required this.onNext,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = Breakpoints.isWide(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final baseWidth = isWide
            ? math.min(maxWidth, constraints.maxWidth)
            : constraints.maxWidth;
        final columnWidth = math.min(baseWidth * zoom, constraints.maxWidth);
        final gutter = (constraints.maxWidth - columnWidth) / 2;
        final mq = MediaQuery.of(context);
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : mq.size.height;
        // The size the book is laid out at; drawn zoom times larger it
        // covers the column.
        final layout = Size(columnWidth / zoom, height / zoom);
        Widget column = MediaQuery(
          data: mq.copyWith(
            size: zoom == 1 ? Size(columnWidth, mq.size.height) : layout,
          ),
          child: child,
        );
        if (zoom != 1) {
          column = ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: layout.width,
              maxWidth: layout.width,
              minHeight: layout.height,
              maxHeight: layout.height,
              child: Transform.scale(
                scale: zoom,
                alignment: Alignment.topLeft,
                child: column,
              ),
            ),
          );
        }
        final showArrows = isWide && gutter >= _minGutterForArrows;

        return Row(
          children: [
            SizedBox(
              width: gutter,
              child: showArrows
                  ? _PageTurnGutter(
                      icon: Icons.chevron_left_rounded,
                      tooltip: 'Previous page',
                      color: color,
                      onTap: onPrevious,
                    )
                  : null,
            ),
            SizedBox(width: columnWidth, child: column),
            SizedBox(
              width: gutter,
              child: showArrows
                  ? _PageTurnGutter(
                      icon: Icons.chevron_right_rounded,
                      tooltip: 'Next page',
                      color: color,
                      onTap: onNext,
                    )
                  : null,
            ),
          ],
        );
      },
    );
  }
}

class _PageTurnGutter extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _PageTurnGutter({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  State<_PageTurnGutter> createState() => _PageTurnGutterState();
}

class _PageTurnGutterState extends State<_PageTurnGutter> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Center(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: _hovered ? 1 : 0,
            child: Tooltip(
              message: widget.tooltip,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  color: widget.color.withValues(alpha: 0.7),
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the highlight menu as soon as the reader finishes selecting text
/// with the mouse.
///
/// On macOS, Flutter's text selection only shows its menu on right-click,
/// and a right-click there re-selects the word under the pointer. Readers
/// expect the highlight menu right after dragging across a passage or
/// double-clicking a word, so this shows the page's own menu (its
/// `SelectionArea.contextMenuBuilder`) for the current selection.
class DesktopSelectionMenu extends StatefulWidget {
  final Widget child;

  const DesktopSelectionMenu({super.key, required this.child});

  static ContextMenuController? _shown;

  /// Where the open menu points: the spot the mouse was released, which is
  /// always on the selection. The selection's own geometry can't be used:
  /// while the reader rebuilds around a drag (its controls come back as the
  /// pointer moves) the page's text re-registers and the geometry briefly
  /// points at the top of the chapter.
  static Offset? _anchor;

  /// Whether the open menu is this one (opened after a mouse selection),
  /// rather than Flutter's own right-click or touch menu.
  static bool get isOpening => _anchor != null;

  /// Anchors for the page's menu builder: the release point while this menu
  /// is open, otherwise the selection's own anchors (right-click, touch).
  static TextSelectionToolbarAnchors anchorsFor(SelectableRegionState region) {
    final anchor = _anchor;
    return anchor != null
        ? TextSelectionToolbarAnchors(primaryAnchor: anchor)
        : region.contextMenuAnchors;
  }

  /// Whether the menu is open.
  static bool get isShown => _shown?.isShown ?? false;

  /// Closes the menu if one is open. Returns whether it was.
  static bool dismiss() {
    final shown = _shown;
    _shown = null;
    _anchor = null;
    if (shown == null || !shown.isShown) return false;
    shown.remove();
    return true;
  }

  @override
  State<DesktopSelectionMenu> createState() => _DesktopSelectionMenuState();
}

class _DesktopSelectionMenuState extends State<DesktopSelectionMenu> {
  Offset? _downPosition;
  DateTime? _lastClickUp;

  /// Two clicks closer together than this make a double-click (word select).
  static const _multiClickWindow = Duration(milliseconds: 400);

  @override
  void dispose() {
    DesktopSelectionMenu.dismiss();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        if (event.kind != PointerDeviceKind.mouse ||
            event.buttons != kPrimaryMouseButton) {
          return;
        }
        // A new click in the text starts a new selection; the old menu goes.
        DesktopSelectionMenu.dismiss();
        _downPosition = event.position;
      },
      onPointerUp: (event) {
        final down = _downPosition;
        _downPosition = null;
        if (event.kind != PointerDeviceKind.mouse || down == null) return;

        final now = DateTime.now();
        final dragged = (event.position - down).distance > 4;
        final multiClick =
            _lastClickUp != null &&
            now.difference(_lastClickUp!) < _multiClickWindow;
        _lastClickUp = dragged ? null : now;
        if (!dragged && !multiClick) return;

        // Let the selection settle, in a frame of its own: an idle window
        // may not draw another one until the pointer moves again.
        WidgetsBinding.instance
          ..addPostFrameCallback((_) => _showMenu(event.position))
          ..scheduleFrame();
      },
      onPointerSignal: (_) => DesktopSelectionMenu.dismiss(),
      child: widget.child,
    );
  }

  void _showMenu(Offset position) {
    if (!mounted) return;
    final found = _selectionAreaAt(position);
    if (found == null) return;
    final (area, areaState) = found;
    final builder = area.contextMenuBuilder;
    if (builder == null) return;

    final region = areaState.selectableRegion;
    try {
      // Throws when nothing is selected (a drag across empty space).
      region.selectionEndpoints;
    } catch (_) {
      return;
    }

    final controller = ContextMenuController();
    DesktopSelectionMenu.dismiss();
    DesktopSelectionMenu._shown = controller;
    DesktopSelectionMenu._anchor = position;
    controller.show(
      context: region.context,
      contextMenuBuilder: (menuContext) => TapRegion(
        onTapOutside: (_) => DesktopSelectionMenu.dismiss(),
        // Every action in the menu finishes with it closed, but the page's
        // own close call only reaches menus Flutter opened itself.
        child: Listener(
          onPointerUp: (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
            if (identical(DesktopSelectionMenu._shown, controller)) {
              DesktopSelectionMenu.dismiss();
            }
          }),
          child: builder(menuContext, region),
        ),
      ),
    );
  }

  /// The text selection area under [position], if any.
  (SelectionArea, SelectionAreaState)? _selectionAreaAt(Offset position) {
    (SelectionArea, SelectionAreaState)? found;
    void visit(Element element) {
      if (found != null) return;
      if (element is StatefulElement && element.state is SelectionAreaState) {
        final box = element.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          final rect = box.localToGlobal(Offset.zero) & box.size;
          if (rect.contains(position)) {
            found = (
              element.widget as SelectionArea,
              element.state as SelectionAreaState,
            );
            return;
          }
        }
      }
      element.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
    return found;
  }
}

/// Opens a PDF at a readable size in a wide window.
///
/// The viewer fits the page to the window's width, which in a large window
/// makes a page of ordinary text huge. Once the document is ready this
/// zooms out so a page is at most [maxPageWidth] wide. The viewer keeps the
/// whole window, so zooming in later has room and nothing is cropped.
class PdfDesktopFit extends StatefulWidget {
  final PdfViewerController? controller;
  final bool isReady;
  final double maxPageWidth;

  /// Called after the zoom changes, so the reader can put the current page
  /// back at the top.
  final VoidCallback onFitted;
  final Widget child;

  const PdfDesktopFit({
    super.key,
    required this.controller,
    required this.isReady,
    required this.maxPageWidth,
    required this.onFitted,
    required this.child,
  });

  /// Fits [controller]'s page width to [maxPageWidth], or to the window with
  /// a margin when that's narrower. Returns whether the zoom changed.
  static Future<bool> fit(
    PdfViewerController controller,
    double maxPageWidth,
  ) async {
    if (!controller.isReady || controller.layout.pageLayouts.isEmpty) {
      return false;
    }
    final pageWidth = controller.layout.pageLayouts.first.width;
    final target = math.min(controller.viewSize.width - 96, maxPageWidth);
    if (pageWidth <= 0 || target <= 0) return false;
    final zoom = math.max(target / pageWidth, controller.minScale);
    if ((zoom - controller.currentZoom).abs() < 0.01) return false;
    await controller.setZoom(
      controller.centerPosition,
      zoom,
      duration: Duration.zero,
    );
    return true;
  }

  @override
  State<PdfDesktopFit> createState() => _PdfDesktopFitState();
}

class _PdfDesktopFitState extends State<PdfDesktopFit> {
  bool _fitted = false;
  Offset? _downPosition;
  DateTime? _lastClickUp;

  @override
  void initState() {
    super.initState();
    _maybeFit();
  }

  @override
  void didUpdateWidget(PdfDesktopFit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) _fitted = false;
    _maybeFit();
  }

  void _maybeFit() {
    if (_fitted || !widget.isReady) return;
    _fitted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = widget.controller;
      if (!mounted || controller == null || !Breakpoints.isWide(context)) {
        return;
      }
      if (await PdfDesktopFit.fit(controller, widget.maxPageWidth)) {
        widget.onFitted();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // As in EPUBs, a mouse selection opens the highlight menu right away.
    // The PDF viewer only does that on right-click with a mouse.
    return Listener(
      onPointerDown: (event) {
        if (event.kind == PointerDeviceKind.mouse &&
            event.buttons == kPrimaryMouseButton) {
          _downPosition = event.position;
        }
      },
      onPointerUp: (event) {
        final down = _downPosition;
        _downPosition = null;
        if (event.kind != PointerDeviceKind.mouse || down == null) return;
        final now = DateTime.now();
        final dragged = (event.position - down).distance > 4;
        final multiClick =
            _lastClickUp != null &&
            now.difference(_lastClickUp!) < const Duration(milliseconds: 400);
        _lastClickUp = dragged ? null : now;
        if (dragged || multiClick) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _showSelectionMenu(event.position),
          );
        }
      },
      child: widget.child,
    );
  }

  void _showSelectionMenu(Offset globalPosition) {
    final controller = widget.controller;
    if (!mounted || controller == null || !controller.isReady) return;
    final selection = controller.textSelectionDelegate;
    if (!selection.hasSelectedText) return;
    final docPosition = controller.globalToDocument(globalPosition);
    if (docPosition == null) return;
    try {
      // The viewer's own right-click action, which keeps the selection.
      // It isn't part of pdfrx's public interface, so a future version
      // without it just loses this shortcut.
      (selection as dynamic).showContextMenu(docPosition);
    } catch (_) {}
  }
}

/// Turns a trackpad pinch into a scale, such as the page zoom.
///
/// A pinch over text is otherwise lost: the text scrolls, it doesn't zoom.
/// The [onScale] callback receives the pinch's scale relative to where it
/// started; scrolling with two fingers (scale 1) is ignored.
class PinchListener extends StatelessWidget {
  final VoidCallback onStart;
  final ValueChanged<double> onScale;
  final Widget child;

  const PinchListener({
    super.key,
    required this.onStart,
    required this.onScale,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerPanZoomStart: (_) => onStart(),
      onPointerPanZoomUpdate: (event) {
        if ((event.scale - 1).abs() > 0.02) onScale(event.scale);
      },
      child: child,
    );
  }
}

/// What the app's menu bar can ask of the open reader.
class ReaderCommands {
  final ValueChanged<int> zoom;
  final VoidCallback resetZoom;

  const ReaderCommands({required this.zoom, required this.resetZoom});

  /// The reader on screen, if any. The menu bar lives above the navigator,
  /// so it reaches the reader through here.
  static ReaderCommands? current;
}

/// Makes [commands] the menu bar's target while this reader is on screen.
class ReaderCommandScope extends StatefulWidget {
  final ReaderCommands commands;
  final Widget child;

  const ReaderCommandScope({
    super.key,
    required this.commands,
    required this.child,
  });

  @override
  State<ReaderCommandScope> createState() => _ReaderCommandScopeState();
}

class _ReaderCommandScopeState extends State<ReaderCommandScope> {
  @override
  void initState() {
    super.initState();
    ReaderCommands.current = widget.commands;
  }

  @override
  void didUpdateWidget(ReaderCommandScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    ReaderCommands.current = widget.commands;
  }

  @override
  void dispose() {
    if (identical(ReaderCommands.current, widget.commands)) {
      ReaderCommands.current = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Shown in place of a book whose file Yomu can no longer read, with a way
/// to find it again.
class MissingBookFile extends StatelessWidget {
  final String fileName;
  final String folder;
  final ReaderSettings settings;
  final VoidCallback onLocate;

  const MissingBookFile({
    super.key,
    required this.fileName,
    required this.folder,
    required this.settings,
    required this.onLocate,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.folder_open_rounded,
                  color: YomuConstants.textSecondary,
                  size: 30,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Yomu can't open this file anymore",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: settings.textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'macOS only let Yomu read "$fileName" while it was open the '
                'first time. Find it once more and Yomu keeps its own copy, '
                'with your progress and notes.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: settings.secondaryTextColor,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              DesktopPrimaryButton(
                icon: Icons.search_rounded,
                label: 'Locate file…',
                onPressed: onLocate,
              ),
              const SizedBox(height: 12),
              Text(
                folder,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: settings.secondaryTextColor.withValues(alpha: 0.7),
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
