import 'package:flutter/material.dart';

double fontScale(BuildContext context) {
  final w = MediaQuery.of(context).size.width;

  if (w < 360) return 0.85; // very small phones
  if (w < 390) return 0.9;  // small phones
  if (w < 430) return 1.0;  // normal phones
  if (w < 500) return 1.05; // large phones
  return 1.1;               // tablets
}
