import 'dart:developer' as developer;

class LoggerService {
  void info(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(message, level: 800, error: error, stackTrace: stackTrace);
  }

  void warning(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(message, level: 900, error: error, stackTrace: stackTrace);
  }

  void error(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(message, level: 1000, name: 'error', error: error, stackTrace: stackTrace);
  }

  void debug(String message) {
    developer.log(message, level: 500);
  }
}
