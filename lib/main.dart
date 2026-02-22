import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/db/db_initializer_stub.dart'
    if (dart.library.ffi) 'data/db/db_initializer_ffi.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initDatabaseFactoryForPlatform();
  runApp(const ProviderScope(child: SteppedAppBootstrap()));
}
