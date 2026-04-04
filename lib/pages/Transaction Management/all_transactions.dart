import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallone/common_widgets/ads/banner_ad_widget.dart';
import 'package:wallone/common_widgets/dynamic_buttons.dart';
import 'package:wallone/common_widgets/filter_control.dart';
import 'package:wallone/state/list_provider.dart';
import 'package:wallone/common_widgets/item_list.dart';
import 'package:wallone/state/userprofile_provider.dart';
import 'package:wallone/utils/constants.dart';

class SeeAllTransactionsPage extends StatefulWidget {
  const SeeAllTransactionsPage({super.key});

  @override
  State<SeeAllTransactionsPage> createState() => _SeeAllTransactionsPageState();
}

class _SeeAllTransactionsPageState extends State<SeeAllTransactionsPage> {
  bool isExpensesSelected = true;
  String selectedPeriod = 'All Transactions';
  DateTime? _selectedDate;

  void _showDateTimePicker(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(builder: (context, setModalState) {
        final pickerKey = ValueKey(_selectedDate?.millisecondsSinceEpoch ?? 0);
        return Container(
          decoration: BoxDecoration(
            color: mainColor(context),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Text(
                    'Select Date',
                    style: GoogleFonts.outfit(
                      fontSize: screenWidth / 20,
                      fontWeight: FontWeight.bold,
                      color: primaryColor(context),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    color: primaryColor(context),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              CupertinoTheme(
                data: CupertinoThemeData(
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: GoogleFonts.outfit(
                      fontSize: screenWidth / 25,
                      color: cardTextColor(context),
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: boxColor(context),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: shadowColor(context).withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CupertinoDatePicker(
                        key: pickerKey,
                        mode: CupertinoDatePickerMode.date,
                        initialDateTime: _selectedDate ?? DateTime.now(),
                        onDateTimeChanged: (DateTime newDateTime) {
                          setModalState(() {
                            _selectedDate = newDateTime;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: boxColor(context),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: shadowColor(context).withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _selectedDate != null
                                  ? DateFormat('yyyy-MM-dd')
                                      .format(_selectedDate!)
                                  : 'No date selected',
                              style: GoogleFonts.outfit(
                                fontSize: screenWidth / 30,
                                color: cardTextColor(context),
                              ),
                            ),
                          ),
                          IconButton(
                            iconSize: screenWidth / 15,
                            icon: const Icon(Icons.check_circle),
                            color: purpleColors(context),
                            onPressed: () {
                              if (_selectedDate != null) {
                                final selectedDateString =
                                    DateFormat('yyyy-MM-dd')
                                        .format(_selectedDate!);
                                setState(() {
                                  selectedPeriod = selectedDateString;
                                });

                                context.read<ListProvider>().setFilter(
                                      isExpensesSelected: isExpensesSelected,
                                      period: selectedDateString,
                                      isActive: true,
                                    );
                                Navigator.pop(context);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userHasPremium = context.read<UserProfileProvider>().isPremium;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          "T R A N S A C T I O N S",
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
      body: Column(
        children: [
          /// Filters Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DynamicButtonsWidget(
                    onSelectionChanged: (value) {
                      setState(() {
                        isExpensesSelected = value;
                      });

                      context.read<ListProvider>().setFilter(
                            isExpensesSelected: value,
                            period: selectedPeriod,
                            isActive: selectedPeriod != 'All Transactions',
                          );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TransactionFilterControls(
                    isExpensesSelected: isExpensesSelected,
                    selectedPeriod: selectedPeriod,
                    showCustomDateOption: true,
                    onTypeChanged: (value) {
                      setState(() {
                        isExpensesSelected = value;
                      });
                    },
                    onPeriodChanged: (period) {
                      if (period == 'Custom_Date') {
                        _showDateTimePicker(context);
                        return;
                      }

                      final newPeriod = period ?? 'All Transactions';

                      setState(() {
                        selectedPeriod = newPeriod;
                      });

                      context.read<ListProvider>().setFilter(
                            isExpensesSelected: isExpensesSelected,
                            period: newPeriod,
                            isActive: newPeriod != 'All Transactions',
                          );
                    },
                  ),
                ),
              ],
            ),
          ),

          /// Transaction List
          Expanded(
            child: Consumer<ListProvider>(
              builder: (context, listProvider, child) {
                final transactions = listProvider.getFilteredTransactions(
                  isExpensesSelected,
                  selectedPeriod,
                );

                // Group transactions by date
                final Map<String, List<AllListProvider>> groupedTransactions =
                    {};
                for (final transaction in transactions) {
                  DateTime parsedDate;
                  try {
                    parsedDate = DateTime.parse(transaction.date);
                  } catch (e) {
                    parsedDate =
                        DateFormat('dd-MM-yyyy').parse(transaction.date);
                  }
                  final dateKey = DateFormat('yyyy-MM-dd').format(parsedDate);
                  (groupedTransactions[dateKey] ??= []).add(transaction);
                }

                final sortedDates = groupedTransactions.keys.toList()
                  ..sort((a, b) => b.compareTo(a));

                if (transactions.isEmpty) {
                  return Center(
                    child: Text(
                      "No Transactions Found",
                      style: GoogleFonts.outfit(
                        color: primaryColor(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedDates.length,
                  itemBuilder: (context, index) {
                    final date = sortedDates[index];
                    final isLastItem = index == sortedDates.length - 1;

                    return Column(
                      children: [
                        ItemListWidget(
                          transactions: groupedTransactions[date]!,
                        ),
                        if (!userHasPremium && !isLastItem)
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: BannerAdWidget(),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
