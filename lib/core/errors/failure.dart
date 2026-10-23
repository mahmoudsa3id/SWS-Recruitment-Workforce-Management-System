sealed class Failure {
  const Failure(this.message, {this.cause});
  final String message;
  final Object? cause;
}
final class ServerFailure extends Failure { const ServerFailure(super.message, {super.cause}); }
final class ValidationFailure extends Failure { const ValidationFailure(super.message); }
final class AuthFailure extends Failure { const AuthFailure(super.message, {super.cause}); }
final class CacheFailure extends Failure { const CacheFailure(super.message, {super.cause}); }
