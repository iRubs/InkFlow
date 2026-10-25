import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Camera over an unbounded world. Only the viewport is laid out and painted;
/// scene coordinates never depend on a giant, finite widget or image surface.
class InfiniteCanvasViewport extends StatefulWidget {
  final TransformationController controller;
  final bool navigationEnabled;
  final Widget child;
  final VoidCallback? onNavigationEnd;

  /// Null preserves the legacy free canvas. Otherwise paper grows only down.
  final double? pageWidth;
  final double? pageHeight;

  const InfiniteCanvasViewport({
    super.key,
    required this.controller,
    required this.child,
    this.navigationEnabled = true,
    this.onNavigationEnd,
    this.pageWidth,
    this.pageHeight,
  });

  @override
  State<InfiniteCanvasViewport> createState() => _InfiniteCanvasViewportState();
}

class _InfiniteCanvasViewportState extends State<InfiniteCanvasViewport> {
  Offset _anchor = Offset.zero;
  double _startScale = 1;
  Size _size = Size.zero;

  Matrix4 _constrain(Matrix4 matrix) {
    final width = widget.pageWidth;
    if (width == null) return matrix;
    final scale = matrix.entry(0, 0);
    final paperWidth = width * scale;
    final x = paperWidth <= _size.width - 24
        ? (_size.width - paperWidth) / 2
        : matrix.entry(0, 3).clamp(_size.width - 12 - paperWidth, 12.0);
    final height = widget.pageHeight;
    final y = height == null
        ? matrix.entry(1, 3).clamp(-double.maxFinite, 12.0)
        : height * scale <= _size.height - 24
        ? (_size.height - height * scale) / 2
        : matrix.entry(1, 3).clamp(_size.height - 12 - height * scale, 12.0);
    return matrix
      ..setEntry(0, 3, x)
      ..setEntry(1, 3, y);
  }

  void _move(Offset screenAnchor, Offset worldAnchor, double scale) {
    var minimum = widget.pageWidth == null
        ? 0.1
        : ((_size.width - 24) / widget.pageWidth!).clamp(0.1, 5.0);
    if (widget.pageHeight != null && widget.pageWidth != null) {
      final fitWidth = (_size.width - 40) / widget.pageWidth!;
      final fitHeight = (_size.height - 40) / widget.pageHeight!;
      minimum = (fitWidth < fitHeight ? fitWidth : fitHeight).clamp(0.1, 5.0);
    }
    final zoom = scale.clamp(minimum, 5.0);
    final translation = screenAnchor - worldAnchor * zoom;
    widget.controller.value = _constrain(
      Matrix4.identity()
        ..setEntry(0, 0, zoom)
        ..setEntry(1, 1, zoom)
        ..setEntry(0, 3, translation.dx)
        ..setEntry(1, 3, translation.dy),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _size = constraints.biggest;
      return Listener(
        onPointerSignal: (event) {
          if (!widget.navigationEnabled || event is! PointerScrollEvent) return;
          GestureBinding.instance.pointerSignalResolver.register(event, (
            event,
          ) {
            final scroll = event as PointerScrollEvent;
            final matrix = widget.controller.value;
            if (HardwareKeyboard.instance.isControlPressed) {
              _move(
                scroll.localPosition,
                widget.controller.toScene(scroll.localPosition),
                matrix.entry(0, 0) *
                    (scroll.scrollDelta.dy < 0 ? 1.15 : 1 / 1.15),
              );
            } else {
              widget.controller.value = _constrain(
                matrix.clone()
                  ..setEntry(0, 3, matrix.entry(0, 3) - scroll.scrollDelta.dx)
                  ..setEntry(1, 3, matrix.entry(1, 3) - scroll.scrollDelta.dy),
              );
            }
            widget.onNavigationEnd?.call();
          });
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          supportedDevices: const {
            PointerDeviceKind.touch,
            PointerDeviceKind.trackpad,
          },
          onScaleStart: (details) {
            _anchor = widget.controller.toScene(details.localFocalPoint);
            _startScale = widget.controller.value.entry(0, 0);
          },
          onScaleUpdate: (details) {
            if (widget.navigationEnabled) {
              _move(
                details.localFocalPoint,
                _anchor,
                _startScale * details.scale,
              );
            }
          },
          onScaleEnd: (_) => widget.onNavigationEnd?.call(),
          child: ClipRect(child: widget.child),
        ),
      );
    },
  );
}
