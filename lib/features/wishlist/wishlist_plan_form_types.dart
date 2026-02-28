class WishlistCountryOption {
  const WishlistCountryOption({
    required this.code,
    required this.name,
  });

  final String code;
  final String name;
}

enum WishlistTimeInputMode {
  aiRecommended,
  preciseDates,
  monthAndDuration,
}
