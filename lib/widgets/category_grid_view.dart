import 'package:flutter/material.dart';

class Category {
  final String name;
  final IconData icon;
  final Color color;

  Category({required this.name, required this.icon, required this.color});
}

class CategoryGridView extends StatelessWidget {
  final Function(String) onCategoryTap;

  const CategoryGridView({super.key, required this.onCategoryTap});

  @override
  Widget build(BuildContext context) {
    final List<Category> categories = [
      Category(name: 'Cleaning', icon: Icons.cleaning_services_rounded, color: Colors.lightBlue),
      Category(name: 'Repairs', icon: Icons.build_rounded, color: Colors.orange),
      Category(name: 'Delivery', icon: Icons.delivery_dining_rounded, color: Colors.green),
      Category(name: 'Tutoring', icon: Icons.school_rounded, color: Colors.purple),
      Category(name: 'Design', icon: Icons.design_services_rounded, color: Colors.pink),
      Category(name: 'Moving', icon: Icons.local_shipping_rounded, color: Colors.brown),
      Category(name: 'Events', icon: Icons.celebration_rounded, color: Colors.red),
      Category(name: 'More', icon: Icons.apps_rounded, color: Colors.grey),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return GestureDetector(
          onTap: () => onCategoryTap(category.name),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: category.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(category.icon, size: 30, color: category.color),
              ),
              const SizedBox(height: 8),
              Text(
                category.name,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}
