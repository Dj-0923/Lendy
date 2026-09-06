import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final headerHeight = screenHeight * 4 / 10; // matches flex 4:6 below

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              //Dark green ---------
              Expanded(
                flex: 4,
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFF0F4844),
                  child: Stack(
                    children: [
                      //////////////////////////////////////////////////////
                      /////SMALL CIRCLE (overlaps big circle, clipped by bottom edge) -----------
                      //////////////////////////////////////////////////////
                      Positioned(
                        top: 272,
                        right: 25,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.15),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.06),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      //////////////////////////////////////////////////////
                      //BIG CIRCLE (bleeds slightly off the right edge) -----------
                      //////////////////////////////////////////////////////
                      Positioned(
                        top: 180,
                        right: 43,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.15),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.06),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      //////////////////////////////////////////////////////
                      //HALF CIRCLE (clipped by left AND bottom edges) -----------
                      //////////////////////////////////////////////////////
                      Positioned(
                        top: 270,
                        left: -70,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.15),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.06),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      //////////////////////////////////////////////////////
                      //Dot Pattern -----------
                      //////////////////////////////////////////////////////
                      Positioned(top: -15, right: -15, child: _buildDotGrid()),
                      //////////////////////////////////////////////////////
                      /////TEXT BLOCK -----------
                      /////////////////////////////////////////////////////////
                      Positioned(
                        top: 150,
                        left: 34,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Welcome to',
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                height: 1.0,
                              ),
                            ),
                            Text(
                              'Lendy',
                              style: GoogleFonts.inter(
                                fontSize: 60,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 0.9,
                              ),
                            ),
                            Text(
                              'Campus Access',
                              style: GoogleFonts.inter(
                                fontSize: 28,
                                fontWeight: FontWeight.w400,
                                color: Colors.white,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ///////////////////////////
              //White ------------
              ///////////////////////////
              Expanded(
                flex: 6,
                child: Container(width: double.infinity, color: Colors.white),
              ),
            ],
          ),
          // LOGO BADGE — sits on the seam between both sections
          Positioned(
            top: headerHeight - 100,
            right: 35,
            child: _buildLogoBadge(),
          ),
        ],
      ),
    );
  }
}

Widget _buildLogoBadge() {
  return Container(
    width: 144,
    height: 144,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.40),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),

    child: Center(
      child: SizedBox(
        width: 120,
        height: 120,
        child: Image.asset('assets/Lendy.png'),
      ),
    ),
  );
}

Widget _buildDotGrid() {
  return Transform.rotate(
    angle: 0.785398, // 45 degrees in radians
    child: Column(
      children: List.generate(4, (row) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(4, (col) {
            return Padding(
              padding: const EdgeInsets.all(3.5),
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
            );
          }),
        );
      }),
    ),
  );
}
