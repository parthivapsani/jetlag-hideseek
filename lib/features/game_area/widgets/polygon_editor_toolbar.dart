import 'package:flutter/material.dart';

import '../polygon_editor_screen.dart';

class PolygonEditorToolbar extends StatelessWidget {
  final EditorMode mode;
  final ValueChanged<EditorMode> onModeChanged;
  final VoidCallback? onUndo;
  final VoidCallback? onClear;

  const PolygonEditorToolbar({
    super.key,
    required this.mode,
    required this.onModeChanged,
    this.onUndo,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToolButton(
              icon: Icons.edit,
              tooltip: 'Add points',
              isSelected: mode == EditorMode.addVertex,
              onTap: () => onModeChanged(
                mode == EditorMode.addVertex ? EditorMode.view : EditorMode.addVertex,
              ),
            ),
            _ToolButton(
              icon: Icons.open_with,
              tooltip: 'Move vertices',
              isSelected: mode == EditorMode.moveVertex,
              onTap: () => onModeChanged(
                mode == EditorMode.moveVertex ? EditorMode.view : EditorMode.moveVertex,
              ),
            ),
            _ToolButton(
              icon: Icons.remove_circle_outline,
              tooltip: 'Delete vertices',
              isSelected: mode == EditorMode.deleteVertex,
              onTap: () => onModeChanged(
                mode == EditorMode.deleteVertex ? EditorMode.view : EditorMode.deleteVertex,
              ),
            ),
            const Divider(height: 8),
            _ToolButton(
              icon: Icons.block,
              tooltip: 'Add exclusion zone',
              isSelected: mode == EditorMode.exclusion,
              color: Colors.red,
              onTap: () => onModeChanged(
                mode == EditorMode.exclusion ? EditorMode.view : EditorMode.exclusion,
              ),
            ),
            const Divider(height: 8),
            _ToolButton(
              icon: Icons.undo,
              tooltip: 'Undo',
              isEnabled: onUndo != null,
              onTap: onUndo,
            ),
            _ToolButton(
              icon: Icons.delete_outline,
              tooltip: 'Clear all',
              isEnabled: onClear != null,
              onTap: onClear,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isSelected;
  final bool isEnabled;
  final Color? color;
  final VoidCallback? onTap;

  const _ToolButton({
    required this.icon,
    required this.tooltip,
    this.isSelected = false,
    this.isEnabled = true,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isSelected
            ? Theme.of(context).colorScheme.primaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              color: isEnabled
                  ? (color ?? (isSelected
                      ? Theme.of(context).colorScheme.primary
                      : null))
                  : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}
