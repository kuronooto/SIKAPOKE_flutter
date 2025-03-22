class RoomModel {
  final String roomId;
  final String roomStatus;
  final String? player1Id;
  final String? player2Id;
  final Map<String, dynamic> gameState;
  final List<dynamic> logs;

  RoomModel({
    required this.roomId,
    required this.roomStatus,
    this.player1Id,
    this.player2Id,
    required this.gameState,
    required this.logs,
  });

  factory RoomModel.fromFirestore(String id, Map<String, dynamic> data) {
    return RoomModel(
      roomId: id,
      roomStatus: data['room_status'] as String,
      player1Id: data['player1_id'] as String?,
      player2Id: data['player2_id'] as String?,
      gameState: data['game_state'] as Map<String, dynamic>,
      logs: data['logs'] as List<dynamic>,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'room_status': roomStatus,
      'player1_id': player1Id,
      'player2_id': player2Id,
      'game_state': gameState,
      'logs': logs,
    };
  }
}
