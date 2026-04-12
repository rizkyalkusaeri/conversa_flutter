import 'package:equatable/equatable.dart';

abstract class CreateThreadState extends Equatable {
  const CreateThreadState();

  @override
  List<Object?> get props => [];
}

class CreateThreadInitial extends CreateThreadState {}

class CreateThreadLoading extends CreateThreadState {}

class CreateThreadSuccess extends CreateThreadState {
  final String message;

  const CreateThreadSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class CreateThreadError extends CreateThreadState {
  final String message;

  const CreateThreadError(this.message);

  @override
  List<Object?> get props => [message];
}
