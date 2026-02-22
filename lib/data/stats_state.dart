import 'dart:convert';

class StatsState {
  final int handsPlayed;
  final int playerWins;
  final int dealerWins;
  final int pushes;
  final int playerBlackjacks;
  final int playerBusts;
  final int dealerBusts;

  const StatsState({
    required this.handsPlayed,
    required this.playerWins,
    required this.dealerWins,
    required this.pushes,
    required this.playerBlackjacks,
    required this.playerBusts,
    required this.dealerBusts,
  });

  factory StatsState.initial() {
    return const StatsState(
      handsPlayed: 0,
      playerWins: 0,
      dealerWins: 0,
      pushes: 0,
      playerBlackjacks: 0,
      playerBusts: 0,
      dealerBusts: 0,
    );
  }

  factory StatsState.fromJson(Map<String, dynamic> json) {
    return StatsState(
      handsPlayed: json['handsPlayed'] as int? ?? 0,
      playerWins: json['playerWins'] as int? ?? 0,
      dealerWins: json['dealerWins'] as int? ?? 0,
      pushes: json['pushes'] as int? ?? 0,
      playerBlackjacks: json['playerBlackjacks'] as int? ?? 0,
      playerBusts: json['playerBusts'] as int? ?? 0,
      dealerBusts: json['dealerBusts'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'handsPlayed': handsPlayed,
      'playerWins': playerWins,
      'dealerWins': dealerWins,
      'pushes': pushes,
      'playerBlackjacks': playerBlackjacks,
      'playerBusts': playerBusts,
      'dealerBusts': dealerBusts,
    };
  }

  double get winRate => handsPlayed > 0 ? (playerWins / handsPlayed) * 100 : 0.0;
  double get lossRate => handsPlayed > 0 ? (dealerWins / handsPlayed) * 100 : 0.0;
  double get pushRate => handsPlayed > 0 ? (pushes / handsPlayed) * 100 : 0.0;

  StatsState copyWith({
    int? handsPlayed,
    int? playerWins,
    int? dealerWins,
    int? pushes,
    int? playerBlackjacks,
    int? playerBusts,
    int? dealerBusts,
  }) {
    return StatsState(
      handsPlayed: handsPlayed ?? this.handsPlayed,
      playerWins: playerWins ?? this.playerWins,
      dealerWins: dealerWins ?? this.dealerWins,
      pushes: pushes ?? this.pushes,
      playerBlackjacks: playerBlackjacks ?? this.playerBlackjacks,
      playerBusts: playerBusts ?? this.playerBusts,
      dealerBusts: dealerBusts ?? this.dealerBusts,
    );
  }
}
