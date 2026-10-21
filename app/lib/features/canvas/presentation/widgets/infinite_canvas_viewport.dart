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

  const InfiniteCanvasViewport({
    super.key,
    required this.controller,
    required this.child,
    this.navigationEnabled = true,
    this.onNavigationEnd,
  });

  @override
  State<InfiniteCanvasViewport> createState() => _InfiniteCanvasViewportState();
}

class _InfiniteCanvasViewportState extends State<InfiniteCanvasViewport> {
  Offset _anchor = Offset.zero;
  double _startScale = 1;

  void _move(Offset screenAnchor, Offset worldAnchor, double scale) {
    final zoom = scale.clamp(0.1, 5.0);
    final translation = screenAnchor - worldAnchor * zoom;
    widget.controller.value = Matrix4.identity()
      ..setEntry(0, 0, zoom)
      ..setEntry(1, 1, zoom)
      ..setEntry(0, 3, translation.dx)
      ..setEntry(1, 3, translation.dy);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerSignal: (event) {
      if (!widget.navigationEnabled || event is! PointerScrollEvent) return;
      GestureBinding.instance.pointerSignalResolver.register(event, (event) {
        final scroll = event as PointerScrollEvent;
        final matrix = widget.controller.value;
        if (HardwareKeyboard.instance.isControlPressed) {
          _move(
            scroll.localPosition,
            widget.controller.toScene(scroll.localPosition),
            matrix.entry(0, 0) * (scroll.scrollDelta.dy < 0 ? 1.15 : 1 / 1.15),
          );
        } else {
          widget.controller.value = matrix.clone()
            ..setEntry(0, 3, matrix.entry(0, 3) - scroll.scrollDelta.dx)
            ..setEntry(1, 3, matrix.entry(1, 3) - scroll.scrollDelta.dy);
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
          _move(details.localFocalPoint, _anchor, _startScale * details.scale);
        }
      },
      onScaleEnd: (_) => widget.onNavigationEnd?.call(),
      child: ClipRect(child: widget.child),
    ),
  );
}
