import 'package:flutter/material.dart';
import 'package:servana/screens/verification_center_screen.dart';

// Enum to represent the different types of services a helper can offer.
enum ServiceType { tutor, pickupDriver, homeRepair, other }

class ServiceSelectionScreen extends StatelessWidget {
  const ServiceSelectionScreen({super.key});

  // Helper method to get display names for the enum
  String _getServiceTypeName(ServiceType type) {
    switch (type) {
      case ServiceType.tutor:
        return 'Tutor / Teacher';
      case ServiceType.pickupDriver:
        return 'Pickup Driver';
      case ServiceType.homeRepair:
        return 'Home Repair';
      case ServiceType.other:
        return 'Other Service';
    }
  }

  // Helper method to get display icons for the enum
  IconData _getServiceTypeIcon(ServiceType type) {
    switch (type) {
      case ServiceType.tutor:
        return Icons.school_outlined;
      case ServiceType.pickupDriver:
        return Icons.local_shipping_outlined;
      case ServiceType.homeRepair:
        return Icons.handyman_outlined;
      case ServiceType.other:
        return Icons.miscellaneous_services_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Service'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'What service will you provide?',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'This helps us tailor the verification process for you.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 48),
            // Creates a list of cards from the ServiceType enum
            ...ServiceType.values.map((service) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    leading: Icon(_getServiceTypeIcon(service), size: 40, color: theme.colorScheme.primary),
                    title: Text(_getServiceTypeName(service), style: theme.textTheme.titleMedium),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: () {
                      // Navigate to the Verification Center, passing the selected service type
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => VerificationCenterScreen(serviceType: service),
                        ),
                      );
                    },
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
