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
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_tree_outlined,
              size: 64,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No production buildings',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Build production buildings to see\nresource flows and dependencies',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.add),
            label: const Text('Build something'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey[500],
              side: BorderSide(color: Colors.grey[700]!),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
