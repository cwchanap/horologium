/// Empty state widget when no production buildings exist.
library;

import 'package:flutter/material.dart';

/// Widget displayed when the colony has no production buildings.
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(128),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.cyanAccent.withAlpha(51),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.account_tree_outlined,
              size: 64,
              color: Colors.cyanAccent.withAlpha(179),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No production buildings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Build production buildings to see\nresource flows and dependencies',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.add),
            label: const Text('Build something'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.cyanAccent,
              side: BorderSide(color: Colors.cyanAccent.withAlpha(128)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
