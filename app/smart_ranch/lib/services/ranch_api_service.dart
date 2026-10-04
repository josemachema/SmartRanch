import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../models/ranch_models.dart';
import 'auth_service.dart';

/// Service for communicating with the PostgreSQL-backed REST API (v2 endpoints).
class RanchApiService {
  static final String _baseUrl = '${AppConfig.apiBaseUrl}/api/v2';

  static Map<String, String> get _headers => AuthService.authHeaders;

  static Future<Map<String, dynamic>> _get(String path,
      {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('$_baseUrl$path')
        .replace(queryParameters: queryParams);
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 3));
    if (response.statusCode >= 400) {
      throw Exception('API error ${response.statusCode}: ${response.body}');
    }
    return json.decode(response.body) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> _getList(String path,
      {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('$_baseUrl$path')
        .replace(queryParameters: queryParams);
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 3));
    if (response.statusCode >= 400) {
      throw Exception('API error ${response.statusCode}: ${response.body}');
    }
    return json.decode(response.body) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl$path'),
          headers: _headers,
          body: json.encode(body),
        )
        .timeout(const Duration(seconds: 3));
    if (response.statusCode >= 400) {
      throw Exception('API error ${response.statusCode}: ${response.body}');
    }
    return json.decode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> _put(
      String path, Map<String, dynamic> body) async {
    final response = await http
        .put(
          Uri.parse('$_baseUrl$path'),
          headers: _headers,
          body: json.encode(body),
        )
        .timeout(const Duration(seconds: 3));
    if (response.statusCode >= 400) {
      throw Exception('API error ${response.statusCode}: ${response.body}');
    }
    return json.decode(response.body) as Map<String, dynamic>;
  }

  static Future<void> _delete(String path) async {
    final response = await http
        .delete(Uri.parse('$_baseUrl$path'), headers: _headers)
        .timeout(const Duration(seconds: 3));
    if (response.statusCode >= 400) {
      throw Exception('API error ${response.statusCode}: ${response.body}');
    }
  }

  // ---- In-memory stores for offline/demo fallback ----
  static final List<Animal> _localAnimals = [];

  static void initDemoData() {
    _localAnimals.clear();
    _localAnimals.addAll([
      Animal(id: 1, name: 'Lupita', earTag: 'MX-0026-0001', deviceId: 'vaca_001', breed: 'Hereford', sex: 'female', category: 'vaca', status: 'active', weightKg: 420),
      Animal(id: 2, name: 'Estrella', earTag: 'MX-0026-0002', deviceId: 'vaca_002', breed: 'Angus', sex: 'female', category: 'vaca', status: 'active', weightKg: 380),
      Animal(id: 3, name: 'Canela', earTag: 'MX-0026-0003', deviceId: 'vaca_003', breed: 'Charolais', sex: 'female', category: 'vaca', status: 'active', weightKg: 350),
      Animal(id: 4, name: 'Luna', earTag: 'MX-0026-0004', deviceId: 'vaca_004', breed: 'Brahman', sex: 'female', category: 'vaca', status: 'active', weightKg: 450),
      Animal(id: 5, name: 'Valentina', earTag: 'MX-0026-0005', deviceId: 'vaca_005', breed: 'Simmental', sex: 'female', category: 'vaca', status: 'active', weightKg: 400),
    ]);
  }

  static void initCleanData() {
    _localAnimals.clear();
    _localMedical.clear();
    _localWeights.clear();
    _localReproductive.clear();
  }

  /// Initialize state for a newly registered real ranch account (Puerto Peñasco).
  static void initNewAccountRanch({
    required String ranchName,
    List<String>? initialDeviceIds,
  }) {
    initCleanData();

    if (initialDeviceIds != null && initialDeviceIds.isNotEmpty) {
      for (int i = 0; i < initialDeviceIds.length; i++) {
        final devId = initialDeviceIds[i];
        _localAnimals.add(
          Animal(
            id: i + 1,
            name: 'Vaca Collar ${i + 1}',
            earTag: 'MX-PP-${(i + 1).toString().padLeft(4, '0')}',
            deviceId: devId,
            breed: 'Brangus',
            sex: 'female',
            category: 'vaca',
            status: 'active',
            weightKg: 450,
          ),
        );
      }
    }
  }

  static final List<MedicalRecord> _localMedical = [
    MedicalRecord(id: 1, animalId: 1, recordType: 'vaccine', productName: 'Pasturela bovina', dose: '5ml IM', administeredBy: 'Dr. Ramírez', cost: 180.0, recordedAt: DateTime.now().subtract(const Duration(days: 15))),
    MedicalRecord(id: 2, animalId: 2, recordType: 'deworming', productName: 'Ivermectina 1%', dose: '10ml SC', administeredBy: 'Dr. Ramírez', cost: 95.0, recordedAt: DateTime.now().subtract(const Duration(days: 10))),
    MedicalRecord(id: 3, animalId: 3, recordType: 'treatment', productName: 'Penicilina + Estreptomicina', dose: '15ml IM', administeredBy: 'Juan', cost: 220.0, withdrawalDays: 30, recordedAt: DateTime.now().subtract(const Duration(days: 5))),
  ];

  static final List<WeightRecord> _localWeights = [
    WeightRecord(id: 1, animalId: 1, weightKg: 420, bodyConditionScore: 6, notes: 'Condición normal', recordedAt: DateTime.now()),
    WeightRecord(id: 2, animalId: 2, weightKg: 380, bodyConditionScore: 5, recordedAt: DateTime.now()),
    WeightRecord(id: 3, animalId: 3, weightKg: 350, bodyConditionScore: 7, recordedAt: DateTime.now()),
  ];

  static final List<ReproductiveEvent> _localReproductive = [
    ReproductiveEvent(
      id: 1, animalId: 1, eventType: 'heat_detected',
      notes: 'Actividad elevada detectada por sensor IoT',
      recordedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    ReproductiveEvent(
      id: 2, animalId: 1, eventType: 'artificial_insemination',
      bullOrSemen: 'Angus Premium #4521',
      notes: 'Inseminación a tiempo fijo (IA)',
      expectedBirthDate: DateTime.now().add(const Duration(days: 253)),
      recordedAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
    ReproductiveEvent(
      id: 3, animalId: 4, eventType: 'pregnancy_check',
      pregnancyConfirmed: true, bullOrSemen: 'Toro Canelo',
      notes: 'Palpación positiva (6 meses)',
      expectedBirthDate: DateTime.now().add(const Duration(days: 90)),
      recordedAt: DateTime.now().subtract(const Duration(days: 15)),
    ),
    ReproductiveEvent(
      id: 4, animalId: 2, eventType: 'birth',
      bullOrSemen: 'Brahman #231', calfId: 6,
      notes: 'Parto normal, becerro macho 32kg',
      recordedAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
    ReproductiveEvent(
      id: 5, animalId: 5, eventType: 'mating',
      bullOrSemen: 'Toro Negro',
      notes: 'Monta natural en potrero',
      expectedBirthDate: DateTime.now().add(const Duration(days: 238)),
      recordedAt: DateTime.now().subtract(const Duration(days: 45)),
    ),
  ];

  // ---- Dashboard ----

  static Future<DashboardStats> getDashboardStats() async {
    try {
      final data = await _get('/dashboard');
      return DashboardStats.fromJson(data);
    } catch (_) {
      return DashboardStats(
        totalActive: _localAnimals.where((a) => a.status == 'active').length,
        animalsByStatus: {'active': _localAnimals.where((a) => a.status == 'active').length},
        animalsByCategory: {
          'vaca': _localAnimals.where((a) => a.category == 'vaca').length,
          'becerro': _localAnimals.where((a) => a.category == 'becerro').length,
          'toro': _localAnimals.where((a) => a.category == 'toro').length,
        },
        upcomingMedical7d: 2,
        expectedBirths30d: 1,
        unacknowledgedAlerts: 3,
      );
    }
  }

  // ---- Animals ----

  static Future<List<Animal>> getAnimals({
    String? status,
    String? category,
    String? sex,
    String? search,
  }) async {
    try {
      final params = <String, String>{};
      if (status != null) params['status'] = status;
      if (category != null) params['category'] = category;
      if (sex != null) params['sex'] = sex;
      if (search != null) params['search'] = search;

      final list = await _getList('/animals', queryParams: params);
      return list
          .map((e) => Animal.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      var result = List<Animal>.from(_localAnimals);
      if (status != null) result = result.where((a) => a.status == status).toList();
      if (category != null) result = result.where((a) => a.category == category).toList();
      if (sex != null) result = result.where((a) => a.sex == sex).toList();
      return result;
    }
  }

  static Future<Animal> getAnimal(int id) async {
    try {
      final data = await _get('/animals/$id');
      return Animal.fromJson(data);
    } catch (_) {
      return _localAnimals.firstWhere((a) => a.id == id,
          orElse: () => _localAnimals.first);
    }
  }

  static Future<Animal> createAnimal(Map<String, dynamic> animalData) async {
    try {
      FirebaseFirestore.instance.collection('animals').add({
        'name': animalData['name'],
        'ear_tag': animalData['ear_tag'] ?? '',
        'device_id': animalData['device_id'],
        'breed': animalData['breed'] ?? 'Brangus',
        'sex': animalData['sex'] ?? 'female',
        'category': animalData['category'] ?? 'vaca',
        'status': animalData['status'] ?? 'active',
        'weight_kg': animalData['weight_kg'],
        'notes': animalData['notes'],
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Firestore add animal: $e');
    }

    try {
      final data = await _post('/animals', animalData);
      final animal = Animal.fromJson(data);
      _localAnimals.insert(0, animal);
      return animal;
    } catch (_) {
      final newAnimal = Animal(
        id: _localAnimals.length + 1,
        name: animalData['name'] ?? 'Nuevo Animal',
        earTag: animalData['ear_tag'] ?? '',
        deviceId: animalData['device_id'],
        breed: animalData['breed'] ?? 'Brangus',
        sex: animalData['sex'] ?? 'female',
        category: animalData['category'] ?? 'vaca',
        status: animalData['status'] ?? 'active',
        weightKg: animalData['weight_kg'] != null ? (animalData['weight_kg'] as num).toDouble() : null,
        notes: animalData['notes'],
        createdAt: DateTime.now(),
      );
      _localAnimals.insert(0, newAnimal);
      return newAnimal;
    }
  }

  static Future<Animal> updateAnimal(
      int id, Map<String, dynamic> updates) async {
    try {
      final data = await _put('/animals/$id', updates);
      return Animal.fromJson(data);
    } catch (_) {
      final idx = _localAnimals.indexWhere((a) => a.id == id);
      if (idx != -1) {
        final existing = _localAnimals[idx];
        final updated = Animal(
          id: existing.id,
          name: updates['name'] ?? existing.name,
          earTag: updates['ear_tag'] ?? existing.earTag,
          deviceId: updates['device_id'] ?? existing.deviceId,
          breed: updates['breed'] ?? existing.breed,
          sex: updates['sex'] ?? existing.sex,
          category: updates['category'] ?? existing.category,
          status: updates['status'] ?? existing.status,
          weightKg: updates['weight_kg'] != null ? (updates['weight_kg'] as num).toDouble() : existing.weightKg,
          notes: updates['notes'] ?? existing.notes,
        );
        _localAnimals[idx] = updated;
        return updated;
      }
      return _localAnimals.first;
    }
  }

  static Future<void> deleteAnimal(int id) async {
    try {
      await _delete('/animals/$id');
      _localAnimals.removeWhere((a) => a.id == id);
    } catch (e) {
      debugPrint('deleteAnimal API error: $e');
      if (AuthService.isDemoMode) {
        _localAnimals.removeWhere((a) => a.id == id);
      } else {
        rethrow;
      }
    }
  }

  static Future<Map<String, dynamic>> getAnimalFullProfile(int id) async {
    try {
      return await _get('/animals/$id/full');
    } catch (_) {
      final a = _localAnimals.firstWhere((x) => x.id == id, orElse: () => _localAnimals.first);
      return {'animal': a.toJson()};
    }
  }

  // ---- Medical Records ----

  static Future<List<MedicalRecord>> getMedicalRecords(
      {int? animalId, String? recordType}) async {
    try {
      final params = <String, String>{};
      if (animalId != null) params['animal_id'] = animalId.toString();
      if (recordType != null) params['record_type'] = recordType;

      final list = await _getList('/medical', queryParams: params);
      return list
          .map((e) => MedicalRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      var list = List<MedicalRecord>.from(_localMedical);
      if (animalId != null) list = list.where((m) => m.animalId == animalId).toList();
      if (recordType != null) list = list.where((m) => m.recordType == recordType).toList();
      return list;
    }
  }

  static Future<MedicalRecord> createMedicalRecord(
      Map<String, dynamic> data) async {
    try {
      final result = await _post('/medical', data);
      final record = MedicalRecord.fromJson(result);
      _localMedical.insert(0, record);
      return record;
    } catch (_) {
      final record = MedicalRecord(
        id: _localMedical.length + 1,
        animalId: data['animal_id'] ?? 1,
        recordType: data['record_type'] ?? 'vaccine',
        productName: data['product_name'] ?? 'Tratamiento',
        dose: data['dose'],
        administeredBy: data['administered_by'] ?? 'Administrador',
        cost: data['cost'] != null ? (data['cost'] as num).toDouble() : null,
        notes: data['notes'],
        recordedAt: DateTime.now(),
      );
      _localMedical.insert(0, record);
      return record;
    }
  }

  static Future<List<Map<String, dynamic>>> getUpcomingMedical(
      {int days = 7}) async {
    final list =
        await _getList('/medical/upcoming', queryParams: {'days': '$days'});
    return list.cast<Map<String, dynamic>>();
  }

  // ---- Reproductive Events ----

  static Future<List<ReproductiveEvent>> getReproductiveEvents(
      {int? animalId, String? eventType}) async {
    try {
      final params = <String, String>{};
      if (animalId != null) params['animal_id'] = animalId.toString();
      if (eventType != null) params['event_type'] = eventType;

      final list = await _getList('/reproductive', queryParams: params);
      return list
          .map((e) => ReproductiveEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      var list = List<ReproductiveEvent>.from(_localReproductive);
      if (animalId != null) list = list.where((r) => r.animalId == animalId).toList();
      if (eventType != null && eventType != 'all') list = list.where((r) => r.eventType == eventType).toList();
      return list;
    }
  }

  static Future<ReproductiveEvent> createReproductiveEvent(
      Map<String, dynamic> data) async {
    try {
      final result = await _post('/reproductive', data);
      final event = ReproductiveEvent.fromJson(result);
      _localReproductive.insert(0, event);
      return event;
    } catch (_) {
      final event = ReproductiveEvent(
        id: _localReproductive.length + 1,
        animalId: data['animal_id'] ?? 1,
        eventType: data['event_type'] ?? 'mating',
        bullOrSemen: data['bull_or_semen'],
        pregnancyConfirmed: data['pregnancy_confirmed'],
        expectedBirthDate: data['expected_birth_date'] != null
            ? (data['expected_birth_date'] is DateTime
                ? data['expected_birth_date']
                : DateTime.tryParse(data['expected_birth_date'].toString()))
            : null,
        calfId: data['calf_id'],
        notes: data['notes'],
        recordedAt: DateTime.now(),
      );
      _localReproductive.insert(0, event);
      return event;
    }
  }

  // ---- Weight Records ----

  static Future<List<WeightRecord>> getWeightRecords({int? animalId}) async {
    try {
      final params = <String, String>{};
      if (animalId != null) params['animal_id'] = animalId.toString();

      final list = await _getList('/weights', queryParams: params);
      return list
          .map((e) => WeightRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      var list = List<WeightRecord>.from(_localWeights);
      if (animalId != null) list = list.where((w) => w.animalId == animalId).toList();
      return list;
    }
  }

  static Future<WeightRecord> createWeightRecord(
      Map<String, dynamic> data) async {
    final aid = data['animal_id'] != null ? (data['animal_id'] as num).toInt() : 1;
    final w = data['weight_kg'] != null ? (data['weight_kg'] as num).toDouble() : 400.0;
    
    // Update local animal weight
    final aIdx = _localAnimals.indexWhere((a) => a.id == aid);
    if (aIdx != -1) {
      final existing = _localAnimals[aIdx];
      _localAnimals[aIdx] = Animal(
        id: existing.id,
        name: existing.name,
        earTag: existing.earTag,
        deviceId: existing.deviceId,
        breed: existing.breed,
        sex: existing.sex,
        category: existing.category,
        status: existing.status,
        weightKg: w,
        notes: existing.notes,
        createdAt: existing.createdAt,
      );
    }

    try {
      final result = await _post('/weights', data);
      final record = WeightRecord.fromJson(result);
      _localWeights.insert(0, record);
      return record;
    } catch (_) {
      final record = WeightRecord(
        id: _localWeights.length + 1,
        animalId: aid,
        weightKg: w,
        bodyConditionScore: data['body_condition_score'] != null ? (data['body_condition_score'] as num).toInt() : 5,
        notes: data['notes'],
        recordedAt: DateTime.now(),
      );
      _localWeights.insert(0, record);
      return record;
    }
  }

  static Future<Map<String, dynamic>> getGrowthCurve(int animalId) async {
    return await _get('/weights/$animalId/growth');
  }

  // ---- Alerts ----

  static Future<List<AlertLog>> getAlerts(
      {int? animalId, String? alertType, bool unacknowledged = false}) async {
    final params = <String, String>{};
    if (animalId != null) params['animal_id'] = animalId.toString();
    if (alertType != null) params['alert_type'] = alertType;
    if (unacknowledged) params['unacknowledged'] = 'true';

    final list = await _getList('/alerts', queryParams: params);
    return list
        .map((e) => AlertLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<AlertLog> acknowledgeAlert(int alertId, String by) async {
    final data =
        await _put('/alerts/$alertId/acknowledge', {'acknowledged_by': by});
    return AlertLog.fromJson(data);
  }

  // ---- GPS ----

  static Future<List<Map<String, dynamic>>> getCurrentPositions() async {
    final list = await _getList('/gps/current');
    return list.cast<Map<String, dynamic>>();
  }

  static Future<List<Map<String, dynamic>>> getGeofenceViolations() async {
    final list = await _getList('/gps/geofence-check');
    return list.cast<Map<String, dynamic>>();
  }

  // ---- Financial Events ----

  static Future<Map<String, dynamic>> createFinancialEvent(
      Map<String, dynamic> data) async {
    return await _post('/financial', data);
  }

  // ---- Feed Records ----

  static Future<Map<String, dynamic>> createFeedRecord(
      Map<String, dynamic> data) async {
    return await _post('/feed', data);
  }
}