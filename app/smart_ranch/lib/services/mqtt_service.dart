import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';

import '../config/app_config.dart';
import '../models/sensor_reading.dart';

/// Service that manages MQTT connection and provides real-time telemetry streams.
class MqttService extends ChangeNotifier {
  MqttClient? _client;
  bool _isConnected = false;
  String _statusMessage = 'Desconectado';
  StreamSubscription? _updateSub;

  // Latest readings per device
  final Map<String, SensorReading> _latestReadings = {};
  // History per device (last N readings for charts)
  final Map<String, List<SensorReading>> _readingHistory = {};
  static const int _maxHistoryPerDevice = 120; // ~10 min at 5s intervals

  // Streams
  final _telemetryController = StreamController<SensorReading>.broadcast();
  final _alertController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<SensorReading> get telemetryStream => _telemetryController.stream;
  Stream<Map<String, dynamic>> get alertStream => _alertController.stream;

  bool get isConnected => _isConnected;
  String get statusMessage => _statusMessage;
  Map<String, SensorReading> get latestReadings =>
      Map.unmodifiable(_latestReadings);
  Map<String, List<SensorReading>> get readingHistory =>
      Map.unmodifiable(_readingHistory);

  /// Connect to the MQTT broker.
  Future<void> connect({String? host, int? port}) async {
    final mqttHost = host ?? AppConfig.mqttHost;

    if (kIsWeb) {
      // Web: use WebSocket connection
      final wsPort = port ?? AppConfig.mqttPortWs;
      final wsUrl = 'ws://$mqttHost:$wsPort/ws';
      _client = MqttBrowserClient(wsUrl, 'smart_ranch_flutter_web');
    } else {
      // Mobile/Desktop: use TCP connection
      final tcpPort = port ?? AppConfig.mqttPortTcp;
      _client = MqttServerClient(mqttHost, 'smart_ranch_flutter_mobile');
      (_client as MqttServerClient).port = tcpPort;
    }

    _client!.logging(on: false);
    _client!.keepAlivePeriod = 30;
    _client!.autoReconnect = true;
    _client!.onConnected = _onConnected;
    _client!.onDisconnected = _onDisconnected;
    _client!.onAutoReconnect = _onAutoReconnect;
    _client!.onAutoReconnected = _onAutoReconnected;

    _statusMessage = 'Conectando a $mqttHost...';
    notifyListeners();

    try {
      final connMsg = MqttConnectMessage()
          .withClientIdentifier(
            'smart_ranch_${kIsWeb ? "web" : "app"}_${DateTime.now().millisecondsSinceEpoch}',
          )
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);
      _client!.connectionMessage = connMsg;

      await _client!.connect();
    } catch (e) {
      _statusMessage = 'Error: $e';
      _isConnected = false;
      notifyListeners();
    }
  }

  void _onConnected() {
    _isConnected = true;
    _statusMessage = 'Conectado ✅';
    notifyListeners();

    // Subscribe to all telemetry and alert topics
    _client!.subscribe(AppConfig.telemetryTopicPattern, MqttQos.atLeastOnce);
    _client!.subscribe(AppConfig.alertTopicPattern, MqttQos.atLeastOnce);

    // Listen for messages
    _updateSub?.cancel();
    _updateSub = _client!.updates!.listen(_onMessage);
  }

  void _onDisconnected() {
    _isConnected = false;
    _statusMessage = 'Desconectado';
    notifyListeners();
  }

  void _onAutoReconnect() {
    _statusMessage = 'Reconectando...';
    notifyListeners();
  }

  void _onAutoReconnected() {
    _statusMessage = 'Reconectado ✅';
    _isConnected = true;
    notifyListeners();
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final msg in messages) {
      final recMsg = msg.payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(
        recMsg.payload.message,
      );
      final topic = msg.topic;

      try {
        if (topic.endsWith('/telemetry')) {
          final reading = SensorReading.fromMqttJson(payload);
          _latestReadings[reading.deviceId] = reading;

          // Add to history
          _readingHistory.putIfAbsent(reading.deviceId, () => []);
          _readingHistory[reading.deviceId]!.add(reading);
          if (_readingHistory[reading.deviceId]!.length >
              _maxHistoryPerDevice) {
            _readingHistory[reading.deviceId]!.removeAt(0);
          }

          _telemetryController.add(reading);
          notifyListeners();
        } else if (topic.endsWith('/alert')) {
          final alertData = json.decode(payload) as Map<String, dynamic>;
          _alertController.add(alertData);
        }
      } catch (e) {
        debugPrint('Error parsing MQTT message: $e');
      }
    }
  }

  /// Disconnect from the MQTT broker.
  void disconnect() {
    _client?.disconnect();
    _isConnected = false;
    _statusMessage = 'Desconectado';
    notifyListeners();
  }

  @override
  void dispose() {
    _updateSub?.cancel();
    _telemetryController.close();
    _alertController.close();
    disconnect();
    super.dispose();
  }
}