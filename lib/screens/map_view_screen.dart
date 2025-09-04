import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:servana/widgets/helper_card.dart';
import 'package:servana/screens/helper_public_profile_screen.dart';

class BrowseMapView extends StatefulWidget {
  const BrowseMapView({super.key, this.category, required this.query, required this.serviceMode, required this.openNow});
  final String? category; final String query; final String serviceMode; final bool openNow;
  @override State<BrowseMapView> createState() => _BrowseMapViewState();
}

class _BrowseMapViewState extends State<BrowseMapView> {
  Map<String, dynamic>? _selected;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = FirebaseFirestore.instance.collection('users').where('isHelper', isEqualTo: true).limit(80);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: base.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        var helpers = snap.data!.docs.map((d) => d.data()..['id']=d.id).toList();
        if (widget.category!=null && widget.category!.isNotEmpty) {
          helpers = helpers.where((h)=> (h['categories']??h['primaryCategory']??'').toString().toLowerCase().contains(widget.category!.toLowerCase())).toList();
        }
        if (widget.query.isNotEmpty) {
          helpers = helpers.where((h){ final hay='${h['displayName']??''} ${h['bio']??''} ${h['categories']??''}'.toString().toLowerCase(); return hay.contains(widget.query.toLowerCase()); }).toList();
        }
        if (widget.serviceMode=='Online') { helpers = helpers.where((h)=>(h['supportsOnline']??false)==true).toList(); }
        else { helpers = helpers.where((h)=>(h['supportsPhysical']??true)==true).toList(); }
        if (widget.openNow) { helpers = helpers.where((h)=>(h['presence']?['isLive']??false)==true).toList(); }
        final withLoc = helpers.where((h)=>h['location']?['lat']!=null && h['location']?['lng']!=null).toList();
        if (withLoc.isEmpty) {
          return Center(child: Container(margin: const EdgeInsets.all(16),padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cs.surface,borderRadius: BorderRadius.circular(16),border: Border.all(color: cs.outline.withOpacity(0.12))),
              child: const Text('No location-enabled helpers for the current filters.')));
        }
        final lats = withLoc.map((h)=>(h['location']['lat'] as num).toDouble()).toList();
        final lngs = withLoc.map((h)=>(h['location']['lng'] as num).toDouble()).toList();
        final minLat = lats.reduce(math.min), maxLat = lats.reduce(math.max);
        final minLng = lngs.reduce(math.min), maxLng = lngs.reduce(math.max);
        final latPad = (maxLat-minLat)*0.05+0.0001, lngPad=(maxLng-minLng)*0.05+0.0001;

        return Stack(children: [
          Positioned.fill(child: Container(
            decoration: BoxDecoration(gradient: LinearGradient(colors:[cs.surfaceVariant, cs.surface], begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: LayoutBuilder(builder:(context,box)=>Stack(children:[
              for (final h in withLoc) _MarkerButton(
                left: _mapX(h['location']['lng'], minLng-lngPad, maxLng+lngPad, box.maxWidth),
                top:  _mapY(h['location']['lat'], minLat-latPad, maxLat+latPad, box.maxHeight),
                onTap: ()=>setState(()=>_selected=h), tooltip: h['displayName']?.toString()??'Helper',
              ),
            ])),
          )),
          if (_selected!=null) _BottomCard(
            child: HelperCard(
              data: _selected!,
              onViewProfile: () => Navigator.of(context).push(MaterialPageRoute(builder: (_)=>HelperPublicProfileScreen(helperId: _selected!['id']))),
            ),
            onClose: ()=>setState(()=>_selected=null),
          ),
        ]);
      },
    );
  }
  double _mapX(double lng,double minLng,double maxLng,double w){ if(maxLng==minLng)return w/2; return ((lng-minLng)/(maxLng-minLng))*(w-24)+12; }
  double _mapY(double lat,double minLat,double maxLat,double h){ if(maxLat==minLat)return h/2; final t=(lat-minLat)/(maxLat-minLat); return (1-t)*(h-24)+12; }
}
class _MarkerButton extends StatelessWidget {
  const _MarkerButton({required this.left, required this.top, required this.onTap, required this.tooltip});
  final double left, top; final VoidCallback onTap; final String tooltip;
  @override Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Positioned(left:left-12, top:top-12, child: Tooltip(message: tooltip, child: InkWell(
      onTap:onTap, borderRadius: BorderRadius.circular(16),
      child: Ink(width:32,height:32,decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle, boxShadow:[BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius:6, offset: Offset(0,2))]), child: const Icon(Icons.place_rounded, size:18)),
    )));
  }
}
class _BottomCard extends StatelessWidget {
  const _BottomCard({required this.child, required this.onClose}); final Widget child; final VoidCallback onClose;
  @override Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Positioned(left:0,right:0,bottom:0, child: AnimatedContainer(
      duration: const Duration(milliseconds:250), padding: const EdgeInsets.fromLTRB(16,12,16,16),
      decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border(top: BorderSide(color: cs.outline.withOpacity(0.12)))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width:44,height:4, decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(4))),
        const SizedBox(height:12), child, const SizedBox(height:12),
        TextButton.icon(onPressed: onClose, icon: const Icon(Icons.expand_more_rounded), label: const Text('Hide')),
      ]),
    ));
  }
}
// Shim to satisfy old references like `const MapViewScreen()`.
class MapViewScreen extends StatelessWidget {
  const MapViewScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: BrowseMapView(category: null, query: '', serviceMode: 'Physical', openNow: false),
  );
}
