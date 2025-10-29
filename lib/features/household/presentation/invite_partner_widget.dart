import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pairwise/features/household/data/household_repository.dart';

// We'll use this to manage the loading state of the "Invite" button
final _inviteLoadingProvider = StateProvider<bool>((ref) => false);

class InvitePartnerWidget extends ConsumerStatefulWidget {
  const InvitePartnerWidget({super.key});

  @override
  ConsumerState<InvitePartnerWidget> createState() =>
      _InvitePartnerWidgetState();
}

class _InvitePartnerWidgetState extends ConsumerState<InvitePartnerWidget> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _onSendInvite() async {
    // 1. Validate the form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    ref.read(_inviteLoadingProvider.notifier).state = true;
    final email = _emailController.text;

    try {
      // 2. Call the repository
      await ref.read(householdRepositoryProvider).invitePartner(email);

      // 3. Show success and clear the field
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invite sent to $email!'),
          backgroundColor: Colors.green,
        ),
      );
      _emailController.clear();
    } catch (e) {
      // 4. Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send invite: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      ref.read(_inviteLoadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(_inviteLoadingProvider);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invite Your Partner:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: "Partner's Email",
              hintText: 'partner@example.com',
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty || !value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: isLoading ? null : _onSendInvite,
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send Invite'),
          )
        ],
      ),
    );
  }
}
