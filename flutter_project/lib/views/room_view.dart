import 'package:flutter/material.dart';
import 'login_view.dart'; // Add this import

class RoomView extends StatelessWidget {
  const RoomView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1B),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center, // Changed to center
            children: [
              // Back button and centered title
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.start, // Align items to start
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginView(),
                        ),
                      );
                    },
                  ),
                  Expanded(
                    child: Center(
                      // Center the title
                      child: const Text(
                        'Room-01',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.bold,
                          fontSize: 32,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // Add invisible icon button to balance the layout
                  const SizedBox(width: 48), // Same width as IconButton
                ],
              ),
              const SizedBox(height: 20),
              // Preview Schedule button
              ElevatedButton(
                onPressed: () {
                  // TODO: Implement preview schedule functionality
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: const Text(
                  'Preview Schedule',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              // Centered Participants title
              const Center(
                child: Text(
                  'Participants',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500, // Medium weight
                    fontSize: 20,
                    color: Colors.white,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Scrollable participant list
              Expanded(
                child: ListView(
                  children: [
                    _buildParticipantRow('Buğrahan Efe (Host)', Colors.green),
                    _buildParticipantRow('Mert Küçükerdem', Colors.red),
                    _buildParticipantRow('Melike Şahin', Colors.red),
                    _buildParticipantRow('Selen Bilgiç', Colors.grey),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantRow(String name, Color statusColor) {
    bool isHost = name.contains('(Host)');
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: isHost ? Border.all(color: Colors.blue, width: 3.0) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.person, color: Colors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Icon(Icons.circle, color: statusColor),
        ],
      ),
    );
  }
}
