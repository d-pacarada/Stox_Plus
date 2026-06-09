// lib/config/api_config.dart
class ApiConfig {
  // ✅ SET THIS: true = physical phone, false = emulator
  static const bool usePhysicalDevice = true;

  // ✅ SET THIS: your PC's WiFi IP (run 'ipconfig' in terminal)
  static const String pcIp = '192.168.20.46'; // replace with your actual IP

  static const String _emulatorUrl = 'http://10.0.2.2:5115/api';
  static const String _deviceUrl = 'http://$pcIp:5115/api';

  static const String baseUrl = usePhysicalDevice ? _deviceUrl : _emulatorUrl;
}