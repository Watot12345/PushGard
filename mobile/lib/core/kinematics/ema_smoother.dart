/// Exponential Moving Average (EMA) smoother used identically by the mobile client
/// and the server validator on raw angle series.
///
/// Formula:
///   S_0 = X_0
///   S_t = alpha * X_t + (1 - alpha) * S_{t-1}
class EmaSmoother {
  final double alpha;
  double? _currentValue;

  EmaSmoother({required this.alpha})
      : assert(alpha > 0.0 && alpha <= 1.0, 'ema_alpha must be in (0, 1]');

  double? get currentValue => _currentValue;

  double addSample(double rawValue) {
    if (_currentValue == null) {
      _currentValue = rawValue;
    } else {
      _currentValue = alpha * rawValue + (1.0 - alpha) * _currentValue!;
    }
    return _currentValue!;
  }

  void reset() {
    _currentValue = null;
  }
}
