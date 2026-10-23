import '../../../../core/result.dart'; import '../entities/traveler.dart'; import '../traveler_repository.dart';
class ListTravelers {const ListTravelers(this.repository);final TravelerRepository repository;Future<Result<List<Traveler>>> call({String query=''})=>repository.list(query:query);}
