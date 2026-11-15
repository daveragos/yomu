import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'chapter_pages.dart';

/// Where a chapter shown as pages is, and what its pages are.
///
/// Shared by the chapter's [PagedChapterView] (gestures and animation), its
/// render object (layout and paint) and the reader (page turns from keys,
/// taps and auto page turn, and the progress it saves).
class PagedChapterController extends ChangeNotifier {
  double _position = 0;
  ChapterPages? _pages;
  double? _pendingProgress;
  bool _pinnedToEnd = false;

  /// A saved place that was opened and not moved from yet. Layouts change
  /// while a book opens (the controls and system bars come and go), and
  /// the place is worked out again from it each time until the reader turns
  /// a page, so it isn't nudged a page off along the way.
  double? _restoredProgress;
  _Anchor? _anchor;
  _RenderPagedChapter? _render;
  _PagedChapterViewState? _view;

  /// The page on screen; fractional while a page slides.
  double get position => _position;
  set position(double value) {
    if (value == _position) return;
    _position = value;
    notifyListeners();
  }

  /// The pages, once the chapter has been laid out.
  ChapterPages? get pages => _pages;
  int get pageCount => _pages?.count ?? 1;

  /// The page the reader is on (the nearest one while sliding).
  int get page => _position.round().clamp(0, pageCount - 1);

  /// The chapter position the reader stores (see [ChapterPages.progressOf]).
  double get progress => _pages?.progressOf(page) ?? 0;

  bool get hasPages => _pages != null;

  /// The lines and pictures the pages were cut around, for tests.
  @visibleForTesting
  List<ContentBand> get debugBands => _render?._lines ?? const [];

  /// Opens the page holding [progress], now or as soon as there is a layout.
  void jumpToProgress(double progress) {
    _pinnedToEnd = false;
    _restoredProgress = progress;
    final pages = _pages;
    if (pages == null) {
      _pendingProgress = progress;
      return;
    }
    _view?._stopAnimation();
    position = pages.pageForProgress(progress).toDouble();
    _captureAnchorAfterFrame();
  }

  /// Opens the last page, and keeps it there while late content (decoded
  /// pictures) adds pages, until the reader turns a page.
  void jumpToEnd() {
    jumpToProgress(1);
    _restoredProgress = null;
    _pinnedToEnd = true;
  }

  /// The reader moved the page: layouts from now on keep the line at the
  /// top of the page instead of a restored place.
  void _userMoved() {
    _pinnedToEnd = false;
    _restoredProgress = null;
  }

  /// Turns one page forward (1) or back (-1), into the next or previous
  /// chapter at either end. False when there is nowhere to go.
  bool turn(int direction) => _view?._turn(direction) ?? false;

  void _setFromLayout(ChapterPages pages, int page) {
    _pages = pages;
    _position = page.toDouble();
  }

  /// Remembers the first line on the page, so the same line opens the page
  /// after the text reflows (text size, rotation, window size).
  void _captureAnchorAfterFrame() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _anchor = _render?._anchorFor(page) ?? _anchor;
    });
  }

  @override
  void dispose() {
    _render = null;
    _view = null;
    super.dispose();
  }
}

/// A place in the text: a paragraph and a character in it.
class _Anchor {
  const _Anchor(this.paragraph, this.offset);
  final RenderParagraph paragraph;
  final int offset;
}

/// One line (or picture) of the laid-out chapter, with what is needed to
/// find its text again after a reflow.
class _Line extends ContentBand {
  const _Line(super.top, super.bottom, this.paragraph, this.localPoint);
  final RenderParagraph? paragraph;
  final Offset localPoint;
}

/// Shows a chapter one page at a time and lets the reader slide between
/// pages; at a chapter's first or last page the slide carries on into the
/// neighbouring chapter in [chapterController].
class PagedChapterView extends StatefulWidget {
  const PagedChapterView({
    super.key,
    required this.controller,
    required this.padding,
    required this.child,
    required this.chapterIndex,
    required this.chapterCount,
    this.chapterController,
    this.onPaginated,
    this.onSettled,
    this.onUserTurn,
    this.onCenterTap,
    this.onTapWithSelection,
    this.beforeSlide,
    this.enabled = true,
  });

  final PagedChapterController controller;

  /// Margins of the page inside the view.
  final EdgeInsets padding;

  /// The whole chapter as one column; it is laid out once at page width.
  final Widget child;

  final int chapterIndex;
  final int chapterCount;

  /// The pager of chapters, driven when a slide crosses a chapter's edge.
  final PageController? chapterController;

  /// After every layout that changed the pages (first layout, reflow).
  final VoidCallback? onPaginated;

  /// When a page has finished sliding into place.
  final VoidCallback? onSettled;

  /// When the reader starts to move the page (to hide the controls).
  final VoidCallback? onUserTurn;

  /// A tap in the middle third of the page.
  final VoidCallback? onCenterTap;

  /// Called for a tap while text is selected; return true when it only
  /// dismissed the selection, so the page doesn't turn.
  final bool Function()? onTapWithSelection;

  /// Called before a page starts to move, to drop the text selection
  /// (selection handles can't be drawn on two pages at once).
  final VoidCallback? beforeSlide;

  /// False for a chapter that is not the one being read.
  final bool enabled;

  @override
  State<PagedChapterView> createState() => _PagedChapterViewState();
}

class _PagedChapterViewState extends State<PagedChapterView>
    with SingleTickerProviderStateMixin {
  /// Share of the width at each side where a tap turns the page.
  static const double _edgeTapZone = 0.3;

  /// A flick at least this fast (logical px/s) turns the page however far
  /// it was dragged.
  static const double _flingVelocity = 350;

  static const Duration _slideDuration = Duration(milliseconds: 280);

  late final AnimationController _animation = AnimationController.unbounded(
    vsync: this,
  )..addListener(_onAnimate);

  /// The drag handed to the chapter pager, while a slide crosses into the
  /// next or previous chapter.
  Drag? _chapterDrag;
  int _chapterDragDirection = 0;

  double _width = 1;

  /// A swipe is under way. The chapter it started in stays able to finish
  /// it even after the swipe made the next chapter the current one.
  bool _swiping = false;
  /// When the wheel last turned a page, in pointer event time.
  Duration? _lastWheelTurn;
  double _trackpadPan = 0;
  bool _trackpadTurned = false;

  PagedChapterController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller._view = this;
  }

  @override
  void didUpdateWidget(PagedChapterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller._view == this) oldWidget.controller._view = null;
      widget.controller._view = this;
    }
  }

  @override
  void dispose() {
    if (_controller._view == this) _controller._view = null;
    _chapterDrag?.cancel();
    _animation.dispose();
    super.dispose();
  }

  void _onAnimate() => _controller.position = _animation.value;

  void _stopAnimation() {
    if (_animation.isAnimating) _animation.stop();
  }

  int get _lastPage => _controller.pageCount - 1;

  bool _hasChapter(int direction) {
    final target = widget.chapterIndex + direction;
    return widget.chapterController?.hasClients == true &&
        target >= 0 &&
        target < widget.chapterCount;
  }

  void _settleOn(int page) {
    final target = page.clamp(0, _lastPage).toDouble();
    if ((_controller.position - target).abs() < 0.001) {
      _controller.position = target;
      _didSettle();
      return;
    }
    _animation.value = _controller.position;
    final distance = (target - _controller.position).abs();
    final duration = Duration(
      milliseconds: (_slideDuration.inMilliseconds * math.min(1.0, distance + 0.35))
          .round(),
    );
    _animation
        .animateTo(target, duration: duration, curve: Curves.easeOutCubic)
        .whenCompleteOrCancel(() {
          if (mounted && !_animation.isAnimating) _didSettle();
        });
  }

  void _didSettle() {
    final settled = _controller.position.round().toDouble();
    if ((_controller.position - settled).abs() < 0.001) {
      _controller.position = settled;
      _controller._captureAnchorAfterFrame();
      widget.onSettled?.call();
    }
  }

  bool _turn(int direction) {
    if (!widget.enabled) return false;
    final current = _animation.isAnimating
        ? _animation.value.round() + direction
        : _controller.page + direction;
    if (current >= 0 && current <= _lastPage) {
      widget.beforeSlide?.call();
      _controller._userMoved();
      _settleOn(current);
      return true;
    }
    if (!_hasChapter(direction)) return false;
    widget.beforeSlide?.call();
    final pager = widget.chapterController!;
    pager.animateToPage(
      widget.chapterIndex + direction,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
    return true;
  }

  // Dragging.

  void _onDragStart(DragStartDetails details) {
    _swiping = true;
    _stopAnimation();
    _chapterDrag?.cancel();
    _chapterDrag = null;
    _controller._userMoved();
    widget.beforeSlide?.call();
    widget.onUserTurn?.call();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final dx = details.primaryDelta ?? details.delta.dx;
    if (_chapterDrag != null) {
      _updateChapterDrag(details, dx);
      return;
    }
    final next = _controller.position - dx / _width;
    if (next > _lastPage && _hasChapter(1)) {
      _controller.position = _lastPage.toDouble();
      _startChapterDrag(details, 1, (next - _lastPage) * -_width);
    } else if (next < 0 && _hasChapter(-1)) {
      _controller.position = 0;
      _startChapterDrag(details, -1, next * -_width);
    } else {
      _controller.position = _resist(next);
    }
  }

  /// Past the book's first or last page the page only gives a little.
  double _resist(double position) {
    if (position < 0) return position * 0.35;
    if (position > _lastPage) {
      return _lastPage + (position - _lastPage) * 0.35;
    }
    return position;
  }

  void _startChapterDrag(DragUpdateDetails details, int direction, double dx) {
    final position = widget.chapterController!.position;
    _chapterDragDirection = direction;
    _chapterDrag = position.drag(
      DragStartDetails(
        globalPosition: details.globalPosition,
        localPosition: details.localPosition,
        sourceTimeStamp: details.sourceTimeStamp,
      ),
      () => _chapterDrag = null,
    );
    _chapterDrag!.update(_withDelta(details, dx));
  }

  void _updateChapterDrag(DragUpdateDetails details, double dx) {
    final position = widget.chapterController!.position;
    final base = widget.chapterIndex * position.viewportDimension;
    final after = position.pixels - dx;
    final backInChapter = _chapterDragDirection > 0 ? after < base : after > base;
    if (!backInChapter) {
      _chapterDrag!.update(details);
      return;
    }
    // Dragged back over the chapter's edge: put the pager back exactly on
    // this chapter and let the rest of the movement turn this chapter's
    // pages again.
    final toBase = position.pixels - base;
    _chapterDrag!.update(_withDelta(details, toBase));
    _chapterDrag!.end(DragEndDetails(primaryVelocity: 0));
    _chapterDrag = null;
    _controller.position = _resist(_controller.position - (dx - toBase) / _width);
  }

  DragUpdateDetails _withDelta(DragUpdateDetails details, double dx) =>
      DragUpdateDetails(
        sourceTimeStamp: details.sourceTimeStamp,
        delta: Offset(dx, 0),
        primaryDelta: dx,
        globalPosition: details.globalPosition,
        localPosition: details.localPosition,
      );

  void _onDragEnd(DragEndDetails details) {
    _endSwipe();
    final velocity = details.primaryVelocity ?? 0;
    final drag = _chapterDrag;
    if (drag != null) {
      _chapterDrag = null;
      drag.end(details);
      return;
    }
    final position = _controller.position;
    int target;
    if (velocity.abs() >= _flingVelocity) {
      target = velocity < 0 ? position.floor() + 1 : position.ceil() - 1;
    } else {
      target = position.round();
    }
    _settleOn(target);
  }

  void _onDragCancel() {
    _endSwipe();
    _chapterDrag?.cancel();
    _chapterDrag = null;
    _settleOn(_controller.position.round());
  }

  void _endSwipe() {
    _swiping = false;
    // Drop the gesture handlers now if this chapter stopped being current
    // during the swipe.
    if (!widget.enabled && mounted) setState(() {});
  }

  // Taps.

  void _onTapUp(TapUpDetails details) {
    if (widget.onTapWithSelection?.call() == true) return;
    final x = details.localPosition.dx / _width;
    if (x < _edgeTapZone) {
      if (_turn(-1)) widget.onUserTurn?.call();
    } else if (x > 1 - _edgeTapZone) {
      if (_turn(1)) widget.onUserTurn?.call();
    } else {
      widget.onCenterTap?.call();
    }
  }

  // Mouse wheel and trackpad.

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      final scroll = event as PointerScrollEvent;
      final delta = scroll.scrollDelta.dy.abs() >= scroll.scrollDelta.dx.abs()
          ? scroll.scrollDelta.dy
          : scroll.scrollDelta.dx;
      if (delta == 0) return;
      // One notch, one page: a wheel sends a burst of events per notch.
      final last = _lastWheelTurn;
      if (last != null &&
          scroll.timeStamp - last < const Duration(milliseconds: 280)) {
        return;
      }
      _lastWheelTurn = scroll.timeStamp;
      if (_turn(delta > 0 ? 1 : -1)) widget.onUserTurn?.call();
    });
  }

  void _onPanZoomStart(PointerPanZoomStartEvent event) {
    _trackpadPan = 0;
    _trackpadTurned = false;
  }

  /// Two-finger vertical swipes on a trackpad turn a page; horizontal ones
  /// are drags (the page follows the fingers).
  void _onPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    if (_trackpadTurned) return;
    if (event.pan.dx.abs() > event.pan.dy.abs()) return;
    _trackpadPan = event.pan.dy;
    if (_trackpadPan.abs() > 70) {
      _trackpadTurned = true;
      if (_turn(_trackpadPan < 0 ? 1 : -1)) widget.onUserTurn?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final touchLike = {
      PointerDeviceKind.touch,
      PointerDeviceKind.stylus,
      PointerDeviceKind.invertedStylus,
      PointerDeviceKind.unknown,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        _width = math.max(constraints.maxWidth, 1);
        return Listener(
          onPointerSignal: widget.enabled ? _onPointerSignal : null,
          onPointerPanZoomStart: widget.enabled ? _onPanZoomStart : null,
          onPointerPanZoomUpdate: widget.enabled ? _onPanZoomUpdate : null,
          child: RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: widget.enabled || _swiping
                ? {
                    HorizontalDragGestureRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                          HorizontalDragGestureRecognizer
                        >(
                          () => HorizontalDragGestureRecognizer(
                            debugOwner: this,
                            // Mouse drags select text instead.
                            supportedDevices: {
                              ...touchLike,
                              PointerDeviceKind.trackpad,
                            },
                          ),
                          (instance) => instance
                            ..onStart = _onDragStart
                            ..onUpdate = _onDragUpdate
                            ..onEnd = _onDragEnd
                            ..onCancel = _onDragCancel,
                        ),
                    TapGestureRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                          TapGestureRecognizer
                        >(
                          () => TapGestureRecognizer(
                            debugOwner: this,
                            // A click stays a click (selection, links); the
                            // desktop turns pages with keys and the gutters.
                            supportedDevices: touchLike,
                          ),
                          (instance) => instance..onTapUp = _onTapUp,
                        ),
                  }
                : const {},
            child: _PagedChapterLayout(
              controller: widget.controller,
              padding: widget.padding,
              onPaginated: widget.onPaginated,
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

class _PagedChapterLayout extends SingleChildRenderObjectWidget {
  const _PagedChapterLayout({
    required this.controller,
    required this.padding,
    required this.onPaginated,
    required super.child,
  });

  final PagedChapterController controller;
  final EdgeInsets padding;
  final VoidCallback? onPaginated;

  @override
  _RenderPagedChapter createRenderObject(BuildContext context) =>
      _RenderPagedChapter(
        controller: controller,
        padding: padding,
        onPaginated: onPaginated,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPagedChapter renderObject,
  ) {
    renderObject
      ..controller = controller
      ..padding = padding
      ..onPaginated = onPaginated;
  }
}

/// Lays the chapter out once at page width, works out where pages start,
/// and paints the page on screen: two windows into the same layout while
/// a page slides. Hit testing and transforms go to the page on screen, so
/// selection, links and note markers work as in one long column.
class _RenderPagedChapter extends RenderBox
    with RenderObjectWithChildMixin<RenderBox> {
  _RenderPagedChapter({
    required PagedChapterController controller,
    required EdgeInsets padding,
    this.onPaginated,
  }) : _controller = controller,
       _padding = padding;

  PagedChapterController _controller;
  PagedChapterController get controller => _controller;
  set controller(PagedChapterController value) {
    if (value == _controller) return;
    if (attached) {
      _controller.removeListener(markNeedsPaint);
      if (_controller._render == this) _controller._render = null;
      value.addListener(markNeedsPaint);
      value._render = this;
    }
    _controller = value;
    markNeedsLayout();
  }

  EdgeInsets _padding;
  set padding(EdgeInsets value) {
    if (value == _padding) return;
    _padding = value;
    markNeedsLayout();
  }

  VoidCallback? onPaginated;

  List<_Line> _lines = const [];
  final _clips = [LayerHandle<ClipRectLayer>(), LayerHandle<ClipRectLayer>()];

  double get _pageHeight => math.max(size.height - _padding.vertical, 1);

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _controller.addListener(markNeedsPaint);
    _controller._render = this;
  }

  @override
  void detach() {
    _controller.removeListener(markNeedsPaint);
    if (_controller._render == this) _controller._render = null;
    super.detach();
  }

  @override
  void dispose() {
    for (final clip in _clips) {
      clip.layer = null;
    }
    super.dispose();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void performLayout() {
    size = constraints.biggest;
    final child = this.child;
    if (child == null) {
      _controller._setFromLayout(
        ChapterPages.single(contentHeight: 0, pageHeight: _pageHeight),
        0,
      );
      return;
    }

    final previous = _controller._pages;
    final previousPage = _controller.page;

    child.layout(
      BoxConstraints.tightFor(
        width: math.max(size.width - _padding.horizontal, 0),
      ),
      parentUsesSize: true,
    );
    _lines = _collectLines(child);
    final pages = paginate(
      _lines,
      pageHeight: _pageHeight,
      contentHeight: child.size.height,
    );

    final int page;
    final pending = _controller._pendingProgress;
    if (pending != null) {
      page = pages.pageForProgress(pending);
      _controller._pendingProgress = null;
      if (pending >= 1) _controller._pinnedToEnd = true;
    } else if (_controller._pinnedToEnd) {
      page = pages.last;
    } else if (_controller._restoredProgress != null) {
      page = pages.pageForProgress(_controller._restoredProgress!);
    } else {
      final anchorY = _anchorY(_controller._anchor, child);
      if (anchorY != null) {
        page = pages.pageAt(anchorY + 1);
      } else if (previous != null && previous.contentHeight > 0) {
        final fraction =
            previous.starts[previousPage.clamp(0, previous.last)] /
            previous.contentHeight;
        page = pages.pageAt(fraction * pages.contentHeight + 1);
      } else {
        page = 0;
      }
    }

    final changed =
        previous == null ||
        previous.count != pages.count ||
        previous.contentHeight != pages.contentHeight ||
        previous.pageHeight != pages.pageHeight ||
        previousPage != page;
    _controller._setFromLayout(pages, page);
    if (changed) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!attached) return;
        _controller._captureAnchorAfterFrame();
        onPaginated?.call();
      });
    }
  }

  /// Every line of text and every picture, in content coordinates.
  ///
  /// flutter_html nests each block (paragraph, div, list item) as a widget
  /// inside its parent's text, so a paragraph's own line boxes skip those
  /// nested blocks and the lines inside them are collected instead.
  static List<_Line> _collectLines(RenderBox root) {
    final lines = <_Line>[];

    void visit(RenderObject node) {
      if (node is RenderParagraph) {
        _collectParagraph(node, root, lines, visit);
        return;
      }
      if (node is RenderImage && node.hasSize) {
        final rect = MatrixUtils.transformRect(
          node.getTransformTo(root),
          Offset.zero & node.size,
        );
        lines.add(_Line(rect.top, rect.bottom, null, Offset.zero));
      }
      node.visitChildren(visit);
    }

    visit(root);
    return lines;
  }

  static void _collectParagraph(
    RenderParagraph paragraph,
    RenderBox root,
    List<_Line> lines,
    void Function(RenderObject) visit,
  ) {
    final children = <RenderBox>[];
    paragraph.visitChildren((child) => children.add(child as RenderBox));

    // Text ranges of this paragraph, split around nested blocks.
    final ranges = <(int, int)>[];
    var offset = 0;
    var rangeStart = 0;
    var childIndex = 0;
    paragraph.text.visitChildren((span) {
      if (span is PlaceholderSpan) {
        if (childIndex < children.length &&
            _containsParagraph(children[childIndex])) {
          if (offset > rangeStart) ranges.add((rangeStart, offset));
          rangeStart = offset + 1;
          visit(children[childIndex]);
        }
        childIndex++;
        offset += 1;
      } else if (span is TextSpan) {
        offset += span.text?.length ?? 0;
      }
      return true;
    });
    if (offset > rangeStart) ranges.add((rangeStart, offset));
    if (ranges.isEmpty || !paragraph.hasSize) return;

    final transform = paragraph.getTransformTo(root);
    for (final (start, end) in ranges) {
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: end),
        // Each run's own glyph box: neighbouring lines never overlap, and a
        // run sharing a line with a nested block isn't stretched to the
        // block's height (as `max` would).
        boxHeightStyle: ui.BoxHeightStyle.tight,
      );
      for (final box in boxes) {
        final top = MatrixUtils.transformPoint(
          transform,
          Offset(box.left, box.top),
        ).dy;
        final bottom = MatrixUtils.transformPoint(
          transform,
          Offset(box.left, box.bottom),
        ).dy;
        lines.add(
          _Line(
            top,
            bottom,
            paragraph,
            Offset(box.left + 1, (box.top + box.bottom) / 2),
          ),
        );
      }
    }
  }

  static bool _containsParagraph(RenderObject node) {
    var found = false;
    void visit(RenderObject child) {
      if (found) return;
      if (child is RenderParagraph) {
        found = true;
        return;
      }
      child.visitChildren(visit);
    }

    visit(node);
    return found;
  }

  /// The first line on [page], for [PagedChapterController._anchor].
  _Anchor? _anchorFor(int page) {
    final pages = _controller._pages;
    if (pages == null || page > pages.last) return null;
    final top = pages.starts[page] - 0.5;
    _Line? first;
    for (final line in _lines) {
      if (line.paragraph == null || line.top < top) continue;
      if (first == null ||
          line.top < first.top ||
          (line.top == first.top &&
              line.localPoint.dx < first.localPoint.dx)) {
        first = line;
      }
    }
    final paragraph = first?.paragraph;
    if (first == null || paragraph == null || !paragraph.attached) return null;
    try {
      final position = paragraph.getPositionForOffset(first.localPoint);
      return _Anchor(paragraph, position.offset);
    } catch (_) {
      return null;
    }
  }

  /// Where [anchor]'s text is in the new layout, or null when its
  /// paragraph is gone (the chapter was rebuilt).
  double? _anchorY(_Anchor? anchor, RenderBox root) {
    if (anchor == null || !anchor.paragraph.attached) return null;
    RenderObject? node = anchor.paragraph;
    while (node != null && node != root) {
      node = node.parent;
    }
    if (node != root) return null;
    try {
      final caret = anchor.paragraph.getOffsetForCaret(
        TextPosition(offset: anchor.offset),
        Rect.zero,
      );
      return MatrixUtils.transformPoint(
        anchor.paragraph.getTransformTo(root),
        caret,
      ).dy;
    } catch (_) {
      return null;
    }
  }

  // Painting.

  /// Horizontal shift of [page] for the current slide position.
  double _dx(int page) => (page - _controller.position) * size.width;

  Rect _pageClip(ChapterPages pages, int page, double dx) {
    final visible = math.min(
      pages.endOf(page) - pages.starts[page],
      _pageHeight,
    );
    return Rect.fromLTWH(dx, _padding.top, size.width, visible);
  }

  Offset _childOffset(ChapterPages pages, int page, double dx) =>
      Offset(dx + _padding.left, _padding.top - pages.starts[page]);

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    final pages = _controller._pages;
    if (child == null || pages == null) return;

    final position = _controller.position;
    final first = position.floor();
    final sliding = (position - first) > 0.001;
    // The same layout can only be painted twice when it has no layers of
    // its own; otherwise show the nearer page alone during a slide.
    final pagesToPaint = !sliding
        ? [first]
        : child.needsCompositing
        ? [position.round()]
        : [first, first + 1];

    var slot = 0;
    for (final page in pagesToPaint) {
      if (page < 0 || page > pages.last) continue;
      final dx = _dx(page);
      final clip = _pageClip(pages, page, dx);
      _clips[slot].layer = context.pushClipRect(
        needsCompositing,
        offset,
        clip,
        (context, offset) => context.paintChild(
          child,
          offset + _childOffset(pages, page, dx),
        ),
        oldLayer: _clips[slot].layer,
      );
      slot++;
    }
    for (; slot < _clips.length; slot++) {
      _clips[slot].layer = null;
    }
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final pages = _controller._pages;
    if (pages == null) return;
    final page = _controller.page;
    final shift = _childOffset(pages, page, _dx(page));
    transform.translateByDouble(shift.dx, shift.dy, 0, 1);
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) {
    final pages = _controller._pages;
    if (pages == null) return null;
    final page = _controller.page;
    final dx = _dx(page);
    return _pageClip(pages, page, dx).shift(-_childOffset(pages, page, dx));
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    final pages = _controller._pages;
    if (child == null || pages == null) return false;
    final page = _controller.page;
    final dx = _dx(page);
    // Only what is visible can be hit: lines of the next page sit right
    // below this one in the layout.
    if (!_pageClip(pages, page, dx).contains(position)) return false;
    return result.addWithPaintOffset(
      offset: _childOffset(pages, page, dx),
      position: position,
      hitTest: (result, position) => child.hitTest(result, position: position),
    );
  }
}

/// The page-turn haptic tick used by keys and taps, kept here so every
/// way of turning feels the same.
void pageTurnFeedback() => HapticFeedback.selectionClick();
