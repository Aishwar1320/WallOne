import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallone/pages/edit_transactions.dart';
import 'package:wallone/state/balance_provider.dart';
import 'package:wallone/state/budget_provider.dart';
import 'package:wallone/state/list_provider.dart';
import 'package:wallone/state/category_provider.dart';
import 'package:wallone/utils/constants.dart';
import 'package:wallone/utils/animations.dart';

class ItemListWidget extends StatefulWidget {
  final List<AllListProvider> transactions;

  const ItemListWidget({
    Key? key,
    required this.transactions,
  }) : super(key: key);

  @override
  _ItemListWidgetState createState() => _ItemListWidgetState();
}

class _ItemListWidgetState extends State<ItemListWidget> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    if (widget.transactions.isEmpty) {
      return Center(
        child: Text(
          "No transactions available",
          style: TextStyle(fontSize: 18, color: primaryColor(context)),
        ),
      );
    }

    // Use the date from the first transaction as the header text.
    String headerDate;
    String rawDate = widget.transactions[0].date;
    DateTime parsedDate;

    // If the date is in "dd-MM" format (length <= 5), append the current year.
    if (rawDate.length <= 5) {
      parsedDate =
          DateFormat('dd-MM-yyyy').parse('$rawDate-${DateTime.now().year}');
    } else {
      parsedDate = DateTime.parse(rawDate);
    }
    headerDate = DateFormat('dd-MM').format(parsedDate);

    // Build the list of transaction widgets.
    List<Widget> widgetList = widget.transactions.asMap().entries.map((entry) {
      final int index = entry.key;
      final transaction = entry.value;
      final code = context.read<BalanceProvider>().currencyCode;
      final symbol = NumberFormat.simpleCurrency(name: code).currencySymbol;

      return StaggeredListAnimation(
        index: index,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Slidable(
            closeOnScroll: true,
            key: ValueKey(transaction.id),

            // Both actions appear on swiping from right-to-left.
            endActionPane: ActionPane(
              motion: const DrawerMotion(),

              // Adjust extentRatio to accommodate both buttons.
              extentRatio: 0.40,
              children: [
                CustomSlidableAction(
                  onPressed: (actionContext) async {
                    // Use parent's context instead of actionContext.
                    final parentContext = this.context;
                    bool? confirm = await showDialog<bool>(
                      context: parentContext,
                      builder: (dialogContext) {
                        return AlertDialog(
                          title: const Text(
                            "Delete Transaction",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          content: const Text(
                            "Are you sure you want to delete this transaction?",
                            style: TextStyle(fontSize: 16),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              child: Text(
                                "Cancel",
                                style: TextStyle(
                                    color: primaryColor(parentContext),
                                    fontSize: 16),
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(true),
                              child: Text(
                                "Delete",
                                style: TextStyle(
                                    color: purpleColors(parentContext),
                                    fontSize: 16),
                              ),
                            ),
                          ],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          elevation: 8.0,
                          backgroundColor: snackbarColor(parentContext),
                        );
                      },
                    );
                    if (!mounted) return;
                    if (confirm == true) {
                      Provider.of<ListProvider>(parentContext, listen: false)
                          .removeTransaction(transaction.id, parentContext);
                    }
                  },
                  backgroundColor: purpleColors(context),
                  child: const Icon(
                    Icons.delete_outlined,
                    size: 25,
                    color: Colors.white,
                  ),
                ),
                CustomSlidableAction(
                  onPressed: (actionContext) {
                    // For edit, you can still use the parent's context.
                    _editTransaction(this.context, transaction);
                  },
                  backgroundColor: purpleColors(context),
                  borderRadius: const BorderRadius.only(
                    bottomRight: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  child: const Icon(
                    Icons.edit_square,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: boxColor(context),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 5,
                    offset: const Offset(1, 1),
                    color: shadowColor(context),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Consumer<CategoryProvider>(
                          builder: (context, categoryProvider, child) {
                            final iconKey = categoryProvider
                                .getIconForCategory(transaction.category);
                            final iconData = iconMap[iconKey] ??
                                Icons.category; // map string → IconData

                            return IconButton(
                              icon: Icon(iconData),
                              iconSize: 25,
                              color: primaryColor(context),
                              onPressed: () {},
                            );
                          },
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              transaction.category,
                              style: GoogleFonts.outfit(
                                fontSize: 17,
                                color: primaryColor(context),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              transaction.title,
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                color: purpleColors(context),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "$symbol${transaction.amount}",
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              color: primaryColor(context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: inversePrimaryColor(context),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              blurRadius: 5,
              offset: const Offset(1, 1),
              blurStyle: BlurStyle.solid,
              color: shadowColor(context),
            )
          ],
        ),
        child: Column(
          children: [
            // Header displaying the date from the first transaction.
            ScaleInTransition(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.only(left: 20.0, top: 10, bottom: 10),
                  color: Colors.transparent,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        headerDate,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          color: primaryColor(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 20.0),
                        child: Icon(
                          _isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: primaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Expandable list area.
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: _isExpanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: widgetList,
              ),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editTransaction(
      BuildContext parentContext, AllListProvider transaction) async {
    final updatedTransaction = await Navigator.push(
      parentContext,
      MaterialPageRoute(
        builder: (context) => EditTransactionPage(transaction: transaction),
      ),
    );
    if (!mounted) return;
    if (updatedTransaction != null) {
      Provider.of<ListProvider>(parentContext, listen: false)
          .editTransaction(updatedTransaction);
    }
  }
}
