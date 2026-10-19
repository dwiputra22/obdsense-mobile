import 'app_language.dart';
import 'translations_data.dart';

final RegExp _placeholder = RegExp(r'\{(\d+)\}');
final RegExp _hasLetter = RegExp(r'[A-Za-zÀ-ÿ]');

class _Pattern {
  _Pattern(this.regex, this.target, this.prefix);

  final RegExp regex;
  final String target;
  final String prefix;
}

List<_Pattern>? _enPatterns;
List<_Pattern>? _idPatterns;
final Map<String, String> _cacheEn = <String, String>{};
final Map<String, String> _cacheId = <String, String>{};

/// Mengubah kalimat bertemplate ("... {0} ... {1}") menjadi pola yang dapat
/// mencocokkan teks yang SUDAH terisi nilai saat runtime.
List<_Pattern> _build(Map<String, String> table) {
  final out = <_Pattern>[];
  table.forEach((src, dst) {
    if (!_placeholder.hasMatch(src)) return;
    final buf = StringBuffer('^');
    var last = 0;
    for (final m in _placeholder.allMatches(src)) {
      buf.write(RegExp.escape(src.substring(last, m.start)));
      buf.write('(.+?)');
      last = m.end;
    }
    buf.write(RegExp.escape(src.substring(last)));
    buf.write(r'$');
    out.add(_Pattern(RegExp(buf.toString(), dotAll: true), dst, src.substring(0, src.indexOf('{'))));
  });
  out.sort((a, b) => b.regex.pattern.length.compareTo(a.regex.pattern.length));
  return out;
}

String _build2(_Pattern p, RegExpMatch m, Map<String, String> table) {
  return p.target.replaceAllMapped(_placeholder, (ph) {
    final idx = int.parse(ph.group(1)!) + 1;
    final value = idx <= m.groupCount ? (m.group(idx) ?? '') : '';
    return table[value] ?? value;
  });
}

String tr(String s) {
  if (s.isEmpty) return s;
  final en = AppLanguage.current == AppLang.en;
  final table = en ? enOfId : idOfEn;

  final direct = table[s];
  if (direct != null) return direct;
  if (!_hasLetter.hasMatch(s)) return s;

  final cache = en ? _cacheEn : _cacheId;
  final cached = cache[s];
  if (cached != null) return cached;

  final patterns = en ? (_enPatterns ??= _build(enOfId)) : (_idPatterns ??= _build(idOfEn));
  var result = s;
  for (final p in patterns) {
    if (p.prefix.isNotEmpty && !s.startsWith(p.prefix)) continue;
    final m = p.regex.firstMatch(s);
    if (m != null) {
      result = _build2(p, m, table);
      break;
    }
  }
  if (cache.length > 3000) cache.clear();
  cache[s] = result;
  return result;
}