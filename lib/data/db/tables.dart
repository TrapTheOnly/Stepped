const countryVisitsTable = 'country_visits';
const tripsTable = 'trips';
const wishlistTable = 'wishlist_items';

const createCountryVisitsTable = '''
CREATE TABLE $countryVisitsTable (
  countryCode TEXT PRIMARY KEY,
  countryName TEXT NOT NULL,
  visitedAt INTEGER NOT NULL
)
''';

const createTripsTable = '''
CREATE TABLE $tripsTable (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  countryCode TEXT NOT NULL,
  countryName TEXT NOT NULL,
  startDate INTEGER NOT NULL,
  endDate INTEGER NOT NULL,
  cities TEXT NOT NULL,
  coverImageUri TEXT,
  notes TEXT
)
''';

const createWishlistTable = '''
CREATE TABLE $wishlistTable (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  countryName TEXT,
  countryCode TEXT,
  createdAt INTEGER NOT NULL,
  plannedStartDate INTEGER,
  plannedEndDate INTEGER,
  plannedCities TEXT,
  aiPlan TEXT
)
''';

const createTripsStartDateIndex = '''
CREATE INDEX idx_trips_start_date ON $tripsTable(startDate DESC)
''';

const createWishlistCreatedAtIndex = '''
CREATE INDEX idx_wishlist_created_at ON $wishlistTable(createdAt DESC)
''';
