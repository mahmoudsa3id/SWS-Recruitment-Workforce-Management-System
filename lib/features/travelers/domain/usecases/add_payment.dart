import '../../../../core/result.dart'; import '../traveler_repository.dart';
class AddTravelerPayment { const AddTravelerPayment(this.repository); final TravelerRepository repository; Future<Result<void>> call({required String travelerId,required double amount,required String method,required String note})=>repository.addPayment(travelerId:travelerId,amount:amount,method:method,note:note); }
