import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/services/fcm_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabaseAnonKey);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // FCM init runs after Firebase. Permission prompt shown to user here.
  // Token is saved to device_tokens only when a user is signed in.
  await FCMService.init();

  runApp(const ProviderScope(child: LeadlyApp()));
}
