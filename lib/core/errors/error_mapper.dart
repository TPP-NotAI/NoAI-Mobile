import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'app_exception.dart';

/// Centralized error mapping from external exceptions to app exceptions.
///
/// Usage:
/// ```dart
/// try {
///   await someOperation();
/// } catch (e, stack) {
///   throw ErrorMapper.map(e, stack);
/// }
/// ```
class ErrorMapper {
  /// Map any exception to a typed [AppException].
  static AppException map(Object error, [StackTrace? stackTrace]) {
    // Already an AppException - return as-is
    if (error is AppException) {
      return error;
    }

    // Supabase Auth exceptions
    if (error is supabase.AuthException) {
      return _mapAuthException(error, stackTrace);
    }

    // Supabase Database exceptions
    if (error is supabase.PostgrestException) {
      return _mapPostgrestException(error, stackTrace);
    }

    // Dart standard exceptions
    if (error is TimeoutException) {
      return AppTimeoutException(
        message: error.message ?? 'Request timed out',
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    if (error is SocketException) {
      return NetworkException(
        message: error.message,
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    if (error is HttpException) {
      return NetworkException(
        message: error.message,
        userMessage: 'Network error. Please check your internet access',
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    if (error is FormatException) {
      return ValidationException(
        message: error.message,
        userMessage: 'Invalid format. Please check your input',
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    // Generic Exception with message - check for known patterns
    if (error is Exception) {
      return _mapGenericException(error, stackTrace);
    }

    // Fallback: wrap in GeneralException
    return GeneralException(
      message: error.toString(),
      originalException: error,
      stackTrace: stackTrace,
    );
  }

  /// Map Supabase AuthException to typed AppAuthException.
  static AppAuthException _mapAuthException(
    supabase.AuthException error,
    StackTrace? stackTrace,
  ) {
    final message = error.message.toLowerCase();

    if (message.contains('invalid login credentials') ||
        message.contains('invalid email or password')) {
      return AppAuthException(
        type: AuthErrorType.invalidCredentials,
        message: error.message,
        userMessage: 'Invalid email or password',
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    if (message.contains('email not confirmed')) {
      return AppAuthException(
        type: AuthErrorType.emailNotConfirmed,
        message: error.message,
        userMessage: 'Please verify your email before signing in',
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    if (message.contains('user already registered')) {
      return AppAuthException(
        type: AuthErrorType.userAlreadyExists,
        message: error.message,
        userMessage: 'An account with this email already exists',
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    if (message.contains('password')) {
      return AppAuthException(
        type: AuthErrorType.weakPassword,
        message: error.message,
        userMessage: 'Password must be at least 6 characters',
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    if (message.contains('invalid email') ||
        message.contains('email address is not valid')) {
      return AppAuthException(
        type: AuthErrorType.invalidEmail,
        message: error.message,
        userMessage: 'Please enter a valid email address',
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    if (message.contains('rate limit') ||
        message.contains('too many requests')) {
      return AppAuthException(
        type: AuthErrorType.rateLimited,
        message: error.message,
        userMessage: 'Too many attempts. Please try again later',
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    if (message.contains('session') ||
        message.contains('token') ||
        message.contains('expired')) {
      return AppAuthException(
        type: AuthErrorType.sessionExpired,
        message: error.message,
        userMessage: 'Your session has expired. Please sign in again',
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    // Fallback for unknown auth errors
    return AppAuthException(
      type: AuthErrorType.unknown,
      message: error.message,
      userMessage: 'Authentication failed. Please try again',
      originalException: error,
      stackTrace: stackTrace,
    );
  }

  /// Map Supabase PostgrestException to typed AppException.
  static AppException _mapPostgrestException(
    supabase.PostgrestException error,
    StackTrace? stackTrace,
  ) {
    final message = error.message.toLowerCase();
    final code = error.code;

    // Unique constraint violation (duplicate entry) - code 23505
    if (code == '23505' ||
        message.contains('duplicate') ||
        message.contains('unique constraint')) {
      if (message.contains('username')) {
        return ValidationException(
          message: error.message,
          userMessage: 'This username is already taken',
          field: 'username',
          originalException: error,
          stackTrace: stackTrace,
        );
      }

      if (message.contains('email')) {
        return ValidationException(
          message: error.message,
          userMessage: 'This email is already registered',
          field: 'email',
          originalException: error,
          stackTrace: stackTrace,
        );
      }

      return ValidationException(
        message: error.message,
        userMessage: 'This value already exists',
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    // Foreign key violation - code 23503
    if (code == '23503') {
      return NotFoundException(
        resourceType: 'resource',
        message: error.message,
        userMessage: 'The referenced item no longer exists',
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    // Not null violation - code 23502
    if (code == '23502') {
      return ValidationException(
        message: error.message,
        userMessage: 'Required information is missing',
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    // RLS policy violation (permission denied) - code 42501
    if (code == '42501' || message.contains('permission denied')) {
      return PermissionException(
        message: error.message,
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    // Row not found - code PGRST116
    if (message.contains('no rows') || code == 'PGRST116') {
      return NotFoundException(
        resourceType: 'item',
        message: error.message,
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    // Fallback for other database errors
    return ServerException(
      message: error.message,
      userMessage: 'Database error. Please try again',
      originalException: error,
      stackTrace: stackTrace,
    );
  }

  /// Map generic Exception based on message patterns.
  static AppException _mapGenericException(
    Exception error,
    StackTrace? stackTrace,
  ) {
    final message = error.toString();
    final lowerMessage = message.toLowerCase();

    // Wallet/Balance errors
    if (_isInsufficientBalance(lowerMessage)) {
      return WalletException.insufficientBalance();
    }

    if (_isWalletFrozen(lowerMessage)) {
      return WalletException.frozen();
    }

    if (_isDailyLimitExceeded(lowerMessage)) {
      return WalletException.dailyLimitExceeded();
    }

    if (_isPrivateKeyNotFound(lowerMessage)) {
      return WalletException.privateKeyNotFound();
    }

    if (_isInvalidAddress(lowerMessage)) {
      return WalletException.invalidAddress();
    }

    if (_isRecipientNotActivated(lowerMessage)) {
      return WalletException.recipientNotActivated();
    }

    // Network errors
    if (_isNetworkError(lowerMessage)) {
      return NetworkException(
        message: message,
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    // Not authenticated
    if (lowerMessage.contains('not authenticated') ||
        lowerMessage.contains('unauthorized')) {
      return AppAuthException.sessionExpired(originalException: error);
    }

    // Permission errors
    if (lowerMessage.contains('permission') ||
        lowerMessage.contains('forbidden')) {
      return PermissionException(
        message: message,
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    // Self-action errors
    if (lowerMessage.contains('cannot') &&
        lowerMessage.contains('yourself')) {
      final action = _extractSelfAction(lowerMessage);
      return PermissionException.selfAction(action);
    }

    // Clean up the message for display
    final cleanMessage = _cleanExceptionMessage(message);

    return GeneralException(
      message: message,
      userMessage: cleanMessage,
      originalException: error,
      stackTrace: stackTrace,
    );
  }

  // ============ Helper Methods ============

  static bool _isInsufficientBalance(String message) {
    return message.contains('insufficient balance') ||
        message.contains('insufficient funds') ||
        message.contains('not enough');
  }

  static bool _isWalletFrozen(String message) {
    return message.contains('wallet') && message.contains('frozen');
  }

  static bool _isDailyLimitExceeded(String message) {
    return message.contains('daily') && message.contains('limit');
  }

  static bool _isPrivateKeyNotFound(String message) {
    return message.contains('private key not found');
  }

  static bool _isInvalidAddress(String message) {
    return message.contains('invalid') &&
        (message.contains('address') || message.contains('wallet address'));
  }

  static bool _isRecipientNotActivated(String message) {
    return message.contains('recipient') &&
        (message.contains('not activated') || message.contains('pending'));
  }

  static bool _isNetworkError(String message) {
    return message.contains('network') ||
        message.contains('connection') ||
        message.contains('socket') ||
        message.contains('timeout') ||
        message.contains('unreachable') ||
        message.contains('offline');
  }

  static String _extractSelfAction(String message) {
    // Try to extract the action from "cannot X yourself"
    final patterns = ['follow', 'block', 'mute', 'report', 'message'];
    for (final pattern in patterns) {
      if (message.contains(pattern)) {
        return pattern;
      }
    }
    return 'do this to';
  }

  /// Clean up exception message for user display.
  static String _cleanExceptionMessage(String message) {
    var clean = message
        .replaceAll('Exception: ', '')
        .replaceAll('exception: ', '')
        .replaceAll(RegExp(r'^Error:\s*', caseSensitive: false), '')
        .trim();

    // Capitalize first letter
    if (clean.isNotEmpty) {
      clean = clean[0].toUpperCase() + clean.substring(1);
    }

    // Ensure it ends with proper punctuation
    if (clean.isNotEmpty &&
        !clean.endsWith('.') &&
        !clean.endsWith('!') &&
        !clean.endsWith('?')) {
      clean = '$clean.';
    }

    // If the message is too technical, use a generic one
    if (_isTooTechnical(clean)) {
      return 'Something went wrong. Please try again';
    }

    return clean;
  }

  /// Check if a message is too technical for users.
  static bool _isTooTechnical(String message) {
    final technicalPatterns = [
      'stacktrace',
      'null pointer',
      'type cast',
      'assertion failed',
      'unhandled',
      '()',
      '[]',
      '{}',
      'instance of',
      'closure',
      'widget',
      'render',
      'setState',
    ];

    final lower = message.toLowerCase();
    for (final pattern in technicalPatterns) {
      if (lower.contains(pattern)) {
        return true;
      }
    }
    return false;
  }
}
