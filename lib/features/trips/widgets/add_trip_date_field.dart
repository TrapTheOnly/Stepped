import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AddTripDateField extends StatelessWidget {
  const AddTripDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM d, y');
    final borderColor = Theme.of(context).colorScheme.outlineVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                const Icon(Icons.calendar_month, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    value == null ? 'Not set' : formatter.format(value!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
