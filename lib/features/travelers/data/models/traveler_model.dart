import '../../domain/entities/traveler.dart';

class TravelerModel extends Traveler {
  const TravelerModel({
    required super.id,
    required super.fullName,
    required super.phone,
    required super.agreementTotal,
    required super.paidAmount,
    required super.createdAt,
    super.fileNo,
    super.salesPerson,
    super.destinationCountry,
    super.submitted,
    super.inspected,
    super.visaIssued,
    super.flightBooked,
    super.avatarPath,
    super.ticketBookingType,
    super.ticketBookingNote,
  });

  factory TravelerModel.fromMap(Map<String, dynamic> map) => TravelerModel(
    id: '${map['id'] ?? ''}',
    fullName: '${map['full_name'] ?? ''}',
    phone: '${map['phone'] ?? ''}',
    agreementTotal: _num(map['agreement_total']),
    paidAmount: _num(map['paid_amount']),
    createdAt: DateTime.tryParse('${map['created_at'] ?? ''}') ?? DateTime.fromMillisecondsSinceEpoch(0),
    fileNo: map['file_no']?.toString(),
    salesPerson: map['sales_person']?.toString(),
    destinationCountry: map['destination_country']?.toString(),
    submitted: map['stage_submitted'] == true,
    inspected: map['stage_inspected'] == true || map['stage_check'] == true,
    visaIssued: map['stage_visa'] == true,
    flightBooked: map['stage_flight'] == true,
    avatarPath: map['avatar_path']?.toString(),
    ticketBookingType: map['ticket_booking_type']?.toString(),
    ticketBookingNote: map['ticket_booking_note']?.toString(),
  );

  static double _num(dynamic value) {
    final parsed = value is num ? value.toDouble() : double.tryParse('${value ?? ''}') ?? 0;
    return parsed.isFinite ? parsed : 0;
  }
}
