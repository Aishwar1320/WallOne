// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:wallone/pages/analytics.dart';
// import 'package:wallone/pages/budget_page.dart';
// import 'package:wallone/utils/constants.dart';
// import 'package:wallone/pages/add_transactions.dart';
// import 'package:wallone/utils/layout.dart';

// class FloatingNavigationBar extends StatelessWidget {
//   const FloatingNavigationBar({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return ClipRRect(
//       borderRadius: BorderRadius.circular(20.0),
//       child: BottomAppBar(
//         elevation: 8,
//         color: inversePrimaryColor(context),
//         shadowColor: shadowColor(context),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             IconButton(
//               onPressed: () {
//                 Navigator.push(context, MaterialPageRoute(
//                   builder: (context) {
//                     return const DesignLayout();
//                   },
//                 ));
//               },
//               icon: const Icon(
//                 Icons.home_outlined,
//                 size: 30,
//               ),
//             ),
//             IconButton(
//               onPressed: () {
//                 Navigator.push(context, MaterialPageRoute(
//                   builder: (context) {
//                     return const BudgetPage();
//                   },
//                 ));
//               },
//               icon: const Icon(
//                 Icons.account_balance_wallet_outlined,
//                 size: 27,
//               ),
//             ),
//             SizedBox(
//               height: double.infinity,
//               child: FloatingActionButton(
//                 elevation: 10,
//                 onPressed: () {
//                   Navigator.push(context, MaterialPageRoute(
//                     builder: (context) {
//                       return const AddTransactionsPage();
//                     },
//                   ));
//                 },
//                 backgroundColor: primaryColor(context),
//                 child: Text(
//                   "₹",
//                   style: GoogleFonts.outfit(
//                     fontSize: 25,
//                     fontWeight: FontWeight.bold,
//                     color: purpleColors(context),
//                   ),
//                 ),
//               ),
//             ),
//             IconButton(
//               onPressed: () {
//                 Navigator.push(context, MaterialPageRoute(
//                   builder: (context) {
//                     return const AnalyticsPage();
//                   },
//                 ));
//               },
//               icon: const Icon(
//                 Icons.analytics_outlined,
//                 size: 30,
//               ),
//             ),
//             IconButton(
//               onPressed: () {
//                 // Navigate to Profile
//                 showCustomSnackBar(context);
//               },
//               icon: const Icon(
//                 Icons.person_2_outlined,
//                 size: 30,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
