class LyricsLine {
  final int timeMs;
  final String text;

  const LyricsLine({
    required this.timeMs,
    required this.text,
  });

  Map<String, dynamic> toJson() => {
    'timeMs': timeMs,
    'text': text,
  };

  factory LyricsLine.fromJson(Map<String, dynamic> json) => LyricsLine(
    timeMs: (json['timeMs'] as num?)?.toInt() ?? 0,
    text: json['text'] as String? ?? '',
  );
}
