import 'package:flutter/material.dart';
import 'package:jnt_app_0120/theme/app_colors.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  static const Color deepPlum = Color(0xFF3B1B4A);

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image (your generated nails image)
          Image.asset(
            'assets/images/homepage.png',
            fit: BoxFit.cover,
          ),

          // Optional: subtle gradient for readability (can remove if not needed)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.blackCat.withValues(alpha: 0.10),
                  Colors.transparent,
                  AppColors.blackCat.withValues(alpha: 0.25),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),

          // Header logo only
          Positioned(
            top: safeTop + 12,
            left: 16,
            child: Image.asset(
              'assets/images/jnt_logo_black.png',
              height: 50, // adjust as needed
              fit: BoxFit.contain,
            ),
          ),

          // Buttons row at bottom
          Positioned(
            left: 16,
            right: 16,
            bottom: safeBottom + 22,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Row(
                children: [
                  Flexible(fit: FlexFit.loose,
                    child: SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: deepPlum,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: () {
                        },
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Flexible(fit: FlexFit.loose,
                    child: SizedBox(
                      height: 54,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: deepPlum,
                          side: const BorderSide(color: deepPlum, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          backgroundColor: AppColors.snow.withValues(alpha: 0.95),
                        ),
                        onPressed: () {
                        },
                        child: const Text(
                          'Register',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

