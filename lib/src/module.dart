import 'package:angel_container_generator/angel_container_generator.dart';
import 'package:angel_container/angel_container.dart' as angel_container;
import 'package:flutter/widgets.dart' as widget;
import 'package:rxdart/rxdart.dart';
import 'action.dart';

typedef SetState = void Function();
typedef Epic<S, T> = Observable<EpicEndAction<S>> Function(
    Observable<T> payload$);

abstract class Module<S> {
  static angel_container.Container _container;

  static angel_container.Container makeContainer() {
    const reflector = GeneratedReflector();
    final container = angel_container.Container(reflector);
    _container = container;
    return container;
  }

  static widget.State<W>
      createAppState<W extends widget.StatefulWidget, M extends Module>(
          widget.State<W> Function(M ayanamiState) builder,
          {bool singleton = true}) {
    final hasSingleton = _container.has(M);
    final M instance = _container.make(M);
    assert(() {
      if (instance._appState != null && instance._appState.mounted) {
        print(
            'You are connecting multi AppState to One module, wish you know what you are doing');
      }
      return true;
    }());
    if (!hasSingleton && singleton) {
      _container.registerSingleton(instance, as: M);
    }
    instance._appState = builder(instance);
    instance.state$.add(instance.state);
    return instance._appState;
  }

  S get state;

  final Map<Function, String> actions = {};

  final Subject<AyanamiAction> action$ = PublishSubject();

  final Subject<S> state$ = BehaviorSubject();

  widget.State _appState;

  widget.State get appState {
    return _appState;
  }

  EpicEndAction<S> Function(T payload) createAction<T>(
    Epic<dynamic, T> method,
  ) {
    final actionName = actions[method];
    return (T payload) => EpicEndAction(DispatchSymbol,
        dispatchAction: AyanamiAction(actionName, payload), module: this);
  }

  EpicEndAction<S> createNoopAction() {
    return EpicEndAction('__noop__', module: this);
  }

  Observable<AyanamiAction<T>> ofMethod<T>(Epic<S, T> method) {
    final actionName = actions[method];
    return action$.where((a) => a.type == actionName).cast<AyanamiAction<T>>();
  }

  Observable<EpicEndAction<S>> setState(SetState setter) {
    return Observable.fromFuture(widget.WidgetsBinding.instance.endOfFrame)
        .doOnData(
      (_) {
        if (_appState.mounted) {
          // ignore: invalid_use_of_protected_member
          _appState.setState(setter);
          state$.add(state);
        } else {
          state$.add(state);
          // widget disposed, no need setState to rerender, just do state sideEffects
          setter();
        }
      },
    ).map(
      (_) => EpicEndAction(SetStateSymbol, module: this),
    );
  }

  Future<Null> dispose() async {
    await action$.close();
    await state$.close();
  }
}

class EpicEndAction<S> extends AyanamiAction<Null> {
  EpicEndAction(String type, {this.dispatchAction, this.module})
      : super(type, null);

  final AyanamiAction<dynamic> dispatchAction;

  final Module<S> module;
}
