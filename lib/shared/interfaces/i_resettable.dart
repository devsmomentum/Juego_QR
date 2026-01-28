/// Interface for objects that need to reset their state.
/// This is typically used by Providers to clear session data on logout.
abstract class IResettable {
  /// Resets the internal state of the object to its initial values.
  /// Must call notifyListeners() if it extends ChangeNotifier.
  void resetState();
}
