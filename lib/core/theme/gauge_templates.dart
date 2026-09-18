import 'package:flutter/material.dart';
import 'app_colors.dart';

enum GaugeStyle { needle, arcFill }

@immutable
class GaugeTemplate {
  final String name;
  final GaugeStyle style;
  final Color valueColorStart;
  final Color valueColorEnd;
  final Color needleColor;
  final Color hubCenterColor;
  final double trackWidthFactor; // proporsi dari lebar gauge
  final bool showTicks;
  final bool showTickLabels;

  const GaugeTemplate({
    required this.name,
    required this.style,
    required this.valueColorStart,
    required this.valueColorEnd,
    required this.needleColor,
    required this.hubCenterColor,
    this.trackWidthFactor = 0.09,
    this.showTicks = true,
    this.showTickLabels = true,
  });
}

class GaugeTemplates {
  static const neonArc = GaugeTemplate(
    name: 'Neon Arc',
    style: GaugeStyle.arcFill,
    valueColorStart: AppColors.cyan,
    valueColorEnd: AppColors.blue,
    needleColor: AppColors.cyan,
    hubCenterColor: AppColors.cyan,
    trackWidthFactor: 0.10,
  );

  static const classicAnalog = GaugeTemplate(
    name: 'Classic Analog',
    style: GaugeStyle.needle,
    valueColorStart: AppColors.orange,
    valueColorEnd: AppColors.red,
    needleColor: AppColors.red,
    hubCenterColor: Colors.white,
    trackWidthFactor: 0.07,
  );

  static const minimal = GaugeTemplate(
    name: 'Minimal',
    style: GaugeStyle.arcFill,
    valueColorStart: AppColors.purple,
    valueColorEnd: AppColors.cyan,
    needleColor: AppColors.purple,
    hubCenterColor: AppColors.purple,
    trackWidthFactor: 0.045,
    showTicks: false,
    showTickLabels: false,
  );

  static const all = [neonArc, classicAnalog, minimal];
}
