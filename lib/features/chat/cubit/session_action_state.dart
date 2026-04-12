import 'package:equatable/equatable.dart';
import 'package:fifgroup_android_ticketing/data/models/session_model.dart';

abstract class SessionActionState extends Equatable {
  const SessionActionState();

  @override
  List<Object?> get props => [];
}

class SessionActionInitial extends SessionActionState {}

class SessionActionLoading extends SessionActionState {
  final String actionType;

  const SessionActionLoading(this.actionType);

  @override
  List<Object?> get props => [actionType];
}

class SessionActionSuccess extends SessionActionState {
  final SessionModel session;
  final String message;
  final String actionType;

  const SessionActionSuccess(this.session, this.message, this.actionType);

  @override
  List<Object?> get props => [session, message, actionType];
}

class SessionActionError extends SessionActionState {
  final String message;
  final String actionType;

  const SessionActionError(this.message, this.actionType);

  @override
  List<Object?> get props => [message, actionType];
}
