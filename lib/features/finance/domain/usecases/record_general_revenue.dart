import '../../../../core/result.dart'; import '../repositories/finance_repository.dart';
class RecordGeneralRevenue { const RecordGeneralRevenue(this.repository); final FinanceRepository repository; Future<Result<String>> call({required double amount,required String method,required String note})=>repository.recordGeneralRevenue(amount:amount,method:method,note:note); }
