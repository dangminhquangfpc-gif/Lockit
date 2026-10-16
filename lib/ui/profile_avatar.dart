import 'package:flutter/material.dart';
import '../data/models.dart';

const profileColors = [
  Color(0xFFF4C95D),
  Color(0xFFBCD8C4),
  Color(0xFFD5C9EC),
  Color(0xFFF2C4AF),
  Color(0xFFB6D6EA),
  Color(0xFFEFC7D6)
];

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.profile, this.radius = 22});
  final Profile profile;
  final double radius;
  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: radius,
        foregroundColor: const Color(0xFF193B32),
        backgroundColor: profileColors[
            profile.colorIndex.clamp(0, profileColors.length - 1)],
        child: Text(
            profile.emoji.isNotEmpty
                ? profile.emoji
                : profile.name.isEmpty
                    ? '?'
                    : profile.name.characters.first.toUpperCase(),
            style: TextStyle(fontSize: radius * 0.85)),
      );
}
