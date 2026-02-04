import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/services/travel_estimator.dart';
import '../../../app/theme.dart';

class TravelRadiusOverlay extends ConsumerStatefulWidget {
  final LatLng? lastKnownLocation;
  final DateTime? lastKnownTime;
  final Function(Set<Polygon>) onPolygonsChanged;

  const TravelRadiusOverlay({
    super.key,
    this.lastKnownLocation,
    this.lastKnownTime,
    required this.onPolygonsChanged,
  });

  @override
  ConsumerState<TravelRadiusOverlay> createState() => _TravelRadiusOverlayState();
}

class _TravelRadiusOverlayState extends ConsumerState<TravelRadiusOverlay> {
  bool _isEnabled = false;
  TravelBoundaryType _selectedType = TravelBoundaryType.likely;
  bool _showTimedRings = false;
  DateTime? _customStartTime;
  Duration? _customDuration;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ExpansionTile(
        leading: Icon(
          Icons.radar,
          color: _isEnabled ? JetLagTheme.accentOrange : null,
        ),
        title: const Text('Travel Radius Estimator'),
        subtitle: _isEnabled
            ? Text(_getEstimateDescription())
            : const Text('Estimate how far the hider could have gone'),
        initiallyExpanded: _isEnabled,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Enable toggle
                SwitchListTile(
                  title: const Text('Show travel radius'),
                  subtitle: const Text('Visualize possible travel distance'),
                  value: _isEnabled,
                  onChanged: (value) {
                    setState(() => _isEnabled = value);
                    _updatePolygons();
                  },
                ),

                if (_isEnabled) ...[
                  const Divider(),

                  // Travel mode selection
                  const Text(
                    'Travel Mode',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: TravelBoundaryType.values.map((type) {
                      return ChoiceChip(
                        label: Text(_getTypeLabel(type)),
                        selected: _selectedType == type,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedType = type);
                            _updatePolygons();
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Time settings
                  const Text(
                    'Time Since Last Known Position',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  if (widget.lastKnownTime != null) ...[
                    _buildTimeOption(
                      'Since last known (${_formatTimeSince(widget.lastKnownTime!)})',
                      _customStartTime == null,
                      () {
                        setState(() => _customStartTime = null);
                        _updatePolygons();
                      },
                    ),
                  ],

                  _buildTimeOption(
                    'Custom duration',
                    _customDuration != null,
                    () => _showDurationPicker(),
                  ),

                  if (_customDuration != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 32, top: 4),
                      child: Text(
                        _formatDuration(_customDuration!),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Show time rings option
                  SwitchListTile(
                    title: const Text('Show time rings'),
                    subtitle: const Text('Display rings at 15-minute intervals'),
                    value: _showTimedRings,
                    onChanged: (value) {
                      setState(() => _showTimedRings = value);
                      _updatePolygons();
                    },
                  ),

                  const Divider(),

                  // Distance estimate display
                  _buildDistanceEstimate(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeOption(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? Theme.of(context).colorScheme.primary : null,
            ),
            const SizedBox(width: 12),
            Text(label),
          ],
        ),
      ),
    );
  }

  Widget _buildDistanceEstimate() {
    final duration = _getEffectiveDuration();
    if (duration == null) return const SizedBox.shrink();

    final estimate = TravelEstimator.estimateTravelRadius(duration: duration);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estimated travel distance (${_formatDuration(duration)})',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildEstimateRow(
            'Walking only',
            estimate.conservativeFormatted,
            Colors.green,
          ),
          _buildEstimateRow(
            'With jogging',
            estimate.likelyFormatted,
            Colors.orange,
          ),
          _buildEstimateRow(
            'With running',
            estimate.maximumFormatted,
            Colors.red,
          ),
          if (estimate.withTransitFormatted != null)
            _buildEstimateRow(
              'With transit',
              estimate.withTransitFormatted!,
              Colors.purple,
            ),
        ],
      ),
    );
  }

  Widget _buildEstimateRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color.withOpacity(0.3),
              border: Border.all(color: color, width: 2),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showDurationPicker() async {
    final result = await showDialog<Duration>(
      context: context,
      builder: (context) => _DurationPickerDialog(
        initialDuration: _customDuration ?? const Duration(hours: 1),
      ),
    );

    if (result != null) {
      setState(() {
        _customDuration = result;
        _customStartTime = DateTime.now(); // Mark as custom
      });
      _updatePolygons();
    }
  }

  Duration? _getEffectiveDuration() {
    if (_customDuration != null) return _customDuration;
    if (widget.lastKnownTime != null) {
      return DateTime.now().difference(widget.lastKnownTime!);
    }
    return null;
  }

  void _updatePolygons() {
    if (!_isEnabled || widget.lastKnownLocation == null) {
      widget.onPolygonsChanged({});
      return;
    }

    final duration = _getEffectiveDuration();
    if (duration == null) {
      widget.onPolygonsChanged({});
      return;
    }

    final polygons = <Polygon>{};

    if (_showTimedRings) {
      // Show concentric time rings
      final timedBoundaries = TravelEstimator.generateTimedBoundaries(
        widget.lastKnownLocation!,
        maxDuration: duration,
        interval: const Duration(minutes: 15),
        type: _selectedType,
      );

      for (int i = 0; i < timedBoundaries.length; i++) {
        final boundary = timedBoundaries[i];
        final opacity = 0.1 + (i / timedBoundaries.length) * 0.2;
        polygons.add(Polygon(
          polygonId: PolygonId('travel_${boundary.duration.inMinutes}'),
          points: boundary.points,
          fillColor: _getTypeColor(_selectedType).withOpacity(opacity),
          strokeColor: _getTypeColor(_selectedType),
          strokeWidth: i == timedBoundaries.length - 1 ? 3 : 1,
        ));
      }
    } else {
      // Show single boundary for selected type
      final boundaries = TravelEstimator.generateTravelBoundaries(
        widget.lastKnownLocation!,
        duration,
      );

      final boundary = boundaries.firstWhere(
        (b) => b.type == _selectedType,
        orElse: () => boundaries.first,
      );

      polygons.add(Polygon(
        polygonId: PolygonId('travel_${_selectedType.name}'),
        points: boundary.points,
        fillColor: _getTypeColor(_selectedType).withOpacity(0.2),
        strokeColor: _getTypeColor(_selectedType),
        strokeWidth: 3,
      ));
    }

    widget.onPolygonsChanged(polygons);
  }

  Color _getTypeColor(TravelBoundaryType type) {
    return switch (type) {
      TravelBoundaryType.conservative => Colors.green,
      TravelBoundaryType.likely => Colors.orange,
      TravelBoundaryType.maximum => Colors.red,
      TravelBoundaryType.withTransit => Colors.purple,
    };
  }

  String _getTypeLabel(TravelBoundaryType type) {
    return switch (type) {
      TravelBoundaryType.conservative => 'Walking',
      TravelBoundaryType.likely => 'Mixed',
      TravelBoundaryType.maximum => 'Running',
      TravelBoundaryType.withTransit => 'Transit',
    };
  }

  String _getEstimateDescription() {
    final duration = _getEffectiveDuration();
    if (duration == null) return 'No time data';

    final estimate = TravelEstimator.estimateTravelRadius(duration: duration);
    final radius = switch (_selectedType) {
      TravelBoundaryType.conservative => estimate.conservativeFormatted,
      TravelBoundaryType.likely => estimate.likelyFormatted,
      TravelBoundaryType.maximum => estimate.maximumFormatted,
      TravelBoundaryType.withTransit =>
        estimate.withTransitFormatted ?? estimate.maximumFormatted,
    };

    return 'Up to $radius in ${_formatDuration(duration)}';
  }

  String _formatTimeSince(DateTime time) {
    final diff = DateTime.now().difference(time);
    return _formatDuration(diff);
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

class _DurationPickerDialog extends StatefulWidget {
  final Duration initialDuration;

  const _DurationPickerDialog({required this.initialDuration});

  @override
  State<_DurationPickerDialog> createState() => _DurationPickerDialogState();
}

class _DurationPickerDialogState extends State<_DurationPickerDialog> {
  late int _hours;
  late int _minutes;

  @override
  void initState() {
    super.initState();
    _hours = widget.initialDuration.inHours;
    _minutes = widget.initialDuration.inMinutes.remainder(60);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Duration'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Hours
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_up),
                    onPressed: () => setState(() => _hours = (_hours + 1).clamp(0, 12)),
                  ),
                  Text(
                    '$_hours',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const Text('hours'),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down),
                    onPressed: () => setState(() => _hours = (_hours - 1).clamp(0, 12)),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(':', style: TextStyle(fontSize: 32)),
              ),
              // Minutes
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_up),
                    onPressed: () => setState(() => _minutes = (_minutes + 15) % 60),
                  ),
                  Text(
                    _minutes.toString().padLeft(2, '0'),
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const Text('minutes'),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down),
                    onPressed: () => setState(() => _minutes = (_minutes - 15 + 60) % 60),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Quick presets
          Wrap(
            spacing: 8,
            children: [
              _PresetChip(label: '30m', onTap: () => _setPreset(0, 30)),
              _PresetChip(label: '1h', onTap: () => _setPreset(1, 0)),
              _PresetChip(label: '2h', onTap: () => _setPreset(2, 0)),
              _PresetChip(label: '4h', onTap: () => _setPreset(4, 0)),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, Duration(hours: _hours, minutes: _minutes));
          },
          child: const Text('Set'),
        ),
      ],
    );
  }

  void _setPreset(int hours, int minutes) {
    setState(() {
      _hours = hours;
      _minutes = minutes;
    });
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
    );
  }
}
