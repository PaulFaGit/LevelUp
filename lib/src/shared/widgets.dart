import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'xp_logic.dart';

Color _hex(String h) =>
    Color(0xFF000000 | int.parse(h.replaceFirst('#', ''), radix: 16));

Widget glass({required Widget child, EdgeInsetsGeometry? padding}) {
  return Container(
    padding: padding,
    decoration: BoxDecoration(
      color: const Color(0x99111827),
      border: Border.all(color: const Color(0xFF1f2a3a)),
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [
        BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 8))
      ],
    ),
    child: child,
  );
}


