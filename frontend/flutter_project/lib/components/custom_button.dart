import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final String buttonType; // "main" or "menu"

  const CustomButton({
    Key? key,
    required this.text,
    required this.onPressed,
    required this.buttonType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return SizedBox(
      height: buttonType == "main" ? 56 : 48, // Adjust height for main button
      width:
          buttonType == "main"
              ? screenWidth *
                  0.9 // Slightly smaller than screen width
              : screenWidth / 3, // 1/3 of screen width for menu button
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1D61E7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24), // Pill-shaped corners
          ),
          // You can add padding or other styling as needed
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontFamily: 'Inter', // Ensure Inter is added to pubspec.yaml
            fontWeight: FontWeight.w500, // Medium weight
          ),
        ),
      ),
    );
  }
}
