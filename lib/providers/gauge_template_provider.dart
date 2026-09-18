import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/gauge_templates.dart';

const _gaugeTemplateKey = 'gauge_template_name';

final gaugeTemplateProvider =
    StateNotifierProvider<GaugeTemplateController, GaugeTemplate>((ref) {
  return GaugeTemplateController();
});

class GaugeTemplateController extends StateNotifier<GaugeTemplate> {
  GaugeTemplateController() : super(GaugeTemplates.neonArc) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString(_gaugeTemplateKey);
    if (savedName == null) return;
    final match = GaugeTemplates.all.where((t) => t.name == savedName);
    if (match.isNotEmpty) state = match.first;
  }

  Future<void> setTemplate(GaugeTemplate template) async {
    state = template;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_gaugeTemplateKey, template.name);
  }
}
