
// ---------------------------------------------------------------------------
// BookingStatus enum (mirrors the one in main.dart)
// ---------------------------------------------------------------------------

enum BookingStatus { pending, active, done, cancelled }

extension BookingStatusX on BookingStatus {
  String get storageKey => name; // 'pending', 'active', 'done'

  static BookingStatus fromString(String value) {
    return BookingStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => BookingStatus.pending,
    );
  }
}

// ---------------------------------------------------------------------------
// BookingModel
// ---------------------------------------------------------------------------

class BookingModel {
  final String id;
  final String itemId;
  final String itemName;
  final String itemCategory;
  final String itemOwner;
  final int itemDeposit;
  final String itemImageUrl;
  final String lenderId;
  final String lenderEmail;
  final String borrowerId;
  final String borrowerName;
  final String borrowerEmail;
  DateTime? from;
  DateTime? to;
  final String note;
  BookingStatus status;
  bool beforePhoto;
  bool afterPhoto;
  final DateTime createdAt;

  BookingModel({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.itemCategory,
    required this.itemOwner,
    required this.itemDeposit,
    this.itemImageUrl = '',
    this.lenderId = '',
    this.lenderEmail = '',
    required this.borrowerId,
    this.borrowerName = '',
    this.borrowerEmail = '',
    this.from,
    this.to,
    this.note = '',
    this.status = BookingStatus.pending,
    this.beforePhoto = false,
    this.afterPhoto = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory BookingModel.fromJson(Map<String, dynamic> json, String id) {
    DateTime? parseDate(dynamic val) {
      if (val is String && val.isNotEmpty) return DateTime.tryParse(val);
      return null;
    }

    return BookingModel(
      id: id,
      itemId: json['itemId'] as String? ?? '',
      itemName: json['itemName'] as String? ?? '',
      itemCategory: json['itemCategory'] as String? ?? '',
      itemOwner: json['itemOwner'] as String? ?? '',
      itemDeposit: (json['itemDeposit'] as num?)?.toInt() ?? 0,
      itemImageUrl: json['itemImageUrl'] as String? ?? '',
      lenderId: json['lenderId'] as String? ?? '',
      lenderEmail: json['lenderEmail'] as String? ?? '',
      borrowerId: json['borrowerId'] as String? ?? '',
      borrowerName: json['borrowerName'] as String? ?? '',
      borrowerEmail: json['borrowerEmail'] as String? ?? '',
      from: parseDate(json['from']),
      to: parseDate(json['to']),
      note: json['note'] as String? ?? '',
      status: BookingStatusX.fromString(json['status'] as String? ?? 'pending'),
      beforePhoto: json['beforePhoto'] as bool? ?? false,
      afterPhoto: json['afterPhoto'] as bool? ?? false,
      createdAt: parseDate(json['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'itemCategory': itemCategory,
      'itemOwner': itemOwner,
      'itemDeposit': itemDeposit,
      'itemImageUrl': itemImageUrl,
      'lenderId': lenderId,
      'borrowerId': borrowerId,
      'borrowerName': borrowerName,
      'borrowerEmail': borrowerEmail,
      'from': from?.toIso8601String(),
      'to': to?.toIso8601String(),
      'note': note,
      'status': status.storageKey,
      'beforePhoto': beforePhoto,
      'afterPhoto': afterPhoto,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
