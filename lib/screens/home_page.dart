import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('We Chat'),

        leading: const Icon(CupertinoIcons.home),

        actions: [
          IconButton(
            icon: const Icon(Icons.search),

            onPressed: () {
              // Search action
            },
          ),

          IconButton(
            icon: const Icon(Icons.more_vert),

            onPressed: () {
              // More options action
            },
          ),
        ],
      ),

      body: const Center(
        child: Text(
          'Welcome to We Chat',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),

      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 15),

        child: FloatingActionButton(
          onPressed: () {
            // FAB action
          },

          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
