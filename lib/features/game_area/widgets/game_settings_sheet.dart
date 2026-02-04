import 'package:flutter/material.dart';

import '../polygon_editor_screen.dart';

class GameSettingsSheet extends StatefulWidget {
  final String areaName;

  const GameSettingsSheet({super.key, required this.areaName});

  @override
  State<GameSettingsSheet> createState() => _GameSettingsSheetState();
}

class _GameSettingsSheetState extends State<GameSettingsSheet> {
  late final TextEditingController _nameController;
  Duration _hidingDuration = const Duration(hours: 1);
  double _zoneRadius = 804.672; // 0.5 miles in meters

  final _hidingOptions = [
    (const Duration(minutes: 30), '30 minutes'),
    (const Duration(hours: 1), '1 hour'),
    (const Duration(hours: 2, minutes: 30), '2.5 hours'),
    (const Duration(hours: 4), '4 hours'),
  ];

  final _zoneOptions = [
    (402.336, '0.25 miles'),
    (804.672, '0.5 miles'),
    (1609.344, '1 mile'),
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.areaName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Game Settings',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Area Name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Game Area Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // Hiding Duration
            Text(
              'Hiding Period',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _hidingOptions.map((option) {
                final isSelected = _hidingDuration == option.$1;
                return ChoiceChip(
                  label: Text(option.$2),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _hidingDuration = option.$1);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Zone Radius
            Text(
              'Hiding Zone Radius',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _zoneOptions.map((option) {
                final isSelected = _zoneRadius == option.$1;
                return ChoiceChip(
                  label: Text(option.$2),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _zoneRadius = option.$1);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // Create Button
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  GameSettings(
                    areaName: _nameController.text.trim().isEmpty
                        ? widget.areaName
                        : _nameController.text.trim(),
                    hidingDuration: _hidingDuration,
                    zoneRadius: _zoneRadius,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Create Game',
                style: TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
