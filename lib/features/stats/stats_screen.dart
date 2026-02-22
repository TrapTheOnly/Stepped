import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/trips_repository.dart';
import '../../data/repositories/visits_repository.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitedAsync = ref.watch(visitedCountProvider);
    final tripsAsync = ref.watch(tripsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Stats')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: ListTile(
              title: const Text('Countries visited'),
              trailing: Text('${visitedAsync.valueOrNull ?? 0}'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: const Text('Trips total'),
              trailing: Text('${tripsAsync.valueOrNull?.length ?? 0}'),
            ),
          ),
        ],
      ),
    );
  }
}
