import 'dart:convert';

import 'package:chitchat/services/chats.dart';
import 'package:event_handeler/event_handeler.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:async';

class MQTTService {
  MqttServerClient? _client;
  final String broker;
  final String clientId;
  final void Function() onConnected;
  final void Function() onDisconnected;
  final void Function(String) onSubscribed;
  final void Function(String?) onUnSubscribed;
  final void Function(String) onMessageReceived;

  MQTTService({
    required this.broker,
    required this.clientId,
    required this.onConnected,
    required this.onDisconnected,
    required this.onSubscribed,
    required this.onUnSubscribed,
    required this.onMessageReceived,
    bool secure = false,
  });

  String? topic; // Default topic
  set setTopic(String value) => topic = value;
  get getTopic => topic;
  String get getClientId => clientId;
  String get getBroker => broker;
  get getClient => _client!;
  bool _isDisposed = false;
  Future<void> connect(String topc) async {
    // Don't try to connect if disposed
    if (_isDisposed) {
      print('⚠️ MQTT service disposed, skipping connection');
      return;
    }

    if (_client != null &&
        (_client!.connectionStatus?.state == MqttConnectionState.connected ||
            _client!.connectionStatus?.state ==
                MqttConnectionState.connecting)) {
      print('🔗 Already connected to MQTT broker');
      return;
    }
    // Ensure the client is not already connected before attempting to connect
    final token = await ChatServices.getChatToken(); //get the password as token
    topic = topc;

    _client = MqttServerClient.withPort(broker, clientId, 1883)
      ..logging(on: false)
      ..keepAlivePeriod = 30
      ..onDisconnected = onDisconnected
      ..onConnected = onConnected
      ..onSubscribed = onSubscribed
      ..onUnsubscribed = onUnSubscribed
      ..autoReconnect =
          false; // Disabled - we handle reconnection manually via timer

    final connMessage = MqttConnectMessage()
        .authenticateAs('user', token)
        .withClientIdentifier(clientId)
        .withWillTopic('clients/$clientId/disconnect')
        .withWillMessage('Client $clientId disconnected unexpectedly')
        .withWillQos(MqttQos.atLeastOnce);

    _client!.connectionMessage = connMessage;

    try {
      await _client!.connect();

      if (_client!.connectionStatus?.state != MqttConnectionState.connected) {
        print('❌ Failed to connect: ${_client!.connectionStatus?.state}');
        _client!.disconnect();
        return;
      }

      print('✅ Connected to MQTT broker');

      _client!.subscribe(topic!, MqttQos.atLeastOnce);

      _client!.updates!
          .listen((List<MqttReceivedMessage<MqttMessage?>>? c) async {
        final recMess = c![0].payload as MqttPublishMessage;
        final String _topic = c[0].topic;

        try {
          final payloadBytes = recMess.payload.message;
          final message = utf8.decode(payloadBytes); // 🔥 FIX HERE
          final senderClientId = _topic.split('/').last;

          if (senderClientId != clientId) {
            print('📩 Message received: $message from $_topic');
            await ChatServices.incrementMessageNotificationCount();
            dispatchCustomEvent(0, "messageNotificationCountUpdate");
            onMessageReceived(message);
          }
        } catch (e) {
          print('🚨 Failed to decode message: $e');
        }
      });
    } catch (e) {
      print('🚨 Connection error: $e');
      _client!.disconnect();
    }
  }

  void disconnect() {
    _isDisposed = true;
    if (_client != null) {
      _client!.disconnect();
      _client = null;
    }
  }

  bool get isConnected =>
      _client != null &&
      _client!.connectionStatus?.state == MqttConnectionState.connected;

  void publish(String message) {
    final builder = MqttClientPayloadBuilder()..addUTF8String(message);
    if (topic == null) {
      print('Topic is not set. Please set a topic before publishing.');
      throw Exception(
          'Topic is not set. Please set a topic before publishing.');
    } else {
      String? _topic = topic!.split('/')[0];
      _client!.publishMessage(
          "$_topic/$clientId", MqttQos.atLeastOnce, builder.payload!);
    }
  }
}
