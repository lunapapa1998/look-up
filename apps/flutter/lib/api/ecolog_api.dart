import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/observation.dart';

/// Thrown by [EcologApi] implementations when the server returns a non-2xx
/// response. [message] is the response body, or the `detail` field of a
/// JSON error body when present.
class EcologApiException implements Exception {
  final int statusCode;
  final String message;

  EcologApiException(this.statusCode, this.message);

  @override
  String toString() => 'EcologApiException($statusCode): $message';
}

/// Contract for the `/api` ecolog backend. JSON bodies, no auth.
abstract class EcologApi {
  Future<List<Observation>> listObservations({SpeciesType? speciesType});

  Future<Observation> getObservation(int id);

  Future<Observation> createObservation(ObservationCreate body);

  Future<Observation> updateObservation(int id, ObservationUpdate body);

  Future<void> deleteObservation(int id);

  Future<List<BadgeProgress>> listBadges();
}

/// HTTP implementation of [EcologApi] against a FastAPI-style backend.
class HttpEcologApi implements EcologApi {
  final String baseUrl;
  final http.Client client;

  HttpEcologApi(this.baseUrl, {http.Client? client})
      : client = client ?? http.Client();

  static const _headers = {'Content-Type': 'application/json'};

  Uri _uri(String path, [Map<String, String>? queryParameters]) {
    final uri = Uri.parse('$baseUrl$path');
    if (queryParameters == null || queryParameters.isEmpty) return uri;
    return uri.replace(queryParameters: queryParameters);
  }

  void _checkStatus(http.Response response, int expected) {
    if (response.statusCode == expected) return;
    var message = response.body;
    try {
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic> && decoded['detail'] is String) {
        message = decoded['detail'] as String;
      }
    } catch (_) {
      // Response body wasn't JSON; fall back to the raw body as the message.
    }
    throw EcologApiException(response.statusCode, message);
  }

  @override
  Future<List<Observation>> listObservations({SpeciesType? speciesType}) async {
    final uri = _uri(
      '/api/observations',
      speciesType != null ? {'speciesType': speciesType.toJson()} : null,
    );
    final response = await client.get(uri, headers: _headers);
    _checkStatus(response, 200);
    final data = json.decode(response.body) as List<dynamic>;
    return data
        .map((e) => Observation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Observation> getObservation(int id) async {
    final response =
        await client.get(_uri('/api/observations/$id'), headers: _headers);
    _checkStatus(response, 200);
    return Observation.fromJson(json.decode(response.body) as Map<String, dynamic>);
  }

  @override
  Future<Observation> createObservation(ObservationCreate body) async {
    final response = await client.post(
      _uri('/api/observations'),
      headers: _headers,
      body: json.encode(body.toJson()),
    );
    _checkStatus(response, 201);
    return Observation.fromJson(json.decode(response.body) as Map<String, dynamic>);
  }

  @override
  Future<Observation> updateObservation(int id, ObservationUpdate body) async {
    final response = await client.patch(
      _uri('/api/observations/$id'),
      headers: _headers,
      body: json.encode(body.toJson()),
    );
    _checkStatus(response, 200);
    return Observation.fromJson(json.decode(response.body) as Map<String, dynamic>);
  }

  @override
  Future<void> deleteObservation(int id) async {
    final response =
        await client.delete(_uri('/api/observations/$id'), headers: _headers);
    _checkStatus(response, 204);
  }

  @override
  Future<List<BadgeProgress>> listBadges() async {
    final response = await client.get(_uri('/api/badges'), headers: _headers);
    _checkStatus(response, 200);
    final data = json.decode(response.body) as List<dynamic>;
    return data
        .map((e) => BadgeProgress.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// In-memory implementation of [EcologApi] for widget/unit tests. No HTTP.
class FakeEcologApi implements EcologApi {
  final List<Observation> _observations = [];
  int _nextId;

  static final List<Badge> _badgeCatalog = [
    Badge(
      id: 'first_step',
      name: '첫 관찰',
      description: '첫 관찰 기록을 남겼어요',
      targetCount: 1,
    ),
    Badge(
      id: 'explorer',
      name: '탐험가',
      description: '총 5개의 관찰을 기록했어요',
      targetCount: 5,
    ),
    Badge(
      id: 'master',
      name: '관찰 마스터',
      description: '총 20개의 관찰을 기록했어요',
      targetCount: 20,
    ),
    Badge(
      id: 'bird_watcher',
      name: '새 관찰자',
      description: '새(bird) 관찰을 5회 기록했어요',
      targetCount: 5,
    ),
    Badge(
      id: 'star_gazer',
      name: '별 관찰자',
      description: '별(star) 관찰을 5회 기록했어요',
      targetCount: 5,
    ),
  ];

  FakeEcologApi({List<Observation>? seed}) : _nextId = 1 {
    if (seed != null) {
      _observations.addAll(seed);
      for (final o in seed) {
        if (o.id >= _nextId) _nextId = o.id + 1;
      }
    }
  }

  @override
  Future<List<Observation>> listObservations({SpeciesType? speciesType}) async {
    if (speciesType == null) return List.of(_observations);
    return _observations.where((o) => o.speciesType == speciesType).toList();
  }

  @override
  Future<Observation> getObservation(int id) async {
    for (final o in _observations) {
      if (o.id == id) return o;
    }
    throw EcologApiException(404, 'Observation $id not found');
  }

  @override
  Future<Observation> createObservation(ObservationCreate body) async {
    final now = DateTime.now().toUtc();
    final observation = Observation(
      id: _nextId++,
      speciesType: body.speciesType,
      speciesName: body.speciesName,
      note: body.note,
      photoUrl: body.photoUrl,
      observedAt: body.observedAt ?? now,
      lat: body.lat,
      lng: body.lng,
      createdAt: now,
    );
    _observations.add(observation);
    return observation;
  }

  @override
  Future<Observation> updateObservation(int id, ObservationUpdate body) async {
    final index = _observations.indexWhere((o) => o.id == id);
    if (index == -1) throw EcologApiException(404, 'Observation $id not found');
    final merged = {..._observations[index].toJson(), ...body.toJson()};
    final updated = Observation.fromJson(merged);
    _observations[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteObservation(int id) async {
    final index = _observations.indexWhere((o) => o.id == id);
    if (index == -1) throw EcologApiException(404, 'Observation $id not found');
    _observations.removeAt(index);
  }

  @override
  Future<List<BadgeProgress>> listBadges() async {
    return _badgeCatalog.map((badge) {
      final int count;
      switch (badge.id) {
        case 'bird_watcher':
          count = _observations
              .where((o) => o.speciesType == SpeciesType.bird)
              .length;
          break;
        case 'star_gazer':
          count = _observations
              .where((o) => o.speciesType == SpeciesType.star)
              .length;
          break;
        default:
          count = _observations.length;
      }
      return BadgeProgress(
        badge: badge,
        achieved: count >= badge.targetCount,
        currentCount: count,
      );
    }).toList();
  }
}
