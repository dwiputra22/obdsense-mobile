import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLang { id, en }

class AppLanguage extends ChangeNotifier {
  AppLanguage._();

  static final AppLanguage instance = AppLanguage._();
  static AppLang current = AppLang.id;

  static const String _prefsKey = 'app_language';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(_prefsKey);
      if (v == 'en') {
        current = AppLang.en;
      } else if (v == 'id') {
        current = AppLang.id;
      }
    } catch (_) {
      // Pakai bawaan (Indonesia) bila pengaturan tidak terbaca.
    }
    notifyListeners();
  }

  Future<void> set(AppLang lang) async {
    if (current == lang) return;
    current = lang;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, lang.name);
    } catch (_) {}
  }
}

class AppLocaleScope extends InheritedWidget {
  const AppLocaleScope({super.key, required this.lang, required super.child});

  final AppLang lang;

  static AppLang of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLocaleScope>()?.lang ?? AppLanguage.current;

  @override
  bool updateShouldNotify(AppLocaleScope oldWidget) => oldWidget.lang != lang;
}