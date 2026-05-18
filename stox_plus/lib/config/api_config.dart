class ApiConfig {

  // Set to true for emulator, false for real phone via USB

  static const bool useEmulator = true;



  static const String baseUrl = useEmulator

      ? 'http://10.0.2.2:5115/api'

      : 'http://10.0.2.2:5115/api';

}