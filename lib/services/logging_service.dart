import 'package:logger/logger.dart';

class LoggerService {
  LoggerService._();

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      dateTimeFormat: DateTimeFormat.dateAndTime,
    ),
  );

  static Logger get logger => _logger;

  static void d(String message) => _logger.d(message);

  static void i(String message) => _logger.i(message);

  static void w(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.w(message, error: error, stackTrace: stackTrace);

  static void e(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.e(message, error: error, stackTrace: stackTrace);
}
