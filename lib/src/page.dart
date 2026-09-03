import 'dart:io';

import 'package:flutter/widgets.dart';

import 'zoomable_widget.dart';

/// A widget that displays one rendered PDF page.
class PDFPage extends StatefulWidget {
  const PDFPage(
    this.imgPath,
    this.num, {
    super.key,
    this.onZoomChanged,
    this.zoomSteps = 3,
    this.minScale = 1.0,
    this.maxScale = 5.0,
    this.panLimit = 1.0,
  });

  /// The path of the rendered page image.
  final String? imgPath;

  /// The one-based page number.
  final int num;
  final ValueChanged<double>? onZoomChanged;
  final int zoomSteps;
  final double minScale;
  final double maxScale;
  final double panLimit;

  @override
  State<PDFPage> createState() => _PDFPageState();
}

class _PDFPageState extends State<PDFPage> {
  ImageProvider<Object>? _provider;

  @override
  void initState() {
    super.initState();
    _updateProvider();
  }

  @override
  void didUpdateWidget(PDFPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imgPath != widget.imgPath) {
      _updateProvider();
    }
  }

  void _updateProvider() {
    _provider = widget.imgPath == null
        ? null
        : FileImage(File(widget.imgPath!));
  }

  @override
  Widget build(BuildContext context) {
    final ImageProvider<Object>? provider = _provider;
    if (provider == null) return const SizedBox.shrink();

    return ZoomableWidget(
      onZoomChanged: widget.onZoomChanged,
      zoomSteps: widget.zoomSteps,
      minScale: widget.minScale,
      panLimit: widget.panLimit,
      maxScale: widget.maxScale,
      child: Image(
        image: provider,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
