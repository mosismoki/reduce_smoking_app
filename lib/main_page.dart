import 'package:flutter/material.dart';
import 'smoking_scheduler.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final _scheduler = SmokingScheduler.instance;
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _buildHome(),
      const Center(child: Text('Profile Page')),
      const Center(child: Text('Settings Page')),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildHome() {
    return Stack(
      children: [
        Positioned(
          top: 16,
          left: 16,
          child: ValueListenableBuilder<Duration>(
            valueListenable: _scheduler.remaining,
            builder: (context, duration, _) {
              final hours = duration.inHours.toString().padLeft(2, '0');
              final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
              final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
              return Text(
                '$hours:$minutes:$seconds',
                style: const TextStyle(fontSize: 16),
              );
            },
          ),
        ),
        Center(
          child: Image.asset('assets/tree.png'),
        ),
      ],
    );
  }
}
