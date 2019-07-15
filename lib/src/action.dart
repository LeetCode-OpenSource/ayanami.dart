const SetStateSymbol = '__SET_STATE__';
const DispatchSymbol = '__DISPATCH__';

class Action<T> {
  Action(this.type, this.payload);
  final String type;
  final T payload;
}
