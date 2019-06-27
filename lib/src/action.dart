class Action<T> {
  Action(this.type, this.payload);
  final String type;
  final T payload;
}
