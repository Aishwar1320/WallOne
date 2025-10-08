import 'package:flutter/material.dart';
import 'package:wallone/utils/constants.dart';

class DetailedAnalyticsSheet extends StatelessWidget {
  const DetailedAnalyticsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: boxColor(context),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  boxColor(context),
                  boxColor(context).withAlpha(95),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: boxColor(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Text(
                      "📊",
                      style: TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Detailed Financial Analytics",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryColor(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAnalyticsCard(
                    "Spending Trends",
                    "📈",
                    "Your spending has increased by 15% this month compared to last month.",
                    Colors.orange,
                    context,
                  ),
                  const SizedBox(height: 16),
                  _buildAnalyticsCard(
                    "Savings Rate",
                    "💰",
                    "You're saving 18% of your income, which is above the recommended 15%.",
                    Colors.green,
                    context,
                  ),
                  const SizedBox(height: 16),
                  _buildAnalyticsCard(
                    "Category Analysis",
                    "🏷️",
                    "Food & Dining represents 35% of your monthly expenses.",
                    Colors.blue,
                    context,
                  ),
                  const SizedBox(height: 16),
                  _buildAnalyticsCard(
                    "Investment Opportunity",
                    "📊",
                    "Consider investing ₹5,000 monthly in mutual funds for long-term wealth building.",
                    Colors.purple,
                    context,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(
    String title,
    String icon,
    String description,
    Color color,
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon,
                  style: TextStyle(
                    fontSize: 20,
                    color: primaryColor(context),
                  )),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: primaryColor(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: cardTextColor(context),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
