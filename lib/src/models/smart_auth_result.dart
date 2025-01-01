/// The state of the result returned from SmartAuth methods
enum SmartAuthResultState {
  success,
  failure,
  canceled,
}

/// The result returned from SmartAuth methods
class SmartAuthResult<T> {
  const SmartAuthResult.success(this.data)
      : _state = SmartAuthResultState.success,
        error = null;

  const SmartAuthResult.failure(this.error)
      : _state = SmartAuthResultState.failure,
        data = null;

  const SmartAuthResult.canceled()
      : _state = SmartAuthResultState.canceled,
        error = null,
        data = null;

  /// The state of the result
  final SmartAuthResultState _state;

  /// The data object if [state] is [SmartAuthResultState.success]
  final T? data;

  /// The error object if [state] is [SmartAuthResultState.failure]
  final Object? error;

  /// Returns latest data received, failing if there is no data.
  ///
  /// Throws [error], if [hasError]. Throws [StateError], if neither [hasData]
  /// nor [hasError].
  T get requireData {
    if (hasData) {
      return data!;
    }
    if (hasError) {
      Error.throwWithStackTrace(error!, StackTrace.current);
    }
    throw StateError('Snapshot has neither data nor error');
  }

  /// Returns whether result contains a non-null [data] value.
  bool get hasData => data != null;

  /// Returns whether result contains a non-null [error] value.
  bool get hasError => error != null;

  /// Returns whether user canceled the operation.
  bool get isCanceled => _state == SmartAuthResultState.canceled;

  @override
  String toString() {
    return 'SmartAuthResult{state: $_state, data: $data, error: $error}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SmartAuthResult &&
          runtimeType == other.runtimeType &&
          _state == other._state &&
          data == other.data &&
          error == other.error;

  @override
  int get hashCode => _state.hashCode ^ data.hashCode ^ error.hashCode;
}