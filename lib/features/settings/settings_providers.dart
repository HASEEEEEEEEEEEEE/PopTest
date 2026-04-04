import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Maximum number of new cards per study session (default 20).
final newLimitProvider = StateProvider<int>((ref) => 20);
