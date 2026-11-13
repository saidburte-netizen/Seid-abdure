import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const _supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SupabaseClient? client;
  final key = _supabasePublishableKey.isNotEmpty
      ? _supabasePublishableKey
      : _supabaseAnonKey;
  if (_supabaseUrl.isNotEmpty && key.isNotEmpty) {
    await Supabase.initialize(url: _supabaseUrl, publishableKey: key);
    client = Supabase.instance.client;
  }
  runApp(ProviderScope(child: BakeryApp(client: client)));
}
