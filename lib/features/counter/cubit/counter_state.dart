part of 'counter_cubit.dart';

@immutable
sealed class CounterState {}

final class CounterInitial extends CounterState {
  final int counter;

  CounterInitial({required this.counter});
}

class CounterLoading extends CounterState {}

class CounterSuccess extends CounterState {
  final int value;
  CounterSuccess({required this.value});
}

class CounterError extends CounterState {
  final String message;

  CounterError({required this.message});
}
