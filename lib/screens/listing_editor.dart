import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../core/haptics.dart';
import '../core/sa_data.dart';
import '../data/repository.dart';
import '../models/models.dart';
import '../state/auth.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'studio.dart';

class ListingEditorScreen extends ConsumerStatefulWidget {
  const ListingEditorScreen({super.key, required this.agent, this.listing});

  final Agent agent;
  final PropertyListing? listing;

  @override
  ConsumerState<ListingEditorScreen> createState() =>
      _ListingEditorScreenState();
}

class _ListingEditorScreenState extends ConsumerState<ListingEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late ListingMode _mode;
  late ListingStatus _status;
  late String _propertyType;
  late String _province;
  String? _city;
  late String _energyRating;

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _suburbCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _bedsCtrl;
  late final TextEditingController _bathsCtrl;
  late final TextEditingController _parkingCtrl;
  late final TextEditingController _floorCtrl;
  late final TextEditingController _erfCtrl;
  late final TextEditingController _levyCtrl;
  late final TextEditingController _ratesCtrl;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;

  late int _loadSheddingScore;
  late int _safetyScore;
  late int _schoolScore;
  late int _lifestyleScore;
  late List<String> _lifestyle;
  late List<String> _security;
  late List<String> _resilience;
  late List<String> _remoteImages;
  final _localImages = <ListingImageUpload>[];
  bool _saving = false;
  String? _savingStage;

  bool get _editing => widget.listing != null;

  @override
  void initState() {
    super.initState();
    final l = widget.listing;
    _mode = l?.mode ?? ListingMode.buy;
    _status = l?.status ?? ListingStatus.draft;
    _propertyType = l?.propertyType ?? 'House';
    _province = l?.province ?? 'Gauteng';
    _city = l?.city ?? SaData.citiesByProvince[_province]?.first;
    _energyRating = l?.energyRating ?? 'B';
    _titleCtrl = TextEditingController(text: l?.title ?? '');
    _descriptionCtrl = TextEditingController(text: l?.description ?? '');
    _priceCtrl = TextEditingController(text: l?.price.toStringAsFixed(0) ?? '');
    _suburbCtrl = TextEditingController(text: l?.suburb ?? '');
    _addressCtrl = TextEditingController();
    _bedsCtrl = TextEditingController(text: '${l?.beds ?? 0}');
    _bathsCtrl = TextEditingController(text: '${l?.baths ?? 0}');
    _parkingCtrl = TextEditingController(text: '${l?.parking ?? 0}');
    _floorCtrl = TextEditingController(text: '${l?.floorSize ?? 0}');
    _erfCtrl = TextEditingController(text: l?.erfSize?.toString() ?? '');
    _levyCtrl = TextEditingController(text: l?.levy?.toStringAsFixed(0) ?? '');
    _ratesCtrl = TextEditingController(
      text: l?.rates?.toStringAsFixed(0) ?? '',
    );
    _latCtrl = TextEditingController(
      text: l?.latitude?.toStringAsFixed(6) ?? '',
    );
    _lngCtrl = TextEditingController(
      text: l?.longitude?.toStringAsFixed(6) ?? '',
    );
    _loadSheddingScore = l?.loadSheddingScore ?? 7;
    _safetyScore = l?.safetyScore ?? 8;
    _schoolScore = l?.schoolScore ?? 7;
    _lifestyleScore = l?.lifestyleScore ?? 8;
    _lifestyle = [...?l?.lifestyleFeatures];
    _security = [...?l?.securityFeatures];
    _resilience = [...?l?.resilienceFeatures];
    _remoteImages = l == null
        ? []
        : l.allImages.where((url) => url.isNotEmpty).toList();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _priceCtrl.dispose();
    _suburbCtrl.dispose();
    _addressCtrl.dispose();
    _bedsCtrl.dispose();
    _bathsCtrl.dispose();
    _parkingCtrl.dispose();
    _floorCtrl.dispose();
    _erfCtrl.dispose();
    _levyCtrl.dispose();
    _ratesCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit listing' : 'Create listing'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: TrustBadge(
                label: _status.label.toUpperCase(),
                icon: _status.icon,
                color: _statusColor(_status),
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 130),
          children: [
            _heroHeader(),
            const SizedBox(height: 16),
            _section('Listing basics', [
              _text(
                _titleCtrl,
                'Listing title',
                icon: Icons.title,
                required: true,
              ),
              _gap,
              _dropdown<ListingMode>(
                label: 'Market',
                value: _mode,
                items: ListingMode.values,
                labelOf: (m) => m.label,
                onChanged: (m) async {
                  await AppHaptics.tap();
                  setState(() => _mode = m);
                },
              ),
              _gap,
              _dropdown<String>(
                label: 'Property type',
                value: _propertyType,
                items: SaData.propertyTypes,
                labelOf: (v) => v,
                onChanged: (v) async {
                  await AppHaptics.tap();
                  setState(() => _propertyType = v);
                },
              ),
              _gap,
              _text(
                _descriptionCtrl,
                'Description',
                icon: Icons.notes_outlined,
                required: true,
                maxLines: 5,
              ),
            ]),
            _section('Workflow', [
              _statusRail(),
              const SizedBox(height: 12),
              _dropdown<ListingStatus>(
                label: 'Current status',
                value: _status,
                items: ListingStatus.values,
                labelOf: (s) => s.label,
                onChanged: (s) async {
                  await AppHaptics.tap();
                  setState(() => _status = s);
                },
              ),
            ]),
            _section('Price & ownership costs', [
              _text(
                _priceCtrl,
                _mode == ListingMode.commercial
                    ? 'Price per m² / month'
                    : 'Price',
                icon: Icons.payments_outlined,
                keyboard: TextInputType.number,
                required: true,
              ),
              _gap,
              Row(
                children: [
                  Expanded(
                    child: _text(
                      _levyCtrl,
                      'Levy',
                      keyboard: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _text(
                      _ratesCtrl,
                      'Rates',
                      keyboard: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ]),
            _section('Location', [
              _dropdown<String>(
                label: 'Province',
                value: _province,
                items: SaData.provinces,
                labelOf: (v) => v,
                onChanged: (v) async {
                  await AppHaptics.tap();
                  setState(() {
                    _province = v;
                    _city = SaData.citiesByProvince[v]?.first;
                  });
                },
              ),
              _gap,
              _dropdown<String>(
                label: 'City',
                value: _city ?? SaData.citiesByProvince[_province]?.first,
                items: SaData.citiesByProvince[_province] ?? const [],
                labelOf: (v) => v,
                onChanged: (v) async {
                  await AppHaptics.tap();
                  setState(() => _city = v);
                },
              ),
              _gap,
              _text(
                _suburbCtrl,
                'Suburb',
                icon: Icons.location_on_outlined,
                required: true,
              ),
              _gap,
              _text(
                _addressCtrl,
                'Street address (private)',
                icon: Icons.pin_drop_outlined,
              ),
              _gap,
              Row(
                children: [
                  Expanded(
                    child: _text(
                      _latCtrl,
                      'Latitude',
                      keyboard: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _text(
                      _lngCtrl,
                      'Longitude',
                      keyboard: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ),
                ],
              ),
            ]),
            _section('Specs', [
              Row(
                children: [
                  Expanded(
                    child: _text(
                      _bedsCtrl,
                      'Beds',
                      keyboard: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _text(
                      _bathsCtrl,
                      'Baths',
                      keyboard: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _text(
                      _parkingCtrl,
                      'Parking',
                      keyboard: TextInputType.number,
                    ),
                  ),
                ],
              ),
              _gap,
              Row(
                children: [
                  Expanded(
                    child: _text(
                      _floorCtrl,
                      'Floor m²',
                      keyboard: TextInputType.number,
                      required: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _text(
                      _erfCtrl,
                      'Erf m²',
                      keyboard: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ]),
            _section('Media', [
              _mediaGrid(),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Add images'),
                onPressed: repo == null || _saving ? null : _pickImages,
              ),
            ]),
            _section('South African filters', [
              _choiceWrap(
                'Load shedding ready',
                SaData.resilienceFeatures,
                _resilience,
                (next) => setState(() => _resilience = next),
              ),
              const SizedBox(height: 16),
              _choiceWrap(
                'Security',
                SaData.securityFeatures,
                _security,
                (next) => setState(() => _security = next),
              ),
              const SizedBox(height: 16),
              _choiceWrap(
                'Lifestyle',
                SaData.lifestyleFeatures,
                _lifestyle,
                (next) => setState(() => _lifestyle = next),
              ),
            ]),
            _section('Suburb intelligence', [
              _score(
                'Load shedding',
                _loadSheddingScore,
                (v) => setState(() => _loadSheddingScore = v),
              ),
              _score(
                'Safety',
                _safetyScore,
                (v) => setState(() => _safetyScore = v),
              ),
              _score(
                'Schools',
                _schoolScore,
                (v) => setState(() => _schoolScore = v),
              ),
              _score(
                'Lifestyle',
                _lifestyleScore,
                (v) => setState(() => _lifestyleScore = v),
              ),
              _gap,
              _dropdown<String>(
                label: 'Energy rating',
                value: _energyRating,
                items: const ['A', 'B', 'C', 'D', 'E', 'F', 'G'],
                labelOf: (v) => v,
                onChanged: (v) async {
                  await AppHaptics.tap();
                  setState(() => _energyRating = v);
                },
              ),
            ]),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.black,
                    ),
                  )
                : Icon(
                    _editing
                        ? Icons.save_outlined
                        : Icons.add_home_work_outlined,
                  ),
            label: Text(
              _saving
                  ? _savingStage ?? 'Saving listing…'
                  : _editing
                  ? 'Save changes'
                  : 'Create listing',
            ),
            onPressed: repo == null || _saving ? null : _save,
          ),
        ),
      ),
    );
  }

  Widget _heroHeader() {
    return GlassCard(
      gradient: AppColors.heroGradient,
      borderColor: AppColors.primary.withValues(alpha: 0.3),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _statusColor(_status).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _statusColor(_status).withValues(alpha: 0.4),
              ),
            ),
            child: Icon(_status.icon, color: _statusColor(_status)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _editing
                      ? 'Professional listing workspace'
                      : 'Launch a new property',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Keep drafts private, publish when ready, then move the property through offer and settlement stages.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget get _gap => const SizedBox(height: 12);

  Widget _text(
    TextEditingController controller,
    String label, {
    IconData? icon,
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboard,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboard,
      validator: required
          ? (v) => v == null || v.trim().isEmpty ? '$label required' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon),
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) labelOf,
    required ValueChanged<T> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: items.contains(value)
          ? value
          : (items.isEmpty ? null : items.first),
      items: [
        for (final item in items)
          DropdownMenuItem(value: item, child: Text(labelOf(item))),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      decoration: InputDecoration(labelText: label),
      dropdownColor: AppColors.surfaceHigh,
    );
  }

  Widget _statusRail() {
    return Row(
      children: [
        for (final s in ListingStatus.values.take(5))
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: GestureDetector(
                onTap: () async {
                  await AppHaptics.tap();
                  setState(() => _status = s);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _status == s
                        ? _statusColor(s).withValues(alpha: 0.18)
                        : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _status == s ? _statusColor(s) : AppColors.outline,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        s.icon,
                        size: 18,
                        color: _status == s
                            ? _statusColor(s)
                            : AppColors.textMuted,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        s.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: TextStyle(
                          color: _status == s
                              ? _statusColor(s)
                              : AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _mediaGrid() {
    final hasAny = _remoteImages.isNotEmpty || _localImages.isNotEmpty;
    if (!hasAny) {
      return EmptyStateCard(
        icon: Icons.photo_library_outlined,
        title: 'No images yet',
        subtitle:
            'Add bright, wide photos. Images are compressed before upload for faster publishing.',
        actionLabel: 'Add images',
        onAction: _pickImages,
      );
    }
    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _remoteImages.length + _localImages.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final remote = i < _remoteImages.length;
          final child = remote
              ? Image.network(_remoteImages[i], fit: BoxFit.cover)
              : Image.memory(
                  _localImages[i - _remoteImages.length].bytes,
                  fit: BoxFit.cover,
                );
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(width: 150, height: 130, child: child),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () async {
                      await AppHaptics.tap();
                      setState(() {
                        if (remote) {
                          _remoteImages.removeAt(i);
                        } else {
                          _localImages.removeAt(i - _remoteImages.length);
                        }
                      });
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.close, color: Colors.white, size: 14),
                    ),
                  ),
                ),
              ),
              if (i == 0)
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Hero',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    remote
                        ? 'Live'
                        : _formatBytes(
                            _localImages[i - _remoteImages.length].bytes.length,
                          ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _choiceWrap(
    String title,
    List<String> options,
    List<String> selected,
    ValueChanged<List<String>> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              FilterChipMini(
                label: option,
                selected: selected.contains(option),
                onTap: () {
                  AppHaptics.tap();
                  final next = [...selected];
                  if (!next.remove(option)) next.add(option);
                  onChanged(next);
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _score(String label, int value, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '$value/10',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Slider(
            value: value.toDouble(),
            min: 0,
            max: 10,
            divisions: 10,
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImages() async {
    await AppHaptics.tap();
    final images = await _picker.pickMultiImage(
      imageQuality: 72,
      maxWidth: 1800,
      maxHeight: 1800,
    );
    if (images.isEmpty) return;
    final uploads = <ListingImageUpload>[];
    for (final image in images) {
      final bytes = await image.readAsBytes();
      uploads.add(
        ListingImageUpload(
          fileName: image.name,
          bytes: bytes,
          contentType: _contentType(image.name),
        ),
      );
    }
    setState(() => _localImages.addAll(uploads));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${uploads.length} image${uploads.length == 1 ? '' : 's'} compressed and queued for upload.',
          ),
        ),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_status == ListingStatus.active &&
        _remoteImages.isEmpty &&
        _localImages.isEmpty) {
      await AppHaptics.warning();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one image before publishing active.'),
        ),
      );
      return;
    }
    final repo = ref.read(repositoryProvider);
    if (repo == null) return;
    AppHaptics.light();
    setState(() {
      _saving = true;
      _savingStage = 'Saving listing…';
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final values = _payload();
      var saved = _editing
          ? await repo.updateListing(
              listingId: widget.listing!.id,
              values: values,
            )
          : await repo.createListingForAgent(
              agent: widget.agent,
              values: values,
            );

      if (_localImages.isNotEmpty) {
        setState(() => _savingStage = 'Uploading photos…');
        final uploaded = await repo.uploadListingImages(
          agentId: widget.agent.id,
          listingId: saved.id,
          images: _localImages,
        );
        saved = await repo.setListingImages(
          listingId: saved.id,
          urls: [..._remoteImages, ...uploaded],
        );
      } else if (_remoteImages.isNotEmpty) {
        setState(() => _savingStage = 'Updating gallery…');
        saved = await repo.setListingImages(
          listingId: saved.id,
          urls: _remoteImages,
        );
      }

      ref.invalidate(studioSnapshotProvider);
      if (!mounted) return;
      AppHaptics.success();
      await showSuccessPulse(
        context,
        title: _status == ListingStatus.active ? 'Published' : 'Saved',
        message: '${saved.title} is ${_status.label.toLowerCase()}.',
        icon: _status.icon,
      );
      messenger.showSnackBar(SnackBar(content: Text('${saved.title} saved.')));
      navigator.pop(true);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save listing: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _savingStage = null;
        });
      }
    }
  }

  Map<String, dynamic> _payload() {
    return {
      'title': _titleCtrl.text.trim(),
      'description': _descriptionCtrl.text.trim(),
      'mode': _mode.name,
      'status': _status.dbValue,
      'property_type': _propertyType,
      'price': _num(_priceCtrl.text),
      'province': _province,
      'city': _city ?? '',
      'suburb': _suburbCtrl.text.trim(),
      'address': _addressCtrl.text.trim().isEmpty
          ? null
          : _addressCtrl.text.trim(),
      'bedrooms': _int(_bedsCtrl.text),
      'bathrooms': _num(_bathsCtrl.text),
      'parking': _int(_parkingCtrl.text),
      'floor_size': _int(_floorCtrl.text),
      'erf_size': _nullableInt(_erfCtrl.text),
      'levy': _nullableNum(_levyCtrl.text),
      'rates': _nullableNum(_ratesCtrl.text),
      'latitude': _nullableNum(_latCtrl.text),
      'longitude': _nullableNum(_lngCtrl.text),
      'lifestyle_features': _lifestyle,
      'security_features': _security,
      'resilience_features': _resilience,
      'load_shedding_score': _loadSheddingScore,
      'safety_score': _safetyScore,
      'school_score': _schoolScore,
      'lifestyle_score': _lifestyleScore,
      'energy_rating': _energyRating,
      'is_verified': true,
      'popi_compliant': true,
      'eaab_registered': true,
      if (_remoteImages.isNotEmpty) 'hero_image_url': _remoteImages.first,
      if (_remoteImages.length > 1)
        'gallery_urls': _remoteImages.skip(1).toList(),
    };
  }

  int _int(String value) => int.tryParse(value.trim()) ?? 0;
  int? _nullableInt(String value) =>
      value.trim().isEmpty ? null : int.tryParse(value.trim());
  num _num(String value) => num.tryParse(value.trim()) ?? 0;
  num? _nullableNum(String value) =>
      value.trim().isEmpty ? null : num.tryParse(value.trim());

  String _contentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  Color _statusColor(ListingStatus status) {
    return switch (status) {
      ListingStatus.draft => AppColors.textMuted,
      ListingStatus.active => AppColors.primary,
      ListingStatus.underOffer => AppColors.warning,
      ListingStatus.sold => AppColors.info,
      ListingStatus.rented => AppColors.info,
      ListingStatus.archived => AppColors.textFaint,
    };
  }
}
