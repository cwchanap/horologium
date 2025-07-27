import 'package:flutter/material.dart';

import '../../game/building/building.dart';

class DeleteConfirmationDialog extends StatelessWidget {
  final Building building;
  final VoidCallback onConfirm;

  const DeleteConfirmationDialog({
    super.key,
    required this.building,
    required this.onConfirm,
  });

  static Future<void> show({
    required BuildContext context,
    required Building building,
    required VoidCallback onConfirm,
  }) {
    return showDialog(
      context: context,
      builder: (context) => DeleteConfirmationDialog(
        building: building,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Delete ${building.name}?'),
      content: Text('This will refund ${building.cost} money.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
          child: const Text('Delete'),
        ),
      ],
    );
  }
}