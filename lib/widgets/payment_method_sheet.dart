
import 'package:flutter/material.dart';
enum PosterPaymentChoice { coins, card, bank }
class PaymentMethodSheet extends StatelessWidget {
  final void Function(PosterPaymentChoice choice) onSelected; final String? subtitle;
  const PaymentMethodSheet({super.key, required this.onSelected, this.subtitle});
  @override Widget build(BuildContext context){
    return SafeArea(child:Padding(padding:const EdgeInsets.all(16.0),child:Column(
      mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children:[
        Text('Choose a payment method', style: Theme.of(context).textTheme.titleLarge),
        if(subtitle!=null) Padding(padding: const EdgeInsets.only(top:4,bottom:12),
          child: Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium)),
        const SizedBox(height:8),
        _tile(context, Icons.savings_outlined, 'Coins wallet', 'Fastest for escrow & deposits', PosterPaymentChoice.coins),
        _tile(context, Icons.credit_card, 'Card', 'Authorize to escrow, captured on completion', PosterPaymentChoice.card),
        _tile(context, Icons.account_balance, 'Bank transfer', 'Upload slip, limited invites until verified', PosterPaymentChoice.bank),
        const SizedBox(height:8),
    ])));}
  Widget _tile(BuildContext c, IconData i, String t, String s, PosterPaymentChoice choice){
    return Card(margin: const EdgeInsets.symmetric(vertical:6),
      child: ListTile(leading: Icon(i), title: Text(t), subtitle: Text(s), onTap: ()=>onSelected(choice)));
  }
}
