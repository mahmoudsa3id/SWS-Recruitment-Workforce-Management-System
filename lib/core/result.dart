import 'package:dartz/dartz.dart';
import 'errors/failure.dart';
typedef Result<T> = Either<Failure, T>;
