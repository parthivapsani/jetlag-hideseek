import 'package:flutter/material.dart';
import '../theme.dart';

enum SheetPosition { collapsed, half, full }

class JetlagBottomSheet extends StatefulWidget {
  final Widget child;
  final SheetPosition initialPosition;
  final ValueChanged<SheetPosition>? onPositionChanged;

  const JetlagBottomSheet({
    super.key,
    required this.child,
    this.initialPosition = SheetPosition.collapsed,
    this.onPositionChanged,
  });

  @override
  State<JetlagBottomSheet> createState() => _JetlagBottomSheetState();
}

class _JetlagBottomSheetState extends State<JetlagBottomSheet> {
  late SheetPosition _position;

  double _fractionForPosition(SheetPosition pos) {
    switch (pos) {
      case SheetPosition.collapsed:
        return 0.0;
      case SheetPosition.half:
        return 0.45;
      case SheetPosition.full:
        return 0.9;
    }
  }

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
  }

  void _onDragEnd(DraggableScrollableNotification notification) {
    final extent = notification.extent;
    SheetPosition newPos;
    if (extent < 0.2) {
      newPos = SheetPosition.collapsed;
    } else if (extent < 0.65) {
      newPos = SheetPosition.half;
    } else {
      newPos = SheetPosition.full;
    }
    if (newPos != _position) {
      setState(() => _position = newPos);
      widget.onPositionChanged?.call(newPos);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: _fractionForPosition(_position),
      minChildSize: 0.0,
      maxChildSize: 0.9,
      snap: true,
      snapSizes: const [0.0, 0.45, 0.9],
      builder: (context, scrollController) {
        return NotificationListener<DraggableScrollableNotification>(
          onNotification: (n) { _onDragEnd(n); return true; },
          child: Container(
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              border: Border(top: BorderSide(color: context.border)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
