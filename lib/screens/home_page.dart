// ignore_for_file: prefer_const_constructors

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
        title: const Text('we chat'),
        leading: Icon(CupertinoIcons.home),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Handle search action
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // Handle more options action
            },
          )
        ],
      ),

      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom:15),
        child: FloatingActionButton(
          onPressed: () {
            // Handle FAB action
          },
          child: const Icon(Icons.add),
        ),
      ),
      
      
    );
  }
}