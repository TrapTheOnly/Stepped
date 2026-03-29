import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/country_flag.dart';
import '../map/map_viewmodel.dart';
import 'search_models.dart';

Future<void> showCountrySearchActions({
  required BuildContext context,
  required WidgetRef ref,
  required CountrySearchEntry entry,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: CountryFlag(
                iso2: entry.iso2,
                width: 28,
                height: 20,
              ),
              title: Text(entry.name),
            ),
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('Show on Earth'),
              enabled: entry.focusableOnGlobe,
              onTap: !entry.focusableOnGlobe
                  ? null
                  : () {
                      Navigator.of(sheetContext).pop();
                      ref.read(globeFocusRequestProvider.notifier).state =
                          GlobeFocusRequest(
                        countryCode: entry.iso2,
                        token: DateTime.now().microsecondsSinceEpoch,
                      );
                      context.go('/');
                    },
            ),
            if (entry.latestTripId != null)
              ListTile(
                leading: const Icon(Icons.flight_takeoff),
                title: const Text('Open latest trip'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/trips/edit/${entry.latestTripId}');
                },
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Add trip'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push('/trips/add');
              },
            ),
          ],
        ),
      );
    },
  );
}
