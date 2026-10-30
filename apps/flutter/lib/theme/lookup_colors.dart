import 'package:flutter/material.dart';

/// Text color for a day/night-meaning [accent] (yellow / lavender): the
/// accent itself on the dark (night) theme, `colorScheme.onSurface` on the
/// light (day) theme, where yellow/lavender text would be unreadable on a
/// light background. Icons, bars and dots may keep the raw accent.
Color accentText(BuildContext context, Color accent) {
  final theme = Theme.of(context);
  return theme.brightness == Brightness.dark
      ? accent
      : theme.colorScheme.onSurface;
}

/// LookUp status/provenance accent colors (spec 053 Phase 2), registered on
/// [ThemeData.extensions] by `AppTheme.themeFor` in a day and a night set.
///
/// These are small-area colors only: dots, thin borders, icons, and rating
/// stars. Text stays `ColorScheme.onSurface` (or `onSurfaceVariant`); never
/// use these as text color or a wide fill, and never use color alone to
/// convey state — pair it with a label, icon, or shape.
///
/// Only [rating] is wired in this phase; the other fields are defined for
/// later phases (specs 054/055) and are not referenced by screens yet.
///
/// Day/night-meaning accents ([modeDayAccent] yellow #F4C247,
/// [onModeDayAccent] #141414, [modeNightAccent] lavender #9CA3F5,
/// [onModeNightAccent] white #FFFFFF; spec 054-3a, final user decision) are
/// the exception to the small-area rule: they are the `ModeToggle`
/// selected-segment fill with its text/icon foreground, and the day vs
/// night suitability elements on home (sun/moon icon, score, bar, golden
/// hours). Identical in the day and night sets. Never use them for status,
/// provenance, warnings, ratings, or any other meaning.
@immutable
class LookUpColors extends ThemeExtension<LookUpColors> {
  const LookUpColors({
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.provenanceLive,
    required this.provenanceApprox,
    required this.provenanceSample,
    required this.provenanceStale,
    required this.rating,
    required this.ratingEmpty,
    required this.hairline,
    required this.mapScrim,
    required this.birdAccent,
    required this.starAccent,
    required this.mapTrail,
    required this.mapHeritage,
    required this.modeDayAccent,
    required this.onModeDayAccent,
    required this.modeNightAccent,
    required this.onModeNightAccent,
  });

  /// Day set: darkened variants so dots/icons clear 3:1 on `#FFFFFF`.
  static const LookUpColors day = LookUpColors(
    warning: Color(0xFFB45309),
    onWarning: Color(0xFFFFFFFF),
    warningContainer: Color(0xFFFDF0E1),
    provenanceLive: Color(0xFF21935B),
    provenanceApprox: Color(0xFF767676),
    provenanceSample: Color(0xFF767676),
    provenanceStale: Color(0xFFB45309),
    rating: Color(0xFFA16207),
    ratingEmpty: Color(0xFF767676),
    hairline: Color(0xFFD9D9D9),
    mapScrim: Color(0x66000000),
    birdAccent: Color(0xFF0A7864),
    starAccent: Color(0xFF8A5700),
    mapTrail: Color(0xFF5C8A72),
    mapHeritage: Color(0xFF8A7A68),
    modeDayAccent: Color(0xFFF4C247),
    onModeDayAccent: Color(0xFF141414),
    modeNightAccent: Color(0xFF9CA3F5),
    onModeNightAccent: Color(0xFFFFFFFF),
  );

  /// Night set: Flim signal colors, all >= 3:1 on `#141414`.
  static const LookUpColors night = LookUpColors(
    warning: Color(0xFFFF8400),
    onWarning: Color(0xFF141414),
    warningContainer: Color(0xFF3A2200),
    provenanceLive: Color(0xFF30A81D),
    provenanceApprox: Color(0xFF8C8C8C),
    provenanceSample: Color(0xFF8C8C8C),
    provenanceStale: Color(0xFFFF8400),
    rating: Color(0xFFFECC33),
    ratingEmpty: Color(0xFF8C8C8C),
    hairline: Color(0xFF333333),
    mapScrim: Color(0x99000000),
    birdAccent: Color(0xFF42E1BE),
    starAccent: Color(0xFFF5BC7E),
    mapTrail: Color(0xFF5C8A72),
    mapHeritage: Color(0xFF8A7A68),
    modeDayAccent: Color(0xFFF4C247),
    onModeDayAccent: Color(0xFF141414),
    modeNightAccent: Color(0xFF9CA3F5),
    onModeNightAccent: Color(0xFFFFFFFF),
  );

  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color provenanceLive;
  final Color provenanceApprox;
  final Color provenanceSample;
  final Color provenanceStale;
  final Color rating;
  final Color ratingEmpty;
  final Color hairline;
  final Color mapScrim;
  final Color birdAccent;
  final Color starAccent;
  final Color mapTrail;
  final Color mapHeritage;

  /// Day-meaning accent (yellow #F4C247, same in both sets): selected '낮'
  /// ModeToggle fill and home day-suitability elements.
  final Color modeDayAccent;

  /// Text/icon drawn on a [modeDayAccent] fill (#141414).
  final Color onModeDayAccent;

  /// Night-meaning accent (lavender #9CA3F5, same in both sets): selected
  /// '밤' ModeToggle fill and home night-suitability elements.
  final Color modeNightAccent;

  /// '밤' text and moon icon drawn on a [modeNightAccent] fill (white
  /// #FFFFFF, final user decision). Only ~2.34:1 on the lavender fill —
  /// below 4.5:1 for text and 3:1 for the icon. Known, user-accepted
  /// limitation; do not change the color or add a border to "fix" it.
  final Color onModeNightAccent;

  /// The [LookUpColors] registered on the ambient theme, falling back to
  /// [day] when the theme has no extension (e.g. bare test harnesses).
  static LookUpColors of(BuildContext context) =>
      Theme.of(context).extension<LookUpColors>() ?? day;

  @override
  LookUpColors copyWith({
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? provenanceLive,
    Color? provenanceApprox,
    Color? provenanceSample,
    Color? provenanceStale,
    Color? rating,
    Color? ratingEmpty,
    Color? hairline,
    Color? mapScrim,
    Color? birdAccent,
    Color? starAccent,
    Color? mapTrail,
    Color? mapHeritage,
    Color? modeDayAccent,
    Color? onModeDayAccent,
    Color? modeNightAccent,
    Color? onModeNightAccent,
  }) {
    return LookUpColors(
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      provenanceLive: provenanceLive ?? this.provenanceLive,
      provenanceApprox: provenanceApprox ?? this.provenanceApprox,
      provenanceSample: provenanceSample ?? this.provenanceSample,
      provenanceStale: provenanceStale ?? this.provenanceStale,
      rating: rating ?? this.rating,
      ratingEmpty: ratingEmpty ?? this.ratingEmpty,
      hairline: hairline ?? this.hairline,
      mapScrim: mapScrim ?? this.mapScrim,
      birdAccent: birdAccent ?? this.birdAccent,
      starAccent: starAccent ?? this.starAccent,
      mapTrail: mapTrail ?? this.mapTrail,
      mapHeritage: mapHeritage ?? this.mapHeritage,
      modeDayAccent: modeDayAccent ?? this.modeDayAccent,
      onModeDayAccent: onModeDayAccent ?? this.onModeDayAccent,
      modeNightAccent: modeNightAccent ?? this.modeNightAccent,
      onModeNightAccent: onModeNightAccent ?? this.onModeNightAccent,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LookUpColors &&
        other.runtimeType == runtimeType &&
        other.warning == warning &&
        other.onWarning == onWarning &&
        other.warningContainer == warningContainer &&
        other.provenanceLive == provenanceLive &&
        other.provenanceApprox == provenanceApprox &&
        other.provenanceSample == provenanceSample &&
        other.provenanceStale == provenanceStale &&
        other.rating == rating &&
        other.ratingEmpty == ratingEmpty &&
        other.hairline == hairline &&
        other.mapScrim == mapScrim &&
        other.birdAccent == birdAccent &&
        other.starAccent == starAccent &&
        other.mapTrail == mapTrail &&
        other.mapHeritage == mapHeritage &&
        other.modeDayAccent == modeDayAccent &&
        other.onModeDayAccent == onModeDayAccent &&
        other.modeNightAccent == modeNightAccent &&
        other.onModeNightAccent == onModeNightAccent;
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
        warning,
        onWarning,
        warningContainer,
        provenanceLive,
        provenanceApprox,
        provenanceSample,
        provenanceStale,
        rating,
        ratingEmpty,
        hairline,
        mapScrim,
        birdAccent,
        starAccent,
        mapTrail,
        mapHeritage,
        modeDayAccent,
        onModeDayAccent,
        modeNightAccent,
        onModeNightAccent,
      ]);

  /// Per-field [Color.lerp]; required because the day/night scene transition
  /// animates through `ThemeData.lerp`.
  @override
  LookUpColors lerp(covariant ThemeExtension<LookUpColors>? other, double t) {
    if (other is! LookUpColors) return this;
    return LookUpColors(
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer:
          Color.lerp(warningContainer, other.warningContainer, t)!,
      provenanceLive: Color.lerp(provenanceLive, other.provenanceLive, t)!,
      provenanceApprox:
          Color.lerp(provenanceApprox, other.provenanceApprox, t)!,
      provenanceSample:
          Color.lerp(provenanceSample, other.provenanceSample, t)!,
      provenanceStale: Color.lerp(provenanceStale, other.provenanceStale, t)!,
      rating: Color.lerp(rating, other.rating, t)!,
      ratingEmpty: Color.lerp(ratingEmpty, other.ratingEmpty, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      mapScrim: Color.lerp(mapScrim, other.mapScrim, t)!,
      birdAccent: Color.lerp(birdAccent, other.birdAccent, t)!,
      starAccent: Color.lerp(starAccent, other.starAccent, t)!,
      mapTrail: Color.lerp(mapTrail, other.mapTrail, t)!,
      mapHeritage: Color.lerp(mapHeritage, other.mapHeritage, t)!,
      modeDayAccent: Color.lerp(modeDayAccent, other.modeDayAccent, t)!,
      onModeDayAccent: Color.lerp(onModeDayAccent, other.onModeDayAccent, t)!,
      modeNightAccent: Color.lerp(modeNightAccent, other.modeNightAccent, t)!,
      onModeNightAccent:
          Color.lerp(onModeNightAccent, other.onModeNightAccent, t)!,
    );
  }
}
