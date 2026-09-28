import 'package:firebase_core/firebase_core.dart';

/// Thrown when Firestore returns permission-denied. Do not auto-retry these.
class FirestorePermissionException implements Exception {
  FirestorePermissionException({
    this.message = 'Access denied — check your account or Firestore rules.',
    this.cause,
  });

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

abstract final class FirestoreErrors {
  static const permissionDeniedCode = 'permission-denied';

  static bool isPermissionDenied(Object? error) {
    if (error == null) return false;
    if (error is FirestorePermissionException) return true;
    if (error is FirebaseException) {
      return error.code == permissionDeniedCode;
    }
    return false;
  }

  /// True for transient failures where retry may help (not permission errors).
  static bool shouldRetry(Object? error) {
    if (error == null) return false;
    if (isPermissionDenied(error)) return false;
    if (error is FirebaseException) {
      return error.code == 'unavailable' ||
          error.code == 'deadline-exceeded' ||
          error.code == 'resource-exhausted';
    }
    return true;
  }

  static Exception toAppException(Object error, [StackTrace? stackTrace]) {
    if (isPermissionDenied(error)) {
      return FirestorePermissionException(cause: error);
    }
    if (error is Exception) return error;
    return Exception(error.toString());
  }

  static Future<T> guardFuture<T>(Future<T> future) async {
    try {
      return await future;
    } catch (e, st) {
      throw toAppException(e, st);
    }
  }

  static Stream<T> guardStream<T>(Stream<T> stream) {
    return stream.handleError((Object error, StackTrace stackTrace) {
      throw toAppException(error, stackTrace);
    });
  }
}
