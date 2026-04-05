/// Card states used by the spaced-repetition scheduler.
enum CardState { newCard, learning, review }

/// Lightweight in-memory card model.
/// TODO: replace with Drift entity in issue #2.
class CardModel {
  const CardModel({
    required this.id,
    required this.front,
    required this.back,
    required this.state,
    this.dueAt,
  });

  final String id;
  final String front;
  final String back;
  final CardState state;
  final DateTime? dueAt;

  CardModel copyWith({
    String? id,
    String? front,
    String? back,
    CardState? state,
    DateTime? dueAt,
  }) {
    return CardModel(
      id: id ?? this.id,
      front: front ?? this.front,
      back: back ?? this.back,
      state: state ?? this.state,
      dueAt: dueAt ?? this.dueAt,
    );
  }
}
