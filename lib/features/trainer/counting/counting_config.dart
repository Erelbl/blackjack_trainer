/// Duration options for a card-counting session.
///
/// Add new variants here — the controller always reads [seconds].
enum CountingSessionDuration {
  s15,
  s30,
  s60,
  s90;

  int get seconds => switch (this) {
        CountingSessionDuration.s15 => 15,
        CountingSessionDuration.s30 => 30,
        CountingSessionDuration.s60 => 60,
        CountingSessionDuration.s90 => 90,
      };

  String get label => switch (this) {
        CountingSessionDuration.s15 => '15s',
        CountingSessionDuration.s30 => '30s',
        CountingSessionDuration.s60 => '60s',
        CountingSessionDuration.s90 => '90s',
      };
}

/// Card reveal cadence options.
///
/// The controller always reads [milliseconds] — no magic numbers elsewhere.
/// Default: [ms1500].
enum CountingCardPace {
  ms600,
  ms800,
  ms1000,
  ms1500,
  ms2000;

  int get milliseconds => switch (this) {
        CountingCardPace.ms600  => 600,
        CountingCardPace.ms800  => 800,
        CountingCardPace.ms1000 => 1000,
        CountingCardPace.ms1500 => 1500,
        CountingCardPace.ms2000 => 2000,
      };

  String get label => switch (this) {
        CountingCardPace.ms600  => '0.6s',
        CountingCardPace.ms800  => '0.8s',
        CountingCardPace.ms1000 => '1.0s',
        CountingCardPace.ms1500 => '1.5s',
        CountingCardPace.ms2000 => '2.0s',
      };
}
