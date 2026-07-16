import 'dart:async';

import 'package:flutter/material.dart';

enum EInkRefreshStyle {
  black('black'),
  white('white'),
  whiteThenBlack('whiteThenBlack');

  const EInkRefreshStyle(this.key);

  final String key;

  static EInkRefreshStyle fromKey(String? key) {
    return values.firstWhere(
      (style) => style.key == key,
      orElse: () => EInkRefreshStyle.black,
    );
  }
}

class EInkRefreshRequest {
  const EInkRefreshRequest({
    required this.id,
    required this.durationMilliseconds,
    required this.style,
  });

  final int id;
  final int durationMilliseconds;
  final EInkRefreshStyle style;
}

class EInkRefreshController extends ChangeNotifier {
  EInkRefreshRequest? _request;
  int _pageChangeCount = 0;
  int? _interval;

  EInkRefreshRequest? get request => _request;

  bool onPageChanged({
    required int interval,
    required int durationMilliseconds,
    required EInkRefreshStyle style,
  }) {
    final normalizedInterval = interval.clamp(1, 10).toInt();
    if (_interval != normalizedInterval) {
      _interval = normalizedInterval;
      _pageChangeCount = 0;
    }

    final shouldRefresh = _pageChangeCount % normalizedInterval == 0;
    _pageChangeCount++;
    if (!shouldRefresh) {
      return false;
    }

    _request = EInkRefreshRequest(
      id: (_request?.id ?? 0) + 1,
      durationMilliseconds: durationMilliseconds.clamp(100, 1500).toInt(),
      style: style,
    );
    notifyListeners();
    return true;
  }

  void reset() {
    _pageChangeCount = 0;
    _interval = null;
  }
}

class EInkRefreshOverlay extends StatefulWidget {
  const EInkRefreshOverlay({super.key, required this.controller});

  final EInkRefreshController controller;

  @override
  State<EInkRefreshOverlay> createState() => _EInkRefreshOverlayState();
}

class _EInkRefreshOverlayState extends State<EInkRefreshOverlay> {
  Timer? _timer;
  Color? _color;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleRefreshRequest);
  }

  @override
  void didUpdateWidget(covariant EInkRefreshOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleRefreshRequest);
      widget.controller.addListener(_handleRefreshRequest);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleRefreshRequest);
    _timer?.cancel();
    super.dispose();
  }

  void _handleRefreshRequest() {
    final request = widget.controller.request;
    if (request == null) {
      return;
    }

    _timer?.cancel();
    final generation = ++_generation;
    final duration = request.durationMilliseconds;

    if (request.style == EInkRefreshStyle.whiteThenBlack) {
      final firstPhase = duration ~/ 2;
      _setColor(Colors.white);
      _timer = Timer(Duration(milliseconds: firstPhase), () {
        if (!mounted || generation != _generation) {
          return;
        }
        _setColor(Colors.black);
        _timer = Timer(Duration(milliseconds: duration - firstPhase), () {
          if (mounted && generation == _generation) {
            _setColor(null);
          }
        });
      });
      return;
    }

    _setColor(
      request.style == EInkRefreshStyle.black ? Colors.black : Colors.white,
    );
    _timer = Timer(Duration(milliseconds: duration), () {
      if (mounted && generation == _generation) {
        _setColor(null);
      }
    });
  }

  void _setColor(Color? color) {
    if (_color == color) {
      return;
    }
    setState(() {
      _color = color;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: _color == null
            ? const SizedBox.expand()
            : ColoredBox(color: _color!),
      ),
    );
  }
}
