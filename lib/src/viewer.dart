import 'package:flutter/material.dart';

import 'document.dart';
import 'page.dart';
import 'page_picker.dart';
import 'tooltip.dart';

/// The location of the built-in page indicator.
enum IndicatorPosition { topLeft, topRight, bottomLeft, bottomRight }

/// A ready-to-use PDF viewer with lazy page rendering, zoom, and navigation.
class PDFViewer extends StatefulWidget {
  const PDFViewer({
    required this.document,
    super.key,
    this.scrollDirection,
    this.lazyLoad = true,
    this.indicatorText = Colors.white,
    this.indicatorBackground = Colors.black54,
    this.numberPickerConfirmWidget = const Text('OK'),
    this.showIndicator = true,
    this.showPicker = true,
    this.showNavigation = true,
    this.enableSwipeNavigation = true,
    this.tooltip = const PDFViewerTooltip(),
    this.navigationBuilder,
    this.controller,
    this.indicatorPosition = IndicatorPosition.topRight,
    this.zoomSteps,
    this.minScale,
    this.maxScale,
    this.panLimit,
    this.progressIndicator,
    this.pickerButtonColor,
    this.pickerIconColor,
    this.onPageChanged,
    this.backgroundColor,
    this.indicatorBuilder,
    this.onZoomChanged,
    this.resizeToAvoidBottomInset = true,
  });

  final PDFDocument document;
  final Color indicatorText;
  final Color indicatorBackground;
  final Color? pickerButtonColor;
  final Color? pickerIconColor;
  final IndicatorPosition indicatorPosition;
  final Widget numberPickerConfirmWidget;
  final bool showIndicator;
  final bool showPicker;
  final bool showNavigation;
  final PDFViewerTooltip tooltip;
  final bool enableSwipeNavigation;
  final Axis? scrollDirection;
  final bool lazyLoad;
  final PageController? controller;
  final int? zoomSteps;
  final double? minScale;
  final double? maxScale;
  final double? panLimit;
  final ValueChanged<int>? onPageChanged;
  final Color? backgroundColor;
  final ValueChanged<double>? onZoomChanged;
  final bool? resizeToAvoidBottomInset;

  final Widget Function(
    BuildContext,
    int? pageNumber,
    int? totalPages,
    void Function({int page}) jumpToPage,
    void Function({int? page}) animateToPage,
  )?
  navigationBuilder;

  final Widget? progressIndicator;

  final Widget Function(BuildContext, int? pageNumber, int? totalPages)?
  indicatorBuilder;

  @override
  State<PDFViewer> createState() => _PDFViewerState();
}

class _PDFViewerState extends State<PDFViewer> {
  late PageController _pageController;
  late bool _ownsPageController;
  late int _pageNumber;
  List<PDFPage?> _pages = <PDFPage?>[];
  bool _isLoading = true;
  bool _swipeEnabled = true;
  int _loadToken = 0;

  static const Duration _animationDuration = Duration(milliseconds: 200);
  static const Curve _animationCurve = Curves.easeIn;

  @override
  void initState() {
    super.initState();
    _setPageController(widget.controller);
    _resetPages();
    if (widget.lazyLoad) {
      _loadPage();
    } else {
      _preloadPages();
    }
  }

  @override
  void didUpdateWidget(PDFViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (_ownsPageController) _pageController.dispose();
      _setPageController(widget.controller);
    }
    if (oldWidget.document != widget.document ||
        oldWidget.lazyLoad != widget.lazyLoad) {
      _resetPages();
      if (widget.lazyLoad) {
        _loadPage();
      } else {
        _preloadPages();
      }
    }
  }

  void _setPageController(PageController? controller) {
    _ownsPageController = controller == null;
    _pageController = controller ?? PageController();
  }

  void _resetPages() {
    _loadToken++;
    _pages = List<PDFPage?>.filled(widget.document.count, null);
    _pageNumber =
        _pageController.initialPage.clamp(0, widget.document.count - 1) + 1;
    _isLoading = true;
  }

  @override
  void dispose() {
    _loadToken++;
    if (_ownsPageController) _pageController.dispose();
    super.dispose();
  }

  void _onZoomChanged(double scale) {
    widget.onZoomChanged?.call(scale);
    final bool swipeEnabled = scale == 1.0;
    if (_swipeEnabled != swipeEnabled && mounted) {
      setState(() => _swipeEnabled = swipeEnabled);
    }
  }

  Future<void> _preloadPages() async {
    final int token = _loadToken;
    for (int page = 1; page <= widget.document.count; page++) {
      final PDFPage loadedPage = await widget.document.get(
        page: page,
        onZoomChanged: _onZoomChanged,
        zoomSteps: widget.zoomSteps,
        minScale: widget.minScale,
        maxScale: widget.maxScale,
        panLimit: widget.panLimit,
      );
      if (!mounted || token != _loadToken) return;
      _pages[page - 1] = loadedPage;
      if (page == 1) setState(() {});
    }
    if (mounted && token == _loadToken) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPage() async {
    if (_pageNumber < 1 || _pageNumber > _pages.length) return;
    final int index = _pageNumber - 1;
    if (_pages[index] != null) {
      if (mounted && _isLoading) setState(() => _isLoading = false);
      return;
    }

    final int token = _loadToken;
    if (mounted && !_isLoading) setState(() => _isLoading = true);
    final PDFPage loadedPage = await widget.document.get(
      page: _pageNumber,
      onZoomChanged: _onZoomChanged,
      zoomSteps: widget.zoomSteps,
      minScale: widget.minScale,
      maxScale: widget.maxScale,
      panLimit: widget.panLimit,
    );
    if (!mounted || token != _loadToken) return;
    _pages[index] = loadedPage;
    setState(() => _isLoading = false);
  }

  Future<void> _animateToPage({int? page}) async {
    await _pageController.animateToPage(
      page ?? _pageNumber - 1,
      duration: _animationDuration,
      curve: _animationCurve,
    );
  }

  void _jumpToPage({int? page}) {
    _pageController.jumpToPage(page ?? _pageNumber - 1);
  }

  Widget _drawIndicator() {
    final Widget child = GestureDetector(
      onTap: widget.showPicker && widget.document.count > 1 ? _pickPage : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: widget.indicatorBackground,
        ),
        child: Text(
          '$_pageNumber/${widget.document.count}',
          style: TextStyle(
            color: widget.indicatorText,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );

    if (widget.indicatorBuilder != null) {
      return widget.indicatorBuilder!(
        context,
        _pageNumber,
        widget.document.count,
      );
    }

    return switch (widget.indicatorPosition) {
      IndicatorPosition.topLeft => Positioned(top: 20, left: 20, child: child),
      IndicatorPosition.topRight => Positioned(
        top: 20,
        right: 20,
        child: child,
      ),
      IndicatorPosition.bottomLeft => Positioned(
        bottom: 20,
        left: 20,
        child: child,
      ),
      IndicatorPosition.bottomRight => Positioned(
        bottom: 20,
        right: 20,
        child: child,
      ),
    };
  }

  Future<void> _pickPage() async {
    final int? page = await showDialog<int>(
      context: context,
      builder: (BuildContext context) => PagePicker(
        title: widget.tooltip.pick,
        maxValue: widget.document.count,
        initialValue: _pageNumber,
        numberPickerConfirmWidget: widget.numberPickerConfirmWidget,
      ),
    );
    if (!mounted || page == null) return;
    _pageNumber = page;
    _jumpToPage();
  }

  @override
  Widget build(BuildContext context) {
    final bool canNavigate = widget.document.count > 1;
    return Scaffold(
      resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
      backgroundColor: widget.backgroundColor,
      body: Stack(
        children: <Widget>[
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            scrollDirection: widget.scrollDirection ?? Axis.horizontal,
            physics:
                _swipeEnabled && widget.enableSwipeNavigation && !_isLoading
                ? null
                : const NeverScrollableScrollPhysics(),
            onPageChanged: (int page) {
              setState(() => _pageNumber = page + 1);
              _loadPage();
              widget.onPageChanged?.call(page);
            },
            itemBuilder: (BuildContext context, int index) {
              final PDFPage? page = _pages[index];
              return page ??
                  Center(
                    child:
                        widget.progressIndicator ??
                        const CircularProgressIndicator(),
                  );
            },
          ),
          if (widget.showIndicator && !_isLoading) _drawIndicator(),
        ],
      ),
      floatingActionButton: widget.showPicker && canNavigate
          ? FloatingActionButton(
              backgroundColor: widget.pickerButtonColor ?? Colors.blue,
              onPressed: _pickPage,
              tooltip: widget.tooltip.jump,
              child: Icon(
                Icons.view_carousel,
                color: widget.pickerIconColor ?? Colors.white,
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: widget.showNavigation && canNavigate
          ? widget.navigationBuilder?.call(
                  context,
                  _pageNumber,
                  widget.document.count,
                  _jumpToPage,
                  _animateToPage,
                ) ??
                _buildNavigationBar()
          : const SizedBox.shrink(),
    );
  }

  Widget _buildNavigationBar() {
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: IconButton(
              icon: const Icon(Icons.first_page),
              tooltip: widget.tooltip.first,
              onPressed: _pageNumber == 1 || _isLoading
                  ? null
                  : () {
                      _pageNumber = 1;
                      _jumpToPage();
                    },
            ),
          ),
          Expanded(
            child: IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: widget.tooltip.previous,
              onPressed: _pageNumber == 1 || _isLoading
                  ? null
                  : () {
                      _pageNumber--;
                      _animateToPage();
                    },
            ),
          ),
          if (widget.showPicker)
            const Expanded(child: SizedBox.shrink())
          else
            const SizedBox(width: 1),
          Expanded(
            child: IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: widget.tooltip.next,
              onPressed: _pageNumber == widget.document.count || _isLoading
                  ? null
                  : () {
                      _pageNumber++;
                      _animateToPage();
                    },
            ),
          ),
          Expanded(
            child: IconButton(
              icon: const Icon(Icons.last_page),
              tooltip: widget.tooltip.last,
              onPressed: _pageNumber == widget.document.count || _isLoading
                  ? null
                  : () {
                      _pageNumber = widget.document.count;
                      _jumpToPage();
                    },
            ),
          ),
        ],
      ),
    );
  }
}
