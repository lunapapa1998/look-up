import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/demo/fallback_apis.dart';

export '../api/demo/fallback_apis.dart' show SampleSource, SampleSourceReporter;

/// Set of API sources currently being served by sample data (spec 052).
/// A source is added when its `Fallback*Api` returns a sample and removed
/// again as soon as a real call for it succeeds.
class SampleSourcesNotifier extends Notifier<Set<SampleSource>> {
  @override
  Set<SampleSource> build() => const {};

  void markSample(SampleSource source) {
    if (state.contains(source)) return;
    state = {...state, source};
  }

  void markReal(SampleSource source) {
    if (!state.contains(source)) return;
    state = {...state}..remove(source);
  }
}

final sampleSourcesProvider =
    NotifierProvider<SampleSourcesNotifier, Set<SampleSource>>(
  SampleSourcesNotifier.new,
);

/// Reporter for a `Fallback*Api` built inside an api provider. Uses
/// `ref.read` only — watching [sampleSourcesProvider] there would rebuild
/// the api provider on every report and refetch forever.
SampleSourceReporter sampleReporterFor(Ref ref) {
  return SampleSourceReporter(
    onSample: (source) =>
        ref.read(sampleSourcesProvider.notifier).markSample(source),
    onReal: (source) =>
        ref.read(sampleSourcesProvider.notifier).markReal(source),
  );
}
