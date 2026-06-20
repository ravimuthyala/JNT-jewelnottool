import 'package:flutter/material.dart';

class NailSizingKitSection extends StatelessWidget {
  const NailSizingKitSection({
    super.key,
    required this.purchased,
    required this.onAddToCart,
  });

  final bool purchased;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    const blackCat = Color(0xFF292222);
    const alabaster = Color(0xFFF4EFE1);
    const snow = Color(0xFFFAF9F9);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(
          color: purchased ? blackCat.withValues(alpha: 0.35) : alabaster,
        ),
        boxShadow: [
          BoxShadow(
            color: blackCat.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nail Sizing Kit',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: 'Arial',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Purchase a sizing kit to ensure perfect fit for your nails. The kit includes sample sizes and a measuring tool.',
            style: TextStyle(color: blackCat.withValues(alpha: 0.55), height: 1.25,fontSize: 14, fontWeight: FontWeight.w400),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  color: alabaster,
                  borderRadius: BorderRadius.zero,
                ),
                child: const Icon(Icons.straighten, color: blackCat),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nail Sizing Kit Product',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        fontFamily: 'Arial',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$3.00',
                      style: TextStyle(
                        color: blackCat.withValues(alpha: 0.70),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Arial',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (purchased)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: blackCat,
                    borderRadius: BorderRadius.zero,
                  ),
                  child: const Text(
                    'Purchased',
                    style: TextStyle(
                      color: snow,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      fontFamily: 'Arial',
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blackCat,
                      foregroundColor: snow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    onPressed: onAddToCart,
                    child: const Text(
                      'Add to Cart',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 14,
                        fontFamily: 'Arial',
                        color:snow
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
