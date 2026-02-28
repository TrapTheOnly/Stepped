class TripCountryOption {
  const TripCountryOption({
    required this.code,
    required this.name,
  });

  final String code;
  final String name;
}

const tripMicrostatesSearchOnly = <TripCountryOption>[
  TripCountryOption(code: 'AD', name: 'Andorra'),
  TripCountryOption(code: 'LI', name: 'Liechtenstein'),
  TripCountryOption(code: 'MC', name: 'Monaco'),
  TripCountryOption(code: 'SM', name: 'San Marino'),
  TripCountryOption(code: 'VA', name: 'Vatican City'),
];
