import 'package:supabase_flutter/supabase_flutter.dart';

/// Shorthand used throughout the services layer instead of importing
/// supabase_flutter everywhere and calling Supabase.instance.client.
SupabaseClient get supabase => Supabase.instance.client;
