import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import 'package:wallone/common_widgets/dropdown_menu.dart';
import 'package:wallone/state/balance_provider.dart';
import 'package:wallone/state/transaction_type_provider.dart';
import 'package:wallone/utils/constants.dart';
import 'package:wallone/state/list_provider.dart';
import 'package:wallone/state/category_provider.dart';

class AddTransactionsPage extends StatefulWidget {
  const AddTransactionsPage({super.key});

  @override
  State<AddTransactionsPage> createState() => _AddTransactionsPageState();
}

class _AddTransactionsPageState extends State<AddTransactionsPage> {
  final TextEditingController _controller = TextEditingController();
  double _fieldWidth = 50;

  String? selectedTitle;
  String? selectedCategory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TransactionTypeProvider>(context, listen: false)
          .resetToExpenses();
    });
    _controller.addListener(_updateFieldWidth);
  }

  void _updateFieldWidth() {
    final textSize = (TextPainter(
      text: TextSpan(
        text: _controller.text.isEmpty ? "0" : _controller.text,
        style: GoogleFonts.outfit(
          fontSize: 70,
          fontWeight: FontWeight.bold,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout())
        .size;

    setState(() {
      _fieldWidth = textSize.width + 5;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = context.read<BalanceProvider>().currencyCode;
    final symbol = intl.NumberFormat.simpleCurrency(name: code).currencySymbol;

    final transactionTypeProvider =
        Provider.of<TransactionTypeProvider>(context);
    final listProvider = Provider.of<ListProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: mainColor(context),
      appBar: AppBar(
        title: Text(
          "Add Transactions",
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
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: DropdownMenuDynamicWidget(
                    boxColor: boxColor(context),
                    hintText: "Pay Via",
                    items: const [
                      "Cash",
                      "Card",
                      "Gpay",
                      "PhonePay",
                      "NetBanking"
                    ],
                    onItemSelected: (value) {
                      setState(() {
                        selectedTitle = value;
                      });
                    },
                    value: selectedTitle,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Consumer<CategoryProvider>(
                    builder: (context, categoryProvider, child) {
                      final categories = categoryProvider.categories;
                      return DropdownMenuDynamicWidget(
                        boxColor: boxColor(context),
                        hintText: "Type",
                        items: categories.map((c) => c.name).toList(),
                        onItemSelected: (value) {
                          setState(() {
                            selectedCategory = value;
                          });
                        },
                        value: selectedCategory,
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            TextButton(
              onPressed: () {
                transactionTypeProvider.toggleTransactionType();
              },
              child: Text(
                transactionTypeProvider.isExpensesSelected
                    ? "Expenses"
                    : "Income",
                style: GoogleFonts.outfit(
                  color: primaryColor(context),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  symbol,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: purpleColors(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(
                  width: _fieldWidth,
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 70,
                      color: primaryColor(context),
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: "0",
                      hintStyle: TextStyle(
                        color: primaryColor(context),
                      ),
                      border: InputBorder.none,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(7),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: GestureDetector(
                onTap: () {
                  final submittedAmount =
                      double.tryParse(_controller.text) ?? 0;

                  if (submittedAmount > 0 &&
                      selectedTitle != null &&
                      selectedCategory != null) {
                    Provider.of<BalanceProvider>(context, listen: false);
                    final isIncome = !transactionTypeProvider
                        .isExpensesSelected; // Determine if it's income or expense

                    final newTransaction = AllListProvider(
                      title: selectedTitle!,
                      category: selectedCategory!,
                      amount: submittedAmount,
                      isIncome: isIncome, // Pass the correct value for isIncome
                    );

                    listProvider.addTransaction(newTransaction);
                    _controller.clear();
                    Navigator.pop(context);
                  } else {
                    // Show an error message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          submittedAmount <= 0
                              ? "Please enter a valid amount."
                              : "Please select all fields.",
                          style: GoogleFonts.outfit(fontSize: 16),
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    height: 70,
                    width: 70,
                    decoration: BoxDecoration(
                      color: inversePrimaryColor(context),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 10,
                          color: shadowColor(context),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.arrow_forward_ios),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
