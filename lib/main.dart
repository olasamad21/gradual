import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO(samad): Configure Firebase options using flutterfire CLI and pass
  // DefaultFirebaseOptions.currentPlatform to initializeApp when available.
  await Firebase.initializeApp();

  runApp(
    const ProviderScope(
      child: GradualApp(),
    ),
  );
}
