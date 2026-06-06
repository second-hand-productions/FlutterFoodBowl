import 'package:flutter/material.dart';

import 'package:cod/config/food_bowl_settings.dart';
import 'package:cod/models/bowl_models.dart';

class AddBowlDialog extends StatefulWidget {
  const AddBowlDialog({super.key, required this.existingIds});

  final Set<String> existingIds;

  @override
  State<AddBowlDialog> createState() => _AddBowlDialogState();
}

class _AddBowlDialogState extends State<AddBowlDialog> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final id = _idController.text.trim();
    final nameText = _nameController.text.trim();
    Navigator.of(
      context,
    ).pop(FoodBowlConfig(id: id, name: nameText.isEmpty ? id : nameText));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add bowl'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _idController,
              decoration: const InputDecoration(
                labelText: 'Bowl ID',
                hintText: 'bowl-aabbccddeeff',
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                final id = value?.trim() ?? '';
                if (id.isEmpty) {
                  return 'Enter the firmware BOWL_ID';
                }
                if (id.length > 32) {
                  return 'Use 32 characters or fewer';
                }
                if (!isValidBowlId(id)) {
                  return 'Use only letters, numbers, _, or -';
                }
                if (widget.existingIds.any((existingId) {
                  return bowlIdsMatch(existingId, id);
                })) {
                  return 'That bowl is already added';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Display name',
                hintText: 'Kitchen bowl',
              ),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}

class RenameBowlDialog extends StatefulWidget {
  const RenameBowlDialog({super.key, required this.bowl});

  final FoodBowlConfig bowl;

  @override
  State<RenameBowlDialog> createState() => _RenameBowlDialogState();
}

class _RenameBowlDialogState extends State<RenameBowlDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.bowl.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(_nameController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename bowl'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Display name'),
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          validator: (value) {
            if ((value ?? '').trim().isEmpty) {
              return 'Enter a display name';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
