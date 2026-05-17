import 'package:flutter/material.dart';

import 'wishlist_editor_shell.dart';

class WishlistManualEditBasicsCard extends StatelessWidget {
  const WishlistManualEditBasicsCard({
    super.key,
    required this.countryController,
    required this.summaryController,
    required this.durationDaysController,
    required this.durationReasonController,
    required this.onChanged,
  });

  final TextEditingController countryController;
  final TextEditingController summaryController;
  final TextEditingController durationDaysController;
  final TextEditingController durationReasonController;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return WishlistEditorSectionCard(
      title: 'Overview',
      subtitle:
          'Set the destination, trip overview, and overall length before refining season notes and cities.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: countryController,
            decoration: const InputDecoration(
              labelText: 'Country',
              prefixIcon: Icon(Icons.public_outlined),
            ),
            onChanged: onChanged,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: summaryController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Overview',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.notes_rounded),
            ),
            onChanged: onChanged,
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: durationDaysController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duration days',
                    prefixIcon: Icon(Icons.schedule_outlined),
                  ),
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: durationReasonController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Why this length works',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.route_outlined),
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
