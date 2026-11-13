import '../../../../core/network/json_reader.dart';
import '../../../../core/types.dart';
import '../../domain/entities/call.dart';

abstract final class CallModel {
  static Call fromJson(Json json) => Call(
    id: json.integer('id'),
    callerId: json.integer('caller_id'),
    receiverId: json.integer('receiver_id'),
    channelName: json.str('channel_name'),
  );
}

abstract final class CallCredentialsModel {
  static CallCredentials fromJson(Json json) => CallCredentials(
    appId: json.str('app_id'),
    channelName: json.str('channel_name'),
    uid: json.integer('uid'),
    token: json.str('token'),
  );
}
