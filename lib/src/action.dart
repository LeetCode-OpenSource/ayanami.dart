const SetStateSymbol = '__SET_STATE__';
const DispatchSymbol = '__DISPATCH__';

class AyanamiAction<T> {
  const AyanamiAction(this.type, this.payload);
  final String type;
  final T payload;
}
