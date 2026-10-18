
class ChatMsgModel {
  final String id;
  final String text;
  final String senderId; // uid or 'system'
  final bool fromMe;     // computed at read time based on current user
  final DateTime timestamp;
  final String type;     // 'text' or 'location'
  final double? latitude;
  final double? longitude;
  final String? locationAddress;

  ChatMsgModel({
    required this.id,
    required this.text,
    required this.senderId,
    required this.fromMe,
    required this.timestamp,
    this.type = 'text',
    this.latitude,
    this.longitude,
    this.locationAddress,
  });

  bool get isLocation =>
      type == 'location' || (latitude != null && longitude != null);

  /// [currentUserId] is used to derive [fromMe] at read time.
  factory ChatMsgModel.fromJson(
    Map<String, dynamic> json,
    String id,
    String currentUserId,
  ) {
    final senderId = json['senderId'] as String? ?? '';
    final lat = (json['latitude'] as num?)?.toDouble() ??
        (json['lat'] as num?)?.toDouble();
    final lng = (json['longitude'] as num?)?.toDouble() ??
        (json['lng'] as num?)?.toDouble();
    final address = json['locationAddress'] as String? ??
        json['address'] as String?;
    final rawType = json['type'] as String?;
    final type = rawType ?? (lat != null && lng != null ? 'location' : 'text');

    return ChatMsgModel(
      id: id,
      text: json['text'] as String? ?? '',
      senderId: senderId,
      fromMe: senderId == currentUserId,
      timestamp: (json['timestamp'] is String
              ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
              : DateTime.now()),
      type: type,
      latitude: lat,
      longitude: lng,
      locationAddress: address,
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'text': text,
      'senderId': senderId,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
    };
    if (latitude != null) data['latitude'] = latitude;
    if (longitude != null) data['longitude'] = longitude;
    if (locationAddress != null && locationAddress!.isNotEmpty) {
      data['locationAddress'] = locationAddress;
    }
    return data;
  }
}
