import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/sign_in.dart';
import '../../domain/usecases/sign_out.dart';

sealed class AuthState {
  const AuthState();
}

final class AuthInitial extends AuthState {
  const AuthInitial();
}

final class AuthLoading extends AuthState {
  const AuthLoading();
}

final class AuthSignedIn extends AuthState {
  const AuthSignedIn();
}

final class AuthFailure extends AuthState {
  const AuthFailure(this.message);
  final String message;
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._signIn, this._signOut) : super(const AuthInitial());
  final SignIn _signIn;
  final SignOut _signOut;
  Future<void> signIn(String email, String password) async {
    emit(const AuthLoading());
    final r = await _signIn(email, password);
    r.fold(
      (f) => emit(AuthFailure(f.message)),
      (_) => emit(const AuthSignedIn()),
    );
  }

  Future<void> signOut() async {
    await _signOut();
    emit(const AuthInitial());
  }
}
