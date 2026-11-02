import 'package:flutter/material.dart';

@immutable
class MiniReaderInk {
  const MiniReaderInk({
    this.color = const Color(0xffd2d2d2),
    this.outlineEnabled = false,
    this.outlineColor = Colors.black,
    this.outlineWidth = .7,
    this.shadowEnabled = false,
    this.shadowColor = Colors.black,
    this.shadowOpacity = .65,
    this.shadowBlur = 2,
    this.shadowOffset = 2,
  });

  final Color color;
  final bool outlineEnabled;
  final Color outlineColor;
  final double outlineWidth;
  final bool shadowEnabled;
  final Color shadowColor;
  final double shadowOpacity;
  final double shadowBlur;
  final double shadowOffset;

  MiniReaderInk copyWith({
    Color? color,
    bool? outlineEnabled,
    Color? outlineColor,
    double? outlineWidth,
    bool? shadowEnabled,
    Color? shadowColor,
    double? shadowOpacity,
    double? shadowBlur,
    double? shadowOffset,
  }) => MiniReaderInk(
    color: color ?? this.color,
    outlineEnabled: outlineEnabled ?? this.outlineEnabled,
    outlineColor: outlineColor ?? this.outlineColor,
    outlineWidth: outlineWidth ?? this.outlineWidth,
    shadowEnabled: shadowEnabled ?? this.shadowEnabled,
    shadowColor: shadowColor ?? this.shadowColor,
    shadowOpacity: shadowOpacity ?? this.shadowOpacity,
    shadowBlur: shadowBlur ?? this.shadowBlur,
    shadowOffset: shadowOffset ?? this.shadowOffset,
  );

  Map<String, Object> toJson() => {
    'color': color.toARGB32(),
    'outlineEnabled': outlineEnabled,
    'outlineColor': outlineColor.toARGB32(),
    'outlineWidth': outlineWidth,
    'shadowEnabled': shadowEnabled,
    'shadowColor': shadowColor.toARGB32(),
    'shadowOpacity': shadowOpacity,
    'shadowBlur': shadowBlur,
    'shadowOffset': shadowOffset,
  };

  factory MiniReaderInk.fromJson(Map<String, dynamic> value) => MiniReaderInk(
    color: Color(value['color'] as int),
    outlineEnabled: value['outlineEnabled'] as bool,
    outlineColor: Color(value['outlineColor'] as int),
    outlineWidth: (value['outlineWidth'] as num).toDouble(),
    shadowEnabled: value['shadowEnabled'] as bool,
    shadowColor: Color(value['shadowColor'] as int),
    shadowOpacity: (value['shadowOpacity'] as num).toDouble(),
    shadowBlur: (value['shadowBlur'] as num).toDouble(),
    shadowOffset: (value['shadowOffset'] as num).toDouble(),
  );
}
