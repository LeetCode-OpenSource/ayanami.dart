import 'package:flutter/widgets.dart';
import 'package:rxdart/rxdart.dart';
import 'action.dart';

typedef SetState<S extends State> = void Function(S state);

abstract class Module<S extends State> {
  S state;

  final Subject<Action> action$ = PublishSubject();

  final Subject<S> state$ = PublishSubject();

  S setState(SetState<S> setter) {
    // ignore: invalid_use_of_protected_member
    state.setState(() {
      setter(state);
      state$.add(state);
    });
    return state;
  }

  Future<void> dispose() async {
    await action$.close();
    await state$.close();
  }
}
