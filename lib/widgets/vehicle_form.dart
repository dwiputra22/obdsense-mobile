import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import '../core/i18n/tr_text.dart';
import '../core/i18n/translations.dart';
import '../core/theme/app_colors.dart';
import '../models/vehicle_profile.dart';
import '../models/vehicle_spec.dart';
import '../services/catalog/vehicle_catalog_service.dart';

class VehicleFormController extends ChangeNotifier {
  VehicleFormController(VehicleProfile p)
      : brand = TextEditingController(text: p.brand),
        model = TextEditingController(text: p.model),
        year = TextEditingController(text: p.year > 0 ? '${p.year}' : ''),
        nickname = TextEditingController(text: p.nickname),
        engine = TextEditingController(text: p.engineName),
        tank = TextEditingController(text: p.tankLiters == null ? '' : _fmtTank(p.tankLiters!)),
        fuelType = p.fuelType,
        transmission = p.transmission,
        gearCount = p.gearCount;

  final VehicleCatalog? catalog = VehicleCatalog.instance;

  final TextEditingController brand;
  final TextEditingController model;
  final TextEditingController year;
  final TextEditingController nickname;
  final TextEditingController engine;
  final TextEditingController tank;

  String? fuelType;
  String? transmission;
  int? gearCount;

  static String _fmtTank(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  CatalogModel? get matched => catalog?.find(brand.text, model.text);

  void onBrandSelected(String name) {
    brand.text = name;
    if (catalog?.brand(name) != null && matched == null && model.text.isNotEmpty) {
      model.clear();
    }
    notifyListeners();
  }

  void onModelSelected(String name) {
    model.text = name;
    final m = matched;
    if (m != null) {
      if (m.engines.length == 1) {
        selectEngine(m.engines.first);
      } else if (m.onlyFuel != null) {
        fuelType = m.onlyFuel!.name;
      }
      if (m.transmissions.length == 1) selectTransmission(m.transmissions.first);
      if (tank.text.trim().isEmpty && m.tankLiters != null) tank.text = _fmtTank(m.tankLiters!);
    }
    notifyListeners();
  }

  void selectEngine(CatalogEngine e) {
    engine.text = e.label;
    fuelType = e.fuel.name;
    if (e.fuel == FuelType.electric) {
      transmission = 'EV';
      gearCount = null;
    }
    notifyListeners();
  }

  void setFuel(String? f) {
    fuelType = f;
    notifyListeners();
  }

  void selectTransmission(CatalogTransmission t) {
    transmission = t.type;
    gearCount = t.gears;
    notifyListeners();
  }

  void setGenericTransmission(String type) {
    transmission = type;
    gearCount = null;
    notifyListeners();
  }

  String? validate() {
    if (brand.text.trim().isEmpty) return 'Merek kendaraan wajib diisi.';
    if (model.text.trim().isEmpty) return 'Model kendaraan wajib diisi.';
    final y = int.tryParse(year.text.trim());
    final maxYear = DateTime.now().year + 1;
    if (y == null || y < 1980 || y > maxYear) return 'Tahun kendaraan tidak valid (1980–$maxYear).';
    final t = tank.text.trim().replaceAll(',', '.');
    if (t.isNotEmpty) {
      final v = double.tryParse(t);
      if (v == null || v < 10 || v > 200) return 'Kapasitas tangki tidak valid (10–200 liter).';
    }
    return null;
  }

  VehicleProfile toProfile(VehicleProfile base, {String? vin}) {
    final m = matched;
    final tankText = tank.text.trim().replaceAll(',', '.');
    final tankValue = tankText.isEmpty ? m?.tankLiters : double.tryParse(tankText);
    return VehicleProfile(
      vin: vin ?? base.vin,
      remoteId: base.remoteId,
      brand: brand.text.trim(),
      model: model.text.trim(),
      year: int.tryParse(year.text.trim()) ?? 0,
      nickname: nickname.text.trim(),
      engineName: engine.text.trim(),
      fuelType: fuelType ?? m?.onlyFuel?.name,
      transmission: transmission,
      gearCount: gearCount,
      tankLiters: tankValue,
    );
  }

  @override
  void dispose() {
    brand.dispose();
    model.dispose();
    year.dispose();
    nickname.dispose();
    engine.dispose();
    tank.dispose();
    super.dispose();
  }
}

class VehicleFormFields extends StatelessWidget {
  const VehicleFormFields({super.key, required this.controller, this.collapseTechnical = false});

  final VehicleFormController controller;

  final bool collapseTechnical;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return ListenableBuilder(
      listenable: Listenable.merge([c, c.brand, c.model]),
      builder: (context, _) {
        final catalog = c.catalog;
        final matched = c.matched;
        final technical = _technical(context, matched);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SuggestField(
              controller: c.brand,
              label: 'Merek',
              icon: Icons.directions_car_rounded,
              options: (q) => catalog?.suggestBrands(q) ?? const [],
              onSelected: c.onBrandSelected,
            ),
            _SuggestField(
              controller: c.model,
              label: 'Model',
              icon: Icons.car_repair_rounded,
              options: (q) => catalog?.suggestModels(c.brand.text, q) ?? const [],
              onSelected: c.onModelSelected,
            ),
            if (matched != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14, left: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.green),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Ada di katalog · ${matched.body} · ${matched.yearsLabel}',
                        style: TextStyle(color: context.palette.muted, fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
              ),
            _plain(
              c.year,
              'Tahun',
              Icons.calendar_today_rounded,
              keyboard: TextInputType.number,
              digitsOnly: true,
              maxLength: 4,
            ),
            _plain(c.nickname, 'Nama panggilan (opsional)', Icons.badge_rounded),
            if (collapseTechnical)
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(top: 4),
                  title: const Text('Detail teknis (opsional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: Text(
                    'Mesin, bahan bakar, transmisi, tangki',
                    style: TextStyle(color: context.palette.muted, fontSize: 11.5),
                  ),
                  children: [technical],
                ),
              )
            else
              technical,
          ],
        );
      },
    );
  }

  Widget _technical(BuildContext context, CatalogModel? matched) {
    final c = controller;
    final palette = context.palette;

    final transmissions = matched?.transmissions ?? const <CatalogTransmission>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (matched != null && matched.engines.isNotEmpty) ...[
          _caption(context, 'Pilih mesin'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in matched.engines)
                ChoiceChip(
                  label: Text(e.label),
                  selected: c.engine.text == e.label,
                  onSelected: (_) => c.selectEngine(e),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        _plain(c.engine, 'Kode / tipe mesin (opsional)', Icons.settings_rounded),
        _caption(context, 'Bahan bakar'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in FuelType.values)
              ChoiceChip(
                label: Text(f.label),
                selected: c.fuelType == f.name,
                onSelected: (_) => c.setFuel(f.name),
              ),
          ],
        ),
        if (c.fuelType == FuelType.diesel.name)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Mesin diesel: konsumsi BBM hanya dihitung bila ECU melaporkan laju BBM langsung (PID 015E). Estimasi dari MAF tidak dipakai karena tidak akurat untuk diesel.',
              style: TextStyle(color: palette.muted, fontSize: 11.5, height: 1.35),
            ),
          ),
        if (c.fuelType == FuelType.electric.name)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Kendaraan listrik: RPM mesin dan level BBM tidak tersedia lewat OBD-II standar.',
              style: TextStyle(color: palette.muted, fontSize: 11.5, height: 1.35),
            ),
          ),
        const SizedBox(height: 14),
        _caption(context, 'Transmisi'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (transmissions.isNotEmpty)
              for (final t in transmissions)
                ChoiceChip(
                  label: Text(t.label),
                  selected: c.transmission == t.type && c.gearCount == t.gears,
                  onSelected: (_) => c.selectTransmission(t),
                )
            else
              for (final t in const [('MT', 'Manual'), ('AT', 'Automatic'), ('CVT', 'CVT')])
                ChoiceChip(
                  label: Text(t.$2),
                  selected: c.transmission == t.$1,
                  onSelected: (_) => c.setGenericTransmission(t.$1),
                ),
          ],
        ),
        const SizedBox(height: 14),
        _plain(
          c.tank,
          'Kapasitas tangki, liter (opsional)',
          Icons.local_gas_station_rounded,
          keyboard: const TextInputType.numberWithOptions(decimal: true),
          maxLength: 5,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'Nilai awal dari katalog bersifat perkiraan, silakan koreksi sesuai kendaraan Anda.',
            style: TextStyle(color: palette.muted, fontSize: 11.5, height: 1.35),
          ),
        ),
      ],
    );
  }

  Widget _caption(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(
          text,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.3, color: context.palette.muted),
        ),
      );

  Widget _plain(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    bool digitsOnly = false,
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        maxLength: maxLength,
        textInputAction: TextInputAction.next,
        inputFormatters: digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
        decoration: InputDecoration(
          labelText: tr(label),
          counterText: '',
          prefixIcon: Icon(icon, size: 20),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        ),
      ),
    );
  }
}

/// Kolom teks dengan daftar saran (autocomplete) yang tetap menerima ketikan bebas.
class _SuggestField extends StatefulWidget {
  const _SuggestField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.options,
    required this.onSelected,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final List<String> Function(String query) options;
  final ValueChanged<String> onSelected;

  @override
  State<_SuggestField> createState() => _SuggestFieldState();
}

class _SuggestFieldState extends State<_SuggestField> {
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: LayoutBuilder(
        builder: (context, constraints) => RawAutocomplete<String>(
          textEditingController: widget.controller,
          focusNode: _focus,
          optionsBuilder: (value) => widget.options(value.text),
          onSelected: widget.onSelected,
          fieldViewBuilder: (context, ctrl, focus, onSubmit) => TextField(
            controller: ctrl,
            focusNode: focus,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => onSubmit(),
            decoration: InputDecoration(
              labelText: tr(widget.label),
              prefixIcon: Icon(widget.icon, size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            ),
          ),
          optionsViewBuilder: (context, onSelected, options) => Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 6,
              color: palette.panel,
              borderRadius: BorderRadius.circular(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 240, maxWidth: constraints.maxWidth),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, i) {
                    final option = options.elementAt(i);
                    return InkWell(
                      onTap: () => onSelected(option),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Text(option, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}