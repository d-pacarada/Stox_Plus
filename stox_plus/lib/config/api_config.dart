class ApiConfig {
  // Set to true for emulator, false for real phone via USB
  static const bool useEmulator = false;

  static const String baseUrl = useEmulator
      ? 'http://10.0.2.2:5115/api'
      : 'http://localhost:5115/api';
}