import 'package:supabase/supabase.dart';
void main() async {
  final supabase = SupabaseClient(
    'https://zvnklviuqulxlcntqdwr.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp2bmtsdml1cXVseGxjbnRxZHdyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc0OTY1NzcsImV4cCI6MjEwMzA3MjU3N30.d1dgrQY9emkEMzOImjnBmne2xKc-0i3Av7EXW8AJG1A',
  );
  final res = await supabase.from('agreements').select().limit(1);
  print(res);
}
