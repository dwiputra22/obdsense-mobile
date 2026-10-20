import 'package:flutter_riverpod/legacy.dart';

final currentTabIndexProvider = StateProvider<int>((ref) => 0);

final splashDoneProvider = StateProvider<bool>((ref) => false);
