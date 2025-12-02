import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GuestModeNotifier extends StateNotifier<bool> {
  GuestModeNotifier() : super(false) {
    _loadGuestMode();
  }

  static const String _guestModeKey = 'guest_mode';

  Future<void> _loadGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_guestModeKey) ?? false;
  }

  Future<void> enableGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guestModeKey, true);
    state = true;
  }

  Future<void> disableGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guestModeKey, false);
    state = false;
  }
}

final guestModeProvider = StateNotifierProvider<GuestModeNotifier, bool>((ref) {
  return GuestModeNotifier();
});



