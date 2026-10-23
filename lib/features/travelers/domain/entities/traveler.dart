class Traveler {
  const Traveler({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.agreementTotal,
    required this.paidAmount,
    required this.createdAt,
    this.fileNo,
    this.salesPerson,
    this.destinationCountry,
    this.submitted = false,
    this.inspected = false,
    this.visaIssued = false,
    this.flightBooked = false,
    this.avatarPath,
    this.ticketBookingType,
    this.ticketBookingNote,
  });

  final String id, fullName, phone;
  final double agreementTotal, paidAmount;
  final DateTime createdAt;
  final String? fileNo, salesPerson, destinationCountry;
  final bool submitted, inspected, visaIssued, flightBooked;
  final String? avatarPath, ticketBookingType, ticketBookingNote;

  double get remaining =>
      (agreementTotal - paidAmount).clamp(0, double.infinity).toDouble();
  bool get isFullyPaid => agreementTotal > 0 && remaining <= 0.009;

  String get currentStage {
    if (flightBooked) return 'تم حجز التذكرة';
    if (visaIssued) return 'بانتظار التذكرة';
    if (inspected) return 'بانتظار التأشيرة';
    if (submitted) return 'تم التقديم';
    return 'جديد';
  }
}
