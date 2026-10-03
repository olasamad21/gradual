import 'package:flutter/material.dart';

const List<Color> _accentColors = [
  Color(0xFF1D4ED8), // blue
  Color(0xFF6D28D9), // purple
  Color(0xFF0F766E), // teal
];

Color wordColor(int index) => _accentColors[index % 3];

const Color doneGreen = Color(0xFF388E3C);
