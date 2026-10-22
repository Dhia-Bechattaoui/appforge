import 'package:flutter/foundation.dart';

/// Represents a discrete, type-safe UI state machine.
///
/// Prevents the "boolean flag soup" anti-pattern (multiple independent flags like
/// `isLoading`, `hasError`, `isSuccess`) which lead to invalid and conflicting UI states.
@immutable
sealed class UiState<T> {
  const UiState();

  /// Initial idle state before an operation starts.
  const factory UiState.idle() = UiIdle<T>;

  /// State indicating an ongoing asynchronous operation.
  const factory UiState.loading() = UiLoading<T>;

  /// State indicating a successfully resolved operation containing [data].
  const factory UiState.success(T data) = UiSuccess<T>;

  /// State indicating an error occurred with a user-facing [message] and optional [error].
  const factory UiState.failure(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) = UiFailure<T>;

  /// Whether the current state is [UiIdle].
  bool get isIdle => this is UiIdle<T>;

  /// Whether the current state is [UiLoading].
  bool get isLoading => this is UiLoading<T>;

  /// Whether the current state is [UiSuccess].
  bool get isSuccess => this is UiSuccess<T>;

  /// Whether the current state is [UiFailure].
  bool get isFailure => this is UiFailure<T>;

  /// Returns data if the state is [UiSuccess], otherwise null.
  T? get dataOrNull => switch (this) {
        UiSuccess<T>(data: final d) => d,
        _ => null,
      };

  /// Returns error message if the state is [UiFailure], otherwise null.
  String? get messageOrNull => switch (this) {
        UiFailure<T>(message: final m) => m,
        _ => null,
      };

  /// Exhaustive pattern-matching across all 4 discrete states.
  R when<R>({
    required R Function() idle,
    required R Function() loading,
    required R Function(T data) success,
    required R Function(String message, Object? error, StackTrace? stackTrace)
        failure,
  }) {
    return switch (this) {
      UiIdle<T>() => idle(),
      UiLoading<T>() => loading(),
      UiSuccess<T>(data: final d) => success(d),
      UiFailure<T>(message: final m, error: final err, stackTrace: final st) =>
        failure(m, err, st),
    };
  }

  /// Partial pattern-matching with fallback.
  R maybeWhen<R>({
    R Function()? idle,
    R Function()? loading,
    R Function(T data)? success,
    R Function(String message, Object? error, StackTrace? stackTrace)? failure,
    required R Function() orElse,
  }) {
    return switch (this) {
      UiIdle<T>() => idle != null ? idle() : orElse(),
      UiLoading<T>() => loading != null ? loading() : orElse(),
      UiSuccess<T>(data: final d) => success != null ? success(d) : orElse(),
      UiFailure<T>(message: final m, error: final err, stackTrace: final st) =>
        failure != null ? failure(m, err, st) : orElse(),
    };
  }
}

/// The initial state before any action is executed.
final class UiIdle<T> extends UiState<T> {
  const UiIdle();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is UiIdle<T>;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'UiState<$T>.idle()';
}

/// The loading state while an asynchronous operation is in flight.
final class UiLoading<T> extends UiState<T> {
  const UiLoading();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is UiLoading<T>;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'UiState<$T>.loading()';
}

/// The success state containing the payload [data].
final class UiSuccess<T> extends UiState<T> {
  final T data;

  const UiSuccess(this.data);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is UiSuccess<T> && other.data == data);

  @override
  int get hashCode => Object.hash(runtimeType, data);

  @override
  String toString() => 'UiState<$T>.success($data)';
}

/// The failure state containing error diagnostics and an optional [error] object.
final class UiFailure<T> extends UiState<T> {
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  const UiFailure(this.message, {this.error, this.stackTrace});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UiFailure<T> &&
          other.message == message &&
          other.error == error);

  @override
  int get hashCode => Object.hash(runtimeType, message, error);

  @override
  String toString() =>
      'UiState<$T>.failure(message: "$message"${error != null ? ', error: $error' : ''})';
}
