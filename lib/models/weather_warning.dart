class WeatherWarning {
  final String warnId;
  final int? type;
  final int? level;
  final String? event;
  final DateTime? start;
  final DateTime? end;
  final String? title;
  final String? description;
  final String? instruction;

  WeatherWarning({
    required this.warnId,
    this.type,
    this.level,
    this.event,
    this.start,
    this.end,
    this.title,
    this.description,
    this.instruction,
  });


}