abstract class ActiveSessionCountState {}

class ActiveSessionCountInitial extends ActiveSessionCountState {}

class ActiveSessionCountLoading extends ActiveSessionCountState {}

class ActiveSessionCountLoaded extends ActiveSessionCountState {
  final int count;

  ActiveSessionCountLoaded(this.count);
}

class ActiveSessionCountError extends ActiveSessionCountState {
  final String message;

  ActiveSessionCountError(this.message);
}
