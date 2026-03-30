import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';

part 'counter_state.dart';

class CounterCubit extends Cubit<CounterState> {
  CounterCubit() : super(CounterInitial(counter: 0));

  void increment() async {
    int currentVal = 0;

    if (state is CounterSuccess) currentVal = (state as CounterSuccess).value;

    emit(CounterLoading());

    await Future.delayed(const Duration(milliseconds: 300));

    if (currentVal >= 10) {
      emit(CounterError(message: "Waduh Mas, maksimal 10 ya!"));
    } else {
      emit(CounterSuccess(value: currentVal + 1));
    }
  }

  void decrement() async {
    int currentVal = 0;
    if (state is CounterSuccess) currentVal = (state as CounterSuccess).value;

    emit(CounterLoading());

    await Future.delayed(const Duration(milliseconds: 300));

    if (currentVal > 0) {
      emit(CounterSuccess(value: currentVal - 1));
    } else {
      emit(CounterError(message: "Waduh Mas, minimal 0 ya!"));
    }
  }
}
