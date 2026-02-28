import 'package:flutter/material.dart';

class WishlistManualEditBasicsCard extends StatelessWidget {
  const WishlistManualEditBasicsCard({
    super.key,
    required this.countryController,
    required this.summaryController,
    required this.durationDaysController,
    required this.durationReasonController,
    required this.durationSource,
    required this.onDurationSourceChanged,
    required this.onChanged,
  });

  final TextEditingController countryController;
  final TextEditingController summaryController;
  final TextEditingController durationDaysController;
  final TextEditingController durationReasonController;
  final String durationSource;
  final ValueChanged<String> onDurationSourceChanged;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Plan Basics',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: countryController,
              decoration: const InputDecoration(
                labelText: 'Country',
                border: OutlineInputBorder(),
              ),
              onChanged: onChanged,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: summaryController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Summary',
                border: OutlineInputBorder(),
              ),
              onChanged: onChanged,
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: durationDaysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Duration days',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: onChanged,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: durationSource,
                    decoration: const InputDecoration(
                      labelText: 'Duration source',
                      border: OutlineInputBorder(),
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: 'ai_recommended',
                        child: Text('AI recommended'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'user_selected',
                        child: Text('User selected'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        onDurationSourceChanged(value);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: durationReasonController,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Duration reason',
                border: OutlineInputBorder(),
              ),
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
