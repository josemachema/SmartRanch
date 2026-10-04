/// Configuration constants for the Smart Ranch app.
class AppConfig {
  // MQTT Broker
  static const String mqttHost = '192.168.1.100'; // Change to your broker IP
  static const int mqttPortTcp = 1883; // For mobile (TCP)
  static const int mqttPortWs = 9001; // For web (WebSocket)

  // REST API
  static const String apiBaseUrl = 'http://192.168.1.100:8000';

  // MQTT Topics
  static const String telemetryTopicPattern = 'ranch/+/telemetry';
  static const String alertTopicPattern = 'ranch/+/alert';
  static String telemetryTopic(String deviceId) => 'ranch/$deviceId/telemetry';
  static String alertTopic(String deviceId) => 'ranch/$deviceId/alert';
  static String commandTopic(String deviceId) => 'ranch/$deviceId/command';

  // THI Thresholds
  static const double thiNormal = 72.0;
  static const double thiAlert = 72.0;
  static const double thiDanger = 79.0;
  static const double thiEmergency = 89.0;

  // Firebase Realtime Database
  static const String firebaseRtdbUrl = 'https://smartranch-innova-default-rtdb.firebaseio.com';
  static const String firebaseTelemetryPath = '/telemetria/actual.json';

  // Update interval
  static const Duration chartUpdateInterval = Duration(seconds: 10);
}
