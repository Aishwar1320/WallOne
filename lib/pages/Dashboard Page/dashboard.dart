import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallone/common_widgets/ads/banner_ad_widget.dart';
import 'package:wallone/common_widgets/dynamic_buttons.dart';
import 'package:wallone/common_widgets/filter_control.dart';
import 'package:wallone/common_widgets/health_score_card.dart';
import 'package:wallone/common_widgets/item_list.dart';
import 'package:wallone/common_widgets/total_expense.dart';
import 'package:wallone/state/adviser_provider.dart';
import 'package:wallone/state/balance_provider.dart';
import 'package:wallone/state/list_provider.dart';
import 'package:wallone/state/userprofile_provider.dart';
import 'package:wallone/utils/constants.dart';

class DashboardPage extends StatefulWidget {
  final Function(bool isBalanceVisible) onBalanceVisibilityChanged;
  const DashboardPage({
    super.key,
    required this.onBalanceVisibilityChanged,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool isExpensesSelected = true;
  String selectedPeriod = 'All Transactions';

  final ScrollController _scrollController = ScrollController();
  bool isBalanceVisible = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    // When scroll offset > 80, assume the Balance section is off-screen
    if (_scrollController.offset > 80 && isBalanceVisible) {
      setState(() {
        isBalanceVisible = false;
      });
      widget.onBalanceVisibilityChanged(false);
    } else if (_scrollController.offset <= 80 && !isBalanceVisible) {
      setState(() {
        isBalanceVisible = true;
      });
      widget.onBalanceVisibilityChanged(true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = context.read<BalanceProvider>().currencyCode;
    final symbol = NumberFormat.simpleCurrency(name: code).currencySymbol;
    final balanceProvider = Provider.of<BalanceProvider>(context);
    final userHasPremium = context.read<UserProfileProvider>().isPremium;

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Scroll Below - Balance Section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Hero(
                tag: 'balanceHero',
                child: Material(
                  color: Colors.transparent,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, anim) {
                      final offsetAnim = anim.drive(
                        Tween<Offset>(
                                begin: const Offset(0, 0.25), end: Offset.zero)
                            .chain(
                          CurveTween(curve: Curves.easeOut),
                        ),
                      );
                      return SlideTransition(
                        position: offsetAnim,
                        child: FadeTransition(
                          opacity: anim,
                          child: child,
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Balance',
                          style: GoogleFonts.outfit(
                            fontSize: 30,
                            color: purpleColors(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          symbol + balanceProvider.totalBalance.toString(),
                          key: ValueKey(balanceProvider.totalBalance),
                          style: GoogleFonts.outfit(
                            fontSize: 35,
                            color: primaryColor(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Stick at top - Filter Controls
        SliverStickyHeader(
          sticky: true,
          header: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
            child: Container(
              decoration: BoxDecoration(
                color: inversePrimaryColor(context),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor(context).withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10.0,
                  vertical: 10,
                ),
                child: Column(
                  spacing: 20,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          flex: 3,
                          child: DynamicButtonsWidget(
                            onSelectionChanged: (isExpensesSelected) {
                              setState(() {
                                this.isExpensesSelected = isExpensesSelected;
                              });

                              Provider.of<ListProvider>(context, listen: false)
                                  .setFilter(
                                isExpensesSelected: isExpensesSelected,
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
                            onTypeChanged: (value) =>
                                setState(() => isExpensesSelected = value),
                            onPeriodChanged: (period) {
                              final newPeriod = period ?? 'All Transactions';
                              setState(() {
                                selectedPeriod = newPeriod;
                              });

                              Provider.of<ListProvider>(context, listen: false)
                                  .setFilter(
                                isExpensesSelected: isExpensesSelected,
                                period: newPeriod,
                                isActive: newPeriod != 'All Transactions',
                              );
                            },
                          ),
                        )
                      ],
                    ),
                    // Show only daily box for specific dates, otherwise show all three
                    selectedPeriod != 'All Transactions'
                        ? Row(
                            spacing: 20,
                            children: [
                              Expanded(
                                child: SizedBox(
                                  child: TotalExpenseBoxWidget(
                                    label: "D A Y",
                                    balanceType: 'daily',
                                    isExpensesSelected: isExpensesSelected,
                                    selectedPeriod: selectedPeriod,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Card(
                                  color: Colors.transparent,
                                  elevation: 0,
                                  child: Text(
                                    "Total for selected period",
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      color: primaryColor(context),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            spacing: 10,
                            children: [
                              Expanded(
                                child: TotalExpenseBoxWidget(
                                  label: "D A Y",
                                  balanceType: 'daily',
                                  isExpensesSelected: isExpensesSelected,
                                  selectedPeriod: selectedPeriod,
                                ),
                              ),
                              Expanded(
                                child: TotalExpenseBoxWidget(
                                  label: "W E E K",
                                  balanceType: 'weekly',
                                  isExpensesSelected: isExpensesSelected,
                                ),
                              ),
                              Expanded(
                                child: TotalExpenseBoxWidget(
                                  label: "M O N T H",
                                  balanceType: 'monthly',
                                  isExpensesSelected: isExpensesSelected,
                                ),
                              ),
                            ],
                          ),
                  ],
                ),
              ),
            ),
          ),
          sliver: userHasPremium
              ? SliverToBoxAdapter(
                  child: Padding(
                      padding: const EdgeInsets.only(
                        left: 16.0,
                        right: 16,
                      ),
                      child: HealthScoreSection(
                        provider: context.read<AIAdvisorProvider>(),
                      )),
                )
              : null,
        ),

        // Stick at top - Transactions Header
        SliverStickyHeader(
          sticky: true,
          header: Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: 16,
              top: userHasPremium ? 16 : 0,
            ),
            color: mainColor(context),
            child: Text(
              "T R A N S A C T I O N S",
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 20,
                color: primaryColor(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // List
          sliver: Consumer<ListProvider>(
            key: ValueKey('${isExpensesSelected}_$selectedPeriod'),
            builder: (context, listProvider, child) {
              final transactions = listProvider.getFilteredTransactions(
                isExpensesSelected,
                selectedPeriod,
              );

              // Group transactions by date
              final Map<String, List<AllListProvider>> groupedTransactions = {};
              for (final transaction in transactions) {
                DateTime parsedDate;
                try {
                  parsedDate = DateTime.parse(transaction.date);
                } catch (e) {
                  parsedDate = DateFormat('dd-MM-yyyy').parse(transaction.date);
                }
                final dateKey = DateFormat('yyyy-MM-dd').format(parsedDate);
                (groupedTransactions[dateKey] ??= []).add(transaction);
              }

              // Sort dates descending
              final sortedDates = groupedTransactions.keys.toList()
                ..sort((a, b) => b.compareTo(a));

              // Return SliverList with proper delegate
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final date = sortedDates[index];
                    final isLastItem = index == sortedDates.length - 1;
                    return Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                            left: 16.0,
                            right: 16,
                            bottom: isLastItem ? 100 : 16.0,
                          ),
                          child: Column(
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
                          ),
                        ),
                      ],
                    );
                  },
                  childCount: sortedDates.length,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
