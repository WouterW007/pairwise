import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pairwise/features/auth/presentation/auth_page.dart';
import 'package:pairwise/features/home/presentation/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'http://127.0.0.1:54321',
    anonKey: 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH',
  );

  runApp(const ProviderScope(child: PairwiseApp()));
}

final supabase = Supabase.instance.client;

class PairwiseApp extends StatelessWidget {
  const PairwiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pairwise',
      theme: ThemeData.dark(),
      // We now use a StreamBuilder to listen to auth changes
      home: StreamBuilder<AuthState>(
        stream: supabase.auth.onAuthStateChange,
        builder: (context, snapshot) {
          // If the user is logged in, show the HomePage
          if (snapshot.hasData && snapshot.data!.session != null) {
            return const HomePage();
          }

          // Otherwise, show the SignUpPage
          return const SignUpPage();
        },
      ),
    );
  }
}
