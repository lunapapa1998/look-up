import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/ecolog_api.dart';
import '../models/observation.dart';
import '../state/providers.dart';
import '../state/sample_data_provider.dart';
import 'diary_list_screen.dart';

/// Create/edit form for a single [Observation].
///
/// Create mode when [existing] is null, edit mode (pre-filled) otherwise.
///
/// [initialSpeciesType]/[initialSpeciesName] optionally prefill a NEW record
/// (spec 058 Phase 1); they are ignored in edit mode, where [existing] wins.
class ObservationFormScreen extends ConsumerStatefulWidget {
  final Observation? existing;
  final SpeciesType? initialSpeciesType;
  final String? initialSpeciesName;

  const ObservationFormScreen({
    super.key,
    this.existing,
    this.initialSpeciesType,
    this.initialSpeciesName,
  });

  @override
  ConsumerState<ObservationFormScreen> createState() =>
      _ObservationFormScreenState();
}

class _ObservationFormScreenState extends ConsumerState<ObservationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late SpeciesType _speciesType;
  late final TextEditingController _speciesNameController;
  late final TextEditingController _noteController;
  late final TextEditingController _photoUrlController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _speciesType = existing != null
        ? existing.speciesType
        : widget.initialSpeciesType ?? SpeciesType.bird;
    _speciesNameController = TextEditingController(
      text: existing != null
          ? existing.speciesName
          : widget.initialSpeciesName ?? '',
    );
    _noteController = TextEditingController(text: existing?.note ?? '');
    _photoUrlController =
        TextEditingController(text: existing?.photoUrl ?? '');
    _latController = TextEditingController(text: existing?.lat?.toString() ?? '');
    _lngController = TextEditingController(text: existing?.lng?.toString() ?? '');
  }

  @override
  void dispose() {
    _speciesNameController.dispose();
    _noteController.dispose();
    _photoUrlController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final speciesName = _speciesNameController.text.trim();
    final note = _noteController.text.trim();
    final photoUrl = _photoUrlController.text.trim();
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());

    try {
      final notifier = ref.read(observationsProvider.notifier);
      if (_isEditing) {
        await notifier.updateObservation(
          widget.existing!.id,
          ObservationUpdate(
            speciesType: _speciesType,
            speciesName: speciesName,
            note: note.isEmpty ? null : note,
            noteSet: true,
            photoUrl: photoUrl.isEmpty ? null : photoUrl,
            photoUrlSet: true,
            lat: lat,
            latSet: true,
            lng: lng,
            lngSet: true,
          ),
        );
      } else {
        await notifier.createObservation(
          ObservationCreate(
            speciesType: _speciesType,
            speciesName: speciesName,
            note: note.isEmpty ? null : note,
            photoUrl: photoUrl.isEmpty ? null : photoUrl,
            lat: lat,
            lng: lng,
          ),
        );
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      // Demo fallback (spec 052) kept the write on-device only. It vanishes
      // from the list once the server answers again, hence "임시".
      final isSample =
          ref.read(sampleSourcesProvider).contains(SampleSource.ecolog);
      if (!_isEditing) {
        // Spec 058 Phase 4: a new record offers a jump to the diary. The
        // sample notice keeps its own copy but gets the same action.
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              isSample ? '서버에 연결할 수 없어 이 기기에만 임시 저장됐어요' : '기록했어요',
            ),
            action: SnackBarAction(
              label: '생태일기 보기',
              onPressed: () => navigator.push(
                MaterialPageRoute<void>(
                  builder: (_) => const DiaryListScreen(),
                ),
              ),
            ),
          ),
        );
      } else if (isSample) {
        messenger.showSnackBar(
          const SnackBar(content: Text('서버에 연결할 수 없어 이 기기에만 임시 저장됐어요')),
        );
      }
      navigator.pop();
    } on EcologApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '관찰 수정' : '새 관찰 기록'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<SpeciesType>(
              segments: const [
                ButtonSegment(
                  value: SpeciesType.bird,
                  label: Text('새'),
                  icon: Icon(Icons.flutter_dash),
                ),
                ButtonSegment(
                  value: SpeciesType.star,
                  label: Text('별'),
                  icon: Icon(Icons.star),
                ),
              ],
              selected: {_speciesType},
              onSelectionChanged: (selection) {
                setState(() => _speciesType = selection.first);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _speciesNameController,
              decoration: const InputDecoration(labelText: '종 이름'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '종 이름을 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: '메모'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _photoUrlController,
              decoration: const InputDecoration(labelText: '사진 URL'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _latController,
              decoration: const InputDecoration(labelText: '위도'),
              keyboardType:
                  const TextInputType.numberWithOptions(signed: true, decimal: true),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lngController,
              decoration: const InputDecoration(labelText: '경도'),
              keyboardType:
                  const TextInputType.numberWithOptions(signed: true, decimal: true),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '저장 중...' : '저장'),
            ),
          ],
        ),
      ),
    );
  }
}
