import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static String url = dotenv.env['SUPABASE_URL']!;
  static String anonKey = dotenv.env['SUPABASE_ANON_KEY']!;
} 