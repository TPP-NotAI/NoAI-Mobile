/// Base exception class and typed exceptions for the app.
///
/// Provides consistent error handling with user-friendly messages.
library;

/// Error categories for grouping and handling.
enum ErrorCategory {
  network,
  auth,
  validation,
  permission,
  notFound,
  server,
  wallet,
  general,
}

/// Base exception class for all app-specific exceptions.
///
/// Provides consistent structure with user-friendly messages.
abstract class AppException implements Exception {
  /// Technical message for logging/debugging.
  final String message;

  /// User-friendly message for display in UI.
  final String userMessage;

  /// Original exception if this wraps another exception.
  final Object? originalException;

  /// Stack trace for debugging.
  final StackTrace? stackTrace;

  /// Error category for analytics/handling.
  ErrorCategory get category;

  const AppException({
    required this.message,
    required this.userMessage,
    this.originalException,
    this.stackTrace,
  });

  @override
  String toString() => userMessage;

  /// Technical string for logging.
  String toDebugString() => 'AppException($category): $message';
}

// ============ NETWORK ERRORS ============

/// Thrown when there's no internet connection or network request fails.
class NetworkException extends AppException {
  const NetworkException({
    String message = 'Network request failed',
    String userMessage = 'Please check your internet access and try again',
    Object? originalException,
    StackTrace? stackTrace,
  }) : super(
          message: message,
          userMessage: userMessage,
          originalException: originalException,
          stackTrace: stackTrace,
        );

  @override
  ErrorCategory get category => ErrorCategory.network;
}

/// Thrown when a request times out.
class AppTimeoutException extends AppException {
  const AppTimeoutException({
    String message = 'Request timed out',
    String userMessage = 'The request took too long. Please try again',
    Object? originalException,
    StackTrace? stackTrace,
  }) : super(
          message: message,
          userMessage: userMessage,
          originalException: originalException,
          stackTrace: stackTrace,
        );

  @override
  ErrorCategory get category => ErrorCategory.network;
}

// ============ AUTH ERRORS ============

/// Types of authentication errors.
enum AuthErrorType {
  invalidCredentials,
  emailNotConfirmed,
  userAlreadyExists,
  weakPassword,
  invalidEmail,
  sessionExpired,
  rateLimited,
  accountBanned,
  accountSuspended,
  unknown,
}

/// Thrown for authentication failures.
class AppAuthException extends AppException {
  final AuthErrorType type;

  const AppAuthException({
    required this.type,
    required super.message,
    required super.userMessage,
    super.originalException,
    super.stackTrace,
  });

  @override
  ErrorCategory get category => ErrorCategory.auth;

  /// Factory constructor for common auth errors.
  factory AppAuthException.invalidCredentials({Object? originalException}) {
    return AppAuthException(
      type: AuthErrorType.invalidCredentials,
      message: 'Invalid login credentials',
      userMessage: 'Invalid email or password',
      originalException: originalException,
    );
  }

  factory AppAuthException.emailNotConfirmed({Object? originalException}) {
    return AppAuthException(
      type: AuthErrorType.emailNotConfirmed,
      message: 'Email not confirmed',
      userMessage: 'Please verify your email before signing in',
      originalException: originalException,
    );
  }

  factory AppAuthException.userAlreadyExists({Object? originalException}) {
    return AppAuthException(
      type: AuthErrorType.userAlreadyExists,
      message: 'User already registered',
      userMessage: 'An account with this email already exists',
      originalException: originalException,
    );
  }

  factory AppAuthException.weakPassword({Object? originalException}) {
    return AppAuthException(
      type: AuthErrorType.weakPassword,
      message: 'Weak password',
      userMessage: 'Password must be at least 6 characters',
      originalException: originalException,
    );
  }

  factory AppAuthException.invalidEmail({Object? originalException}) {
    return AppAuthException(
      type: AuthErrorType.invalidEmail,
      message: 'Invalid email format',
      userMessage: 'Please enter a valid email address',
      originalException: originalException,
    );
  }

  factory AppAuthException.sessionExpired({Object? originalException}) {
    return AppAuthException(
      type: AuthErrorType.sessionExpired,
      message: 'Session expired',
      userMessage: 'Your session has expired. Please sign in again',
      originalException: originalException,
    );
  }

  factory AppAuthException.rateLimited({Object? originalException}) {
    return AppAuthException(
      type: AuthErrorType.rateLimited,
      message: 'Rate limited',
      userMessage: 'Too many attempts. Please try again later',
      originalException: originalException,
    );
  }

  factory AppAuthException.accountBanned({Object? originalException}) {
    return AppAuthException(
      type: AuthErrorType.accountBanned,
      message: 'Account banned',
      userMessage: 'Your account has been banned. Please contact support',
      originalException: originalException,
    );
  }

  factory AppAuthException.accountSuspended({Object? originalException}) {
    return AppAuthException(
      type: AuthErrorType.accountSuspended,
      message: 'Account suspended',
      userMessage: 'Your account has been suspended. Please contact support',
      originalException: originalException,
    );
  }
}

// ============ VALIDATION ERRORS ============

/// Thrown for client-side validation failures.
class ValidationException extends AppException {
  /// The field that failed validation (optional).
  final String? field;

  const ValidationException({
    required super.message,
    required super.userMessage,
    this.field,
    super.originalException,
    super.stackTrace,
  });

  @override
  ErrorCategory get category => ErrorCategory.validation;

  /// Factory for duplicate username.
  factory ValidationException.duplicateUsername({Object? originalException}) {
    return ValidationException(
      message: 'Duplicate username',
      userMessage: 'This username is already taken',
      field: 'username',
      originalException: originalException,
    );
  }

  /// Factory for duplicate email.
  factory ValidationException.duplicateEmail({Object? originalException}) {
    return ValidationException(
      message: 'Duplicate email',
      userMessage: 'This email is already registered',
      field: 'email',
      originalException: originalException,
    );
  }

  /// Factory for required field.
  factory ValidationException.required(String fieldName) {
    return ValidationException(
      message: 'Required field: $fieldName',
      userMessage: 'Please enter your $fieldName',
      field: fieldName,
    );
  }

  /// Factory for invalid format.
  factory ValidationException.invalidFormat(String fieldName) {
    return ValidationException(
      message: 'Invalid format: $fieldName',
      userMessage: 'Please enter a valid $fieldName',
      field: fieldName,
    );
  }
}

// ============ PERMISSION ERRORS ============

/// Thrown when user lacks permission for an action.
class PermissionException extends AppException {
  const PermissionException({
    required super.message,
    String userMessage = "You don't have permission to perform this action",
    super.originalException,
    super.stackTrace,
  }) : super(userMessage: userMessage);

  @override
  ErrorCategory get category => ErrorCategory.permission;

  /// Factory for KYC verification required.
  factory PermissionException.kycRequired() {
    return const PermissionException(
      message: 'KYC verification required',
      userMessage:
          'Please complete human verification to perform this action',
    );
  }

  /// Factory for self-action error.
  factory PermissionException.selfAction(String action) {
    return PermissionException(
      message: 'Cannot $action yourself',
      userMessage: 'You cannot $action yourself',
    );
  }
}

// ============ NOT FOUND ERRORS ============

/// Thrown when a requested resource doesn't exist.
class NotFoundException extends AppException {
  /// The type of resource that wasn't found.
  final String resourceType;

  const NotFoundException({
    required this.resourceType,
    String? message,
    String? userMessage,
    super.originalException,
    super.stackTrace,
  }) : super(
          message: message ?? '$resourceType not found',
          userMessage:
              userMessage ?? 'The requested $resourceType could not be found',
        );

  @override
  ErrorCategory get category => ErrorCategory.notFound;

  /// Factory for post not found.
  factory NotFoundException.post() {
    return const NotFoundException(resourceType: 'post');
  }

  /// Factory for user not found.
  factory NotFoundException.user() {
    return const NotFoundException(resourceType: 'user');
  }

  /// Factory for comment not found.
  factory NotFoundException.comment() {
    return const NotFoundException(resourceType: 'comment');
  }
}

// ============ SERVER ERRORS ============

/// Thrown for server-side errors (5xx).
class ServerException extends AppException {
  /// HTTP status code if available.
  final int? statusCode;

  const ServerException({
    this.statusCode,
    String message = 'Server error',
    String userMessage = 'Something went wrong on our end. Please try again later',
    super.originalException,
    super.stackTrace,
  }) : super(message: message, userMessage: userMessage);

  @override
  ErrorCategory get category => ErrorCategory.server;
}

// ============ WALLET ERRORS ============

/// Types of wallet errors.
enum WalletErrorType {
  insufficientBalance,
  walletFrozen,
  dailyLimitExceeded,
  invalidAddress,
  privateKeyNotFound,
  transferFailed,
  walletNotActivated,
  networkOffline,
}

/// Thrown for wallet/Roocoin related errors.
class WalletException extends AppException {
  final WalletErrorType type;

  const WalletException({
    required this.type,
    required super.message,
    required super.userMessage,
    super.originalException,
    super.stackTrace,
  });

  @override
  ErrorCategory get category => ErrorCategory.wallet;

  /// Factory for insufficient balance.
  factory WalletException.insufficientBalance() {
    return const WalletException(
      type: WalletErrorType.insufficientBalance,
      message: 'Insufficient balance',
      userMessage: "You don't have enough ROO for this transaction",
    );
  }

  /// Factory for frozen wallet.
  factory WalletException.frozen({String? reason}) {
    return WalletException(
      type: WalletErrorType.walletFrozen,
      message: 'Wallet frozen: ${reason ?? 'unknown reason'}',
      userMessage: 'Your wallet has been frozen. Please contact support',
    );
  }

  /// Factory for daily limit exceeded.
  factory WalletException.dailyLimitExceeded() {
    return const WalletException(
      type: WalletErrorType.dailyLimitExceeded,
      message: 'Daily transfer limit exceeded',
      userMessage:
          "You've reached your daily transfer limit. Try again tomorrow",
    );
  }

  /// Factory for invalid address.
  factory WalletException.invalidAddress() {
    return const WalletException(
      type: WalletErrorType.invalidAddress,
      message: 'Invalid wallet address',
      userMessage: 'The wallet address is invalid',
    );
  }

  /// Factory for private key not found.
  factory WalletException.privateKeyNotFound() {
    return const WalletException(
      type: WalletErrorType.privateKeyNotFound,
      message: 'Private key not found',
      userMessage:
          'Wallet configuration error. Please try signing out and back in',
    );
  }

  /// Factory for network offline.
  factory WalletException.networkOffline() {
    return const WalletException(
      type: WalletErrorType.networkOffline,
      message: 'Network offline',
      userMessage: 'You are offline. Connect to activate your wallet',
    );
  }

  /// Factory for recipient wallet not activated.
  factory WalletException.recipientNotActivated() {
    return const WalletException(
      type: WalletErrorType.walletNotActivated,
      message: 'Recipient wallet not activated',
      userMessage: 'The recipient wallet has not been activated yet',
    );
  }
}

// ============ GENERAL ERRORS ============

/// Generic app exception for uncategorized errors.
class GeneralException extends AppException {
  const GeneralException({
    String message = 'An unexpected error occurred',
    String userMessage = 'Something went wrong. Please try again',
    super.originalException,
    super.stackTrace,
  }) : super(message: message, userMessage: userMessage);

  @override
  ErrorCategory get category => ErrorCategory.general;
}
