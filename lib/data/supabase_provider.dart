import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase client toàn cục (đã khởi tạo trong main.dart).
final supabaseProvider =
    Provider<SupabaseClient>((ref) => Supabase.instance.client);
