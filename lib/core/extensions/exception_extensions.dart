import '../errors/app_exception.dart';
import '../errors/error_mapper.dart';

/// Extension methods for easy exception conversion.
extension ExceptionExtensions on Object {
  /// Convert any exception to an [AppException].
  ///
  /// Usage:
  /// ```dart
  /// catch (e, stack) {
  ///   throw e.toAppException(stack);
  /// }
  /// ```
  AppException toAppException([StackTrace? stackTrace]) {
    if (this is AppException) return this as AppException;
    return ErrorMapper.map(this, stackTrace);
  }

  /// Get user-friendly message from any exception.
  ///
  /// Usage:
  /// ```dart
  /// catch (e) {
  ///   _error = e.userMessage;
  /// }
  /// ```
  String get userMessage {
    if (this is AppException) return (this as AppException).userMessage;
    return ErrorMapper.map(this).userMessage;
  }

  /// Get the error category from any exception.
  ///
  /// Usage:
  /// ```dart
  /// catch (e) {
  ///   if (e.errorCategory == ErrorCategory.network) {
  ///     // Handle network error
  ///   }
  /// }
  /// ```
  ErrorCategory get errorCategory {
    if (this is AppException) return (this as AppException).category;
    return ErrorMapper.map(this).category;
  }
}
