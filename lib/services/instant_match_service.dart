import 'dart:async';
import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/services/user.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

enum MatchState { idle, searching, chatting, ended }

class InstantMatchService {
  static final InstantMatchService _instance = InstantMatchService._internal();
  factory InstantMatchService() => _instance;
  InstantMatchService._internal();

  IO.Socket? socket;
  MatchState state = MatchState.idle;
  String? roomId;
  Map<String, dynamic>? partnerProfile;
  String? partnerAlias;
  String? partnerId;

  final _stateController = StreamController<MatchState>.broadcast();
  Stream<MatchState> get stateStream => _stateController.stream;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;

  final _readStatusController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get readStatusStream => _readStatusController.stream;

  void init() async {
    if (socket != null && socket!.connected) return;

    String? token = await UserService.getAccessToken();
    String? baseUrl = AppVariables.get<String>('baseurl');
    
    if (baseUrl == null || token == null) return;

    // Use the full baseUrl. Socket.IO will append /socket.io/ by default.
    String socketUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

    socket = IO.io(socketUrl, IO.OptionBuilder()
        .setTransports(['websocket'])
        .setAuth({'token': token})
        .enableAutoConnect()
        .build());

    socket!.onConnect((_) {
      print('Connected to Match Server');
    });

    socket!.onDisconnect((_) {
      print('Disconnected from Match Server');
      _updateState(MatchState.idle);
    });

    socket!.on('searching', (_) {
      _updateState(MatchState.searching);
    });

    socket!.on('match_found', (data) {
      roomId = data['roomId'];
      partnerAlias = data['partnerAlias'];
      partnerId = data['partnerId'];
      partnerProfile = data['partnerProfile'];
      _updateState(MatchState.chatting);
    });

    socket!.on('receive_message', (data) {
      _messageController.add(data);
      // Auto-read message when received if in chat
      if (roomId != null) {
        markAsRead(data['messageId']);
      }
    });

    socket!.on('message_sent', (data) {
      print('Message acknowledged: ${data['messageId']}');
    });

    socket!.on('typing', (data) {
      _typingController.add(data);
    });

    socket!.on('read_status', (data) {
      _readStatusController.add(data);
    });

    socket!.on('match_ended', (_) {
      _updateState(MatchState.ended);
    });

    socket!.onConnectError((err) => print('Connect Error: $err'));
    socket!.onError((err) => print('Socket Error: $err'));
  }

  void startMatching(String lookingFor) {
    if (socket == null) return;
    socket!.emit('join_match', {'lookingFor': lookingFor});
  }

  void sendMessage(String text) {
    if (socket == null || roomId == null) return;
    socket!.emit('send_message', {
      'roomId': roomId,
      'message': text,
    });
  }

  void sendTyping(bool isTyping) {
    if (socket == null || roomId == null) return;
    socket!.emit('typing', {
      'roomId': roomId,
      'isTyping': isTyping,
    });
  }

  void markAsRead(String messageId) {
    if (socket == null || roomId == null) return;
    socket!.emit('read_message', {
      'roomId': roomId,
      'messageId': messageId,
    });
  }

  void leaveMatch() {
    if (socket == null) return;
    socket!.emit('leave_match');
    _updateState(MatchState.idle);
    roomId = null;
    partnerProfile = null;
    partnerAlias = null;
    partnerId = null;
  }

  void _updateState(MatchState newState) {
    state = newState;
    _stateController.add(newState);
  }

  void dispose() {
    socket?.dispose();
    _stateController.close();
    _messageController.close();
    _typingController.close();
    _readStatusController.close();
  }
}
