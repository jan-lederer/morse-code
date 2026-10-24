import 'package:flutter/material.dart';

const morseOrangeLight = Color(0xFFA56300);
const morseOrangeDark = Color(0xFFFFB74D);
const morseOrangeSoftLight = Color(0xFFFFF8E8);
const morseOrangeSoftDark = Color(0xFF332719);
const morseAccentInk = Color(0xFF172235);

Color morseAccentFor(bool dark) => dark ? morseOrangeDark : morseOrangeLight;
Color morseAccentSoftFor(bool dark) =>
    dark ? morseOrangeSoftDark : morseOrangeSoftLight;
Color morseAccentForegroundFor(bool dark) =>
    dark ? morseAccentInk : Colors.white;
