
import 'package:flutter/material.dart';
class TopUpSheet extends StatefulWidget {
  final int currentCoins; final void Function(int coins) onTopUpConfirmed;
  const TopUpSheet({super.key, required this.currentCoins, required this.onTopUpConfirmed});
  @override State<TopUpSheet> createState()=>_TopUpSheetState();
}
class _TopUpSheetState extends State<TopUpSheet> {
  int _selected=500;
  @override Widget build(BuildContext context){
    return SafeArea(child:Padding(padding:const EdgeInsets.all(16.0),child:Column(
      mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children:[
        Text('Top up coins', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:8),
        Wrap(spacing:8, children:[500,1000,2500].map((v)=>ChoiceChip(label:Text('+$v'),
          selected:_selected==v, onSelected:(_)=>setState(()=>_selected=v))).toList()),
        const SizedBox(height:12),
        TextField(keyboardType: TextInputType.number, decoration: const InputDecoration(
          labelText:'Custom amount (coins)', hintText:'Enter coins…'),
          onChanged:(s){final v=int.tryParse(s)??_selected; setState(()=>_selected=v);}),
        const SizedBox(height:12),
        ElevatedButton(onPressed:()=>widget.onTopUpConfirmed(_selected), child: const Text('Confirm top up')),
        const SizedBox(height:8),
        Text('Why coins? Faster escrow, instant booking, and incentives.', style: Theme.of(context).textTheme.bodySmall),
    ])));}
}
