import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:wallone/state/category_provider.dart';
import 'package:wallone/utils/constants.dart';

class CategoryManagementPage extends StatelessWidget {
  const CategoryManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mainColor(context),
      appBar: AppBar(
        title: Text(
          "Manage Categories",
          style: GoogleFonts.outfit(
            color: primaryColor(context),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: primaryColor(context)),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: mainColor(context),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategoryDialog(context),
        backgroundColor: purpleColors(context),
        child: const Icon(Icons.add),
      ),
      body: Consumer<CategoryProvider>(
        builder: (context, categoryProvider, child) {
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: categoryProvider.categories.length,
            itemBuilder: (context, index) {
              final category = categoryProvider.categories[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: boxColor(context),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: purpleColors(context).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      category.icon,
                      color: purpleColors(context),
                    ),
                  ),
                  title: Text(
                    category.name,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: primaryColor(context),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.edit,
                          color: primaryColor(context),
                        ),
                        onPressed: () =>
                            _showEditCategoryDialog(context, category),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete,
                          color: primaryColor(context),
                        ),
                        onPressed: () =>
                            _showDeleteConfirmation(context, category),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _CategoryDialog(
        title: 'Add Category',
        onSave: (name, icon) {
          context.read<CategoryProvider>().addCategory(name, icon as String);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showEditCategoryDialog(BuildContext context, Category category) {
    showDialog(
      context: context,
      builder: (context) => _CategoryDialog(
        title: 'Edit Category',
        initialName: category.name,
        initialIcon: category.icon,
        onSave: (name, icon) {
          context
              .read<CategoryProvider>()
              .updateCategory(category.name, name, icon as String);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Category category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete ${category.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<CategoryProvider>().removeCategory(category.name);
              Navigator.pop(context);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  final String title;
  final String? initialName;
  final IconData? initialIcon;
  final Function(String name, IconData icon) onSave;

  const _CategoryDialog({
    required this.title,
    this.initialName,
    this.initialIcon,
    required this.onSave,
  });

  @override
  _CategoryDialogState createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late TextEditingController _nameController;
  IconData _selectedIcon = Icons.category;
  final List<IconData> _availableIcons = [
    Icons.shopping_cart,
    Icons.fastfood,
    Icons.shopping_bag,
    Icons.receipt,
    Icons.local_grocery_store,
    Icons.sports_esports,
    Icons.people,
    Icons.home,
    Icons.school,
    Icons.attach_money,
    Icons.movie,
    Icons.directions_car,
    Icons.medical_services,
    Icons.pets,
    Icons.sports_basketball,
    Icons.flight,
    Icons.hotel,
    Icons.restaurant,
    Icons.local_bar,
    Icons.fitness_center,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    if (widget.initialIcon != null) {
      _selectedIcon = widget.initialIcon!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Category Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select Icon',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: _availableIcons.length,
                itemBuilder: (context, index) {
                  final icon = _availableIcons[index];
                  final isSelected = icon.codePoint == _selectedIcon.codePoint;
                  return InkWell(
                    onTap: () => setState(() => _selectedIcon = icon),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? purpleColors(context)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? purpleColors(context)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: isSelected ? Colors.white : Colors.grey.shade600,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    if (_nameController.text.isNotEmpty) {
                      widget.onSave(_nameController.text, _selectedIcon);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: purpleColors(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
