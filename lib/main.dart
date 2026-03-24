import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/db/db_initializer_stub.dart'
    if (dart.library.ffi) 'data/db/db_initializer_ffi.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  initDatabaseFactoryForPlatform();
  await Firebase.initializeApp();
  runApp(const ProviderScope(child: SteppedAppBootstrap()));
}
