import 'dart:async';

/// Fired whenever a P2P order changes — either a `p2p_order` push
/// notification arriving in the foreground (see
/// PushNotificationService._handleForegroundMessage) or, now, a live
/// order.updated event from P2pSocketService's Reverb connection. P2P
/// screens listen on this to refresh themselves the moment an order
/// changes, instead of relying on pull-to-refresh or blind timers.
class P2pOrderPushEvent {
  final String? orderId;

  const P2pOrderPushEvent(this.orderId);
}

class P2pEventBus {
  P2pEventBus._();

  static final StreamController<P2pOrderPushEvent> _controller =
      StreamController<P2pOrderPushEvent>.broadcast();

  static Stream<P2pOrderPushEvent> get stream => _controller.stream;

  static void emit(P2pOrderPushEvent event) => _controller.add(event);
}
