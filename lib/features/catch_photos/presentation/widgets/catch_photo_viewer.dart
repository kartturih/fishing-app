import 'dart:io';

import 'package:flutter/material.dart';

/// Full-screen photo viewer, opened as a normal page (never a Bottom Sheet or
/// dialog). Displays already-resolved [files] — a mix of persistent Catch
/// photo files and pending picker files is expected — and does not modify
/// photo state. See TD-013.
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
  late final PageController _pageController = PageController(
    initialPage: widget.initialIndex,
  );
  late int _currentIndex = widget.initialIndex;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
        itemCount: widget.files.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
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
