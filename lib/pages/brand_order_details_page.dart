import 'package:flutter/material.dart';

import 'brand_order_details_page_v2.dart' as v2;

class ShippedOrderDetailsPage extends StatelessWidget {
  const ShippedOrderDetailsPage({super.key, required this.order});
  final dynamic order;

  @override
  Widget build(BuildContext context) {
    return v2.ShippedOrderDetailsPage(order: order);
  }
}

class InProgressOrderDetailsPage extends StatelessWidget {
  const InProgressOrderDetailsPage({super.key, required this.order});
  final dynamic order;

  @override
  Widget build(BuildContext context) {
    return v2.InProgressOrderDetailsPage(order: order);
  }
}

class InReviewOrderDetailsPage extends StatelessWidget {
  const InReviewOrderDetailsPage({super.key, required this.order});
  final dynamic order;

  @override
  Widget build(BuildContext context) {
    return v2.InReviewOrderDetailsPage(order: order);
  }
}

class NewOrderDetailsPage extends StatelessWidget {
  const NewOrderDetailsPage({super.key, required this.order});
  final dynamic order;

  @override
  Widget build(BuildContext context) {
    return v2.NewOrderDetailsPage(order: order);
  }
}
