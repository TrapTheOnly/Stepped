import 'package:flutter/material.dart';

import '../../../widgets/frosted_squircle.dart';

class MapSearchDock extends StatelessWidget {
  const MapSearchDock({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasQuery = controller.text.trim().isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: FrostedSquircle(
        radius: 30,
        blurSigma: 16,
        color: colorScheme.surface.withValues(alpha: 0.52),
        borderColor: colorScheme.outlineVariant.withValues(alpha: 0.12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.search_rounded,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search countries',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (hasQuery)
              IconButton(
                onPressed: onClear,
                tooltip: 'Clear search',
                icon: const Icon(Icons.close_rounded),
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
