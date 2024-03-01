import 'package:flutter/material.dart';

class AppTheme {
  final Color primaryColor;
  final Color focusColor;
  final Color backgroundColor;
  final Color accentColor;
  final Color shimmerBaseColor;
  final Color shimmerHighlightColor;
  final String? locale;

  AppTheme({
    this.primaryColor = Colors.white,
    this.focusColor = Colors.black,
    this.backgroundColor = Colors.white,
    this.accentColor = Colors.blue,
    this.shimmerBaseColor = const Color.fromARGB(255, 185, 185, 185),
    this.shimmerHighlightColor = const Color.fromARGB(255, 209, 209, 209),
    this.locale
  });
}
