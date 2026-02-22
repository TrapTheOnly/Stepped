import 'package:flutter/material.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  static const _mapHiddenMicrostates = <String>[
    'Andorra',
    'Liechtenstein',
    'Monaco',
    'San Marino',
    'Vatican City',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: <Widget>[
            SearchBar(
              hintText: 'Search countries',
              leading: const Icon(Icons.search),
              onTap: () {},
              onChanged: (_) {},
            ),
            const SizedBox(height: 16),
            Text(
              'Microstates (search-only)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _mapHiddenMicrostates
                  .map((name) => Chip(label: Text(name)))
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}
