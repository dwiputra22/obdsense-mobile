import 'package:flutter/material.dart' hide Text;
import '../core/i18n/tr_text.dart';

import '../core/motion/motion.dart';
import '../core/theme/app_colors.dart';
import 'glass_card.dart';
import 'ui_kit.dart';

/// Kerangka standar sub-halaman.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.trailing,
    this.bottom,
    this.padding = const EdgeInsets.fromLTRB(20, 10, 20, 28),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;

  /// Widget tetap di bawah layar.
  final Widget? bottom;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: bottom,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: padding,
          children: [
            Reveal(
              index: 0,
              child: AppPageHeader(title: title, subtitle: subtitle, trailing: trailing),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Header sub-halaman (tombol kembali bulat + judul + aksi). Dipakai AppPage
/// dan halaman yang butuh layout sendiri (mis. peta).
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({super.key, required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          if (canPop) ...[
            RoundIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: 'Kembali',
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.6, height: 1.1),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.palette.muted, fontSize: 12.5, fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

/// Kartu pemberitahuan / keadaan kosong: ikon berwarna + teks.
class NoticeCard extends StatelessWidget {
  const NoticeCard({super.key, required this.icon, required this.text, this.color, this.title});

  final IconData icon;
  final String text;
  final String? title;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final c = color ?? palette.muted;
    return GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBubble(icon: icon, color: c),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(title!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 3),
                ],
                Text(text, style: TextStyle(color: palette.muted, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Blok loading di tengah halaman.
class LoadingBlock extends StatelessWidget {
  const LoadingBlock({super.key, this.label = 'Memuat…'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const SizedBox(width: 34, height: 34, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.cyan)),
          const SizedBox(height: 14),
          Text(label, style: TextStyle(color: context.palette.muted, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}