import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/utils/constants.dart';
import 'auth_service.dart';
import 'p2p_event_bus.dart';

/// Tag every line so `adb logcat` / the run console can be filtered with
/// `flutter logs | grep P2pSocket` — this is genuinely the only way to see
/// what this connection is doing on a real device, since there's no UI
/// indicator for it (yet).
const _tag = '[P2pSocket]';

/// A minimal hand-rolled Pusher-protocol client talking directly to
/// Eziplug's own Laravel Reverb server — deliberately not the official
/// `pusher_channels_flutter` plugin, whose versions new enough to point at a
/// self-hosted host/port pull in a `js` package version that conflicts with
/// `flutter_secure_storage` already used across the app. Reverb speaks the
/// same wire protocol Pusher does, and that protocol is simple enough
/// (connect, subscribe with an auth signature, listen, ping/pong) that a
/// plain WebSocket client covers it without the native-plugin dependency risk.
///
/// Every P2P screen that wants live order updates calls [acquire] in
/// initState and [release] in dispose; the socket connects once on the first
/// caller and disconnects once the last one goes away, rather than every
/// screen managing its own connection. Every order-status change it hears
/// about is republished onto [P2pEventBus] — the exact same bus the old
/// polling/follow-up-timer code fed — so no P2P screen needed to change how
/// it listens for refreshes, only where those refreshes come from.
class P2pSocketService {
  P2pSocketService._();

  static final P2pSocketService instance = P2pSocketService._();

  WebSocketChannel? _channel;
  StreamSubscription? _streamSub;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  String? _socketId;
  AuthService? _authService;
  int _refCount = 0;
  int _reconnectAttempt = 0;

  static const _channelPrefix = 'private-p2p-orders.';
  static const _reconnectDelaysSeconds = [2, 5, 10, 20, 30];

  void acquire(AuthService authService) {
    _refCount++;
    debugPrint('$_tag acquire() -> refCount=$_refCount');
    if (_refCount == 1) {
      _authService = authService;
      _reconnectAttempt = 0;
      _connect();
    }
  }

  void release() {
    if (_refCount == 0) return;
    _refCount--;
    debugPrint('$_tag release() -> refCount=$_refCount');
    if (_refCount == 0) _disconnect();
  }

  void _connect() {
    final uri = Uri(
      scheme: Constants.reverbUseTLS ? 'wss' : 'ws',
      host: Constants.reverbHost,
      port: Constants.reverbPort,
      path: '/app/${Constants.reverbKey}',
      queryParameters: const {
        'protocol': '7',
        'client': 'eziplug-flutter',
        'version': '1.0',
        'flash': 'false',
      },
    );

    debugPrint('$_tag connecting to $uri ...');

    try {
      _channel = WebSocketChannel.connect(uri);
    } catch (e) {
      debugPrint('$_tag connect() threw synchronously: $e');
      _scheduleReconnect();
      return;
    }

    _streamSub = _channel!.stream.listen(
      _handleMessage,
      onDone: () {
        debugPrint('$_tag connection closed');
        _handleDisconnect();
      },
      onError: (e) {
        debugPrint('$_tag stream error: $e');
        _handleDisconnect();
      },
      cancelOnError: true,
    );
  }

  void _handleMessage(dynamic raw) {
    try {
      final message = jsonDecode(raw as String) as Map<String, dynamic>;
      final event = message['event'] as String?;
      final rawData = message['data'];
      final data = rawData is String
          ? (jsonDecode(rawData) as Map<String, dynamic>)
          : (rawData is Map ? Map<String, dynamic>.from(rawData) : const {});

      switch (event) {
        case 'pusher:connection_established':
          _socketId = data['socket_id']?.toString();
          debugPrint('$_tag connected, socket_id=$_socketId');
          _reconnectAttempt = 0;
          _startPing();
          _subscribe();
          break;
        case 'pusher:ping':
          _send({'event': 'pusher:pong', 'data': {}});
          break;
        case 'pusher:error':
          // Reverb sends this for a bad/expired auth signature among other
          // things — nothing to recover from mid-connection beyond letting
          // the normal disconnect/reconnect cycle re-authorize from scratch.
          debugPrint('$_tag pusher:error received: $data');
          break;
        case 'pusher_internal:subscription_succeeded':
          debugPrint('$_tag subscribed successfully');
          break;
        case 'order.updated':
          debugPrint('$_tag order.updated received: $data');
          P2pEventBus.emit(P2pOrderPushEvent(data['id']?.toString()));
          break;
      }
    } catch (e) {
      // A malformed frame shouldn't take the whole connection down — the
      // worst case is one missed push, and the next refresh (pull-to-refresh,
      // app resume, or the next broadcast) catches up regardless.
      debugPrint('$_tag failed to handle message: $e — raw: $raw');
    }
  }

  Future<void> _subscribe() async {
    final authService = _authService;
    final socketId = _socketId;
    final userId = authService?.userId;
    if (authService == null || socketId == null || userId == null) {
      debugPrint(
        '$_tag cannot subscribe — authService=${authService != null} '
        'socketId=$socketId userId=$userId (is AuthService.user populated yet?)',
      );
      return;
    }

    final channelName = '$_channelPrefix$userId';
    debugPrint('$_tag authorizing for $channelName ...');
    final auth = await _authorize(authService, channelName, socketId);
    if (auth == null) {
      debugPrint('$_tag authorization failed — not subscribing to $channelName');
      return;
    }

    debugPrint('$_tag sending pusher:subscribe for $channelName');
    _send({
      'event': 'pusher:subscribe',
      'data': {'channel': channelName, 'auth': auth},
    });
  }

  /// Hits Laravel's own /broadcasting/auth endpoint (routes/channels.php)
  /// with the same bearer token every other API call uses — Reverb itself
  /// never sees or checks that token, it only trusts the signature this
  /// endpoint hands back proving the backend already authorized this user
  /// for this exact channel + socket.
  Future<String?> _authorize(AuthService authService, String channelName, String socketId) async {
    final token = await authService.getToken();
    if (token == null) {
      debugPrint('$_tag no auth token available — cannot authorize');
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse(Constants.broadcastAuthUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: {'socket_id': socketId, 'channel_name': channelName},
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['auth']?.toString();
      }
      debugPrint('$_tag ${Constants.broadcastAuthUrl} returned ${response.statusCode}: ${response.body}');
    } catch (e) {
      // Left null — _subscribe() simply won't send pusher:subscribe, and the
      // next reconnect attempt (or the next time a screen calls acquire())
      // tries the whole handshake again.
      debugPrint('$_tag request to ${Constants.broadcastAuthUrl} failed: $e');
    }
    return null;
  }

  void _send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  void _startPing() {
    _pingTimer?.cancel();
    // Well under Reverb's own 60s default activity_timeout so the server
    // never has a reason to consider this connection dead.
    _pingTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _send({'event': 'pusher:ping', 'data': {}}),
    );
  }

  void _handleDisconnect() {
    _pingTimer?.cancel();
    _socketId = null;
    _streamSub?.cancel();
    _streamSub = null;
    _channel = null;
    if (_refCount > 0) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final delay = _reconnectDelaysSeconds[
        _reconnectAttempt.clamp(0, _reconnectDelaysSeconds.length - 1)];
    _reconnectAttempt++;
    debugPrint('$_tag reconnecting in ${delay}s (attempt $_reconnectAttempt)');
    _reconnectTimer = Timer(Duration(seconds: delay), () {
      if (_refCount > 0) _connect();
    });
  }

  void _disconnect() {
    debugPrint('$_tag disconnecting (refCount=0)');
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _streamSub?.cancel();
    _streamSub = null;
    _channel?.sink.close();
    _channel = null;
    _socketId = null;
    _authService = null;
  }
}
