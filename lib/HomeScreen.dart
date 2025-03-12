import 'package:flutter/material.dart';
import 'GradientBackground.dart';
import 'package:google_fonts/google_fonts.dart';
import 'FloatingButton.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isTranslationEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.3),
            radius: 1.5,
            colors: [
              Color(0xFF8CA0E0), // Light blue
              Color(0xFF3854AF), // Darker blue
            ],
            stops: [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // App title
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Screen',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Translator',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    // Settings button
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white),
                        iconSize: 20,
                        onPressed: () {
                          // Open settings
                        },
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Center power button
                Center(
                  child: Column(
                    children: [
                      // Power button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isTranslationEnabled = !_isTranslationEnabled;
                            if (_isTranslationEnabled) {
                              // Show the floating button
                              _requestOverlayPermission();
                            } else {
                              // Hide the floating button
                              FloatingButtonService.hideFloatingButton();
                            }
                          });
                        },
                        child: Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              Icons.power_settings_new,
                              size: 150,
                              color: _isTranslationEnabled
                                  ? const Color(0xFF51D95E)
                                  : const Color(0xFF3854AF),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),
                      // Status text
                      Text(
                        _isTranslationEnabled
                            ? 'Disable Translation Mode'
                            : 'Enable Translation Mode',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Method to request overlay permission and show floating button
  Future<void> _requestOverlayPermission() async {
    // In a real app, you would need to implement platform-specific code
    // to request the SYSTEM_ALERT_WINDOW permission on Android

    // For this example, we'll just show the floating button
    FloatingButtonService.showFloatingButton(context);

    // In reality, you would check permission status first:
    // bool hasPermission = await checkOverlayPermission();
    // if (hasPermission) {
    //   FloatingButtonService.showFloatingButton(context);
    // } else {
    //   // Request permission
    //   await requestOverlayPermission();
    // }
  }
}