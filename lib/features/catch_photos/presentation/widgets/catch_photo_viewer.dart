import 'dart:io';

import 'package:flutter/material.dart';

/// Full-screen photo viewer, opened as a normal page (never a Bottom Sheet or
/// dialog). Displays already-resolved [files] — a mix of persistent Catch
/// photo files and pending picker files is expected — and does not modify
/// photo state. See TD-013.
///
/// Each page is wrapped in an [InteractiveViewer] for pinch-to-zoom. A plain
/// [InteractiveViewer] nested in a [PageView] loses one-finger drags to the
/// ancestor [Scrollable] once zoomed in — Flutter's gesture arena resolves a
/// single-pointer horizontal drag in the [PageView]'s favor, so panning a
/// zoomed image would otherwise require a second finger. To fix this, the
/// [PageView]'s physics are switched to [NeverScrollableScrollPhysics] for as
/// long as the current page reports a zoom scale above 1, which stops the
/// [Scrollable] from claiming the pointer at all and leaves one-finger drags
/// entirely to the [InteractiveViewer].
///
/// True mid-gesture handoff back to the [PageView] (transferring the same
/// pointer to its drag recognizer once the pan hits a horizontal boundary)
/// is not something the gesture arena supports — once a recognizer wins a
/// pointer it keeps it for that whole gesture. Instead, boundary "handoff" is
/// approximated: [InteractiveViewer.onInteractionUpdate] compares the
/// horizontal translation before and after each update against the drag
/// delta that was applied. When the translation stops moving despite a
/// continued horizontal delta (i.e. the pan is clamped at its edge) the
/// clamped delta is accumulated, and once it crosses a small threshold the
/// viewer resets zoom and animates to the next/previous page itself.
class CatchPhotoViewer extends StatefulWidget {
  const CatchPhotoViewer({
    super.key,
    required this.files,
    this.initialIndex = 0,
  });

  final List<File> files;
  final int initialIndex;

  /// Pushes the viewer as a normal [MaterialPageRoute].
  static Future<void> open(
    BuildContext context, {
    required List<File> files,
    int initialIndex = 0,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            CatchPhotoViewer(files: files, initialIndex: initialIndex),
      ),
    );
  }

  @override
  State<CatchPhotoViewer> createState() => _CatchPhotoViewerState();
}

class _CatchPhotoViewerState extends State<CatchPhotoViewer> {
  /// Logical pixels of clamped (boundary) horizontal drag needed before the
  /// viewer treats it as intent to move to the next/previous photo.
  static const double _edgeHandoffThreshold = 48;

  static const double _zoomEpsilon = 1.01;

  late final PageController _pageController = PageController(
    initialPage: widget.initialIndex,
  );
  late int _currentIndex = widget.initialIndex;
  bool _isZoomed = false;

  final Map<int, TransformationController> _transformationControllers = {};

  double _horizontalOverdrag = 0;
  double? _lastTranslationX;

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _transformationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TransformationController _transformationControllerFor(int index) {
    return _transformationControllers.putIfAbsent(
      index,
      TransformationController.new,
    );
  }

  bool _isPageZoomed(int index) {
    final controller = _transformationControllers[index];
    if (controller == null) {
      return false;
    }
    return controller.value.getMaxScaleOnAxis() > _zoomEpsilon;
  }

  void _handleInteractionStart(int index, ScaleStartDetails details) {
    if (index != _currentIndex) {
      return;
    }
    _horizontalOverdrag = 0;
    _lastTranslationX = null;
  }

  void _handleInteractionUpdate(int index, ScaleUpdateDetails details) {
    if (index != _currentIndex || !_isZoomed) {
      return;
    }

    final translationX = _transformationControllerFor(
      index,
    ).value.getTranslation().x;
    final dx = details.focalPointDelta.dx;

    final lastTranslationX = _lastTranslationX;
    if (lastTranslationX != null &&
        dx.abs() > 0 &&
        (translationX - lastTranslationX).abs() < 0.5) {
      // The transformation didn't move even though the drag did: the pan is
      // clamped at a horizontal boundary and this delta is "overdrag".
      _horizontalOverdrag += dx;
    } else {
      _horizontalOverdrag = 0;
    }
    _lastTranslationX = translationX;

    if (_horizontalOverdrag <= -_edgeHandoffThreshold) {
      _horizontalOverdrag = 0;
      _goToNextPage();
    } else if (_horizontalOverdrag >= _edgeHandoffThreshold) {
      _horizontalOverdrag = 0;
      _goToPreviousPage();
    }
  }

  void _handleInteractionEnd(int index, ScaleEndDetails details) {
    if (index != _currentIndex) {
      return;
    }
    _horizontalOverdrag = 0;
    _lastTranslationX = null;

    final isZoomed = _isPageZoomed(index);
    if (isZoomed != _isZoomed) {
      setState(() => _isZoomed = isZoomed);
    }
  }

  void _goToNextPage() {
    if (_currentIndex >= widget.files.length - 1) {
      return;
    }
    _resetZoom(_currentIndex);
    _pageController.animateToPage(
      _currentIndex + 1,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _goToPreviousPage() {
    if (_currentIndex <= 0) {
      return;
    }
    _resetZoom(_currentIndex);
    _pageController.animateToPage(
      _currentIndex - 1,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _resetZoom(int index) {
    _transformationControllers[index]?.value = Matrix4.identity();
    if (index == _currentIndex && _isZoomed) {
      setState(() => _isZoomed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} / ${widget.files.length}'),
        leading: IconButton(
          key: const Key('catchPhotoViewerCloseButton'),
          icon: const Icon(Icons.close),
          tooltip: 'Sulje',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: PageView.builder(
        key: const Key('catchPhotoViewerPageView'),
        controller: _pageController,
        // While the current page is zoomed in, the PageView must not compete
        // with the InteractiveViewer for one-finger drags; see class doc.
        physics: _isZoomed
            ? const NeverScrollableScrollPhysics()
            : const PageScrollPhysics(),
        itemCount: widget.files.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
            _isZoomed = _isPageZoomed(index);
          });
        },
        itemBuilder: (context, index) {
          return InteractiveViewer(
            transformationController: _transformationControllerFor(index),
            minScale: 1,
            maxScale: 4,
            onInteractionStart: (details) =>
                _handleInteractionStart(index, details),
            onInteractionUpdate: (details) =>
                _handleInteractionUpdate(index, details),
            onInteractionEnd: (details) =>
                _handleInteractionEnd(index, details),
            child: Center(
              child: Image.file(
                widget.files[index],
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const _ViewerPlaceholder(),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ViewerPlaceholder extends StatelessWidget {
  const _ViewerPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
        SizedBox(height: 12),
        Text('Kuvaa ei voi näyttää', style: TextStyle(color: Colors.white54)),
      ],
    );
  }
}
