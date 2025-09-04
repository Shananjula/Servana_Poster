
import 'package:flutter/material.dart';
enum TaskMode { online, physical }
class FiltersChipRow extends StatelessWidget {
  final TaskMode mode; final void Function(TaskMode) onModeChanged; final VoidCallback onOpenFilters;
  const FiltersChipRow({super.key, required this.mode, required this.onModeChanged, required this.onOpenFilters});
  @override Widget build(BuildContext context){
    return Wrap(spacing:8, children:[
      ChoiceChip(label: const Text('Online'), selected: mode==TaskMode.online, onSelected:(_)=>onModeChanged(TaskMode.online)),
      ChoiceChip(label: const Text('Physical'), selected: mode==TaskMode.physical, onSelected:(_)=>onModeChanged(TaskMode.physical)),
      ActionChip(label: const Text('Filters'), onPressed: onOpenFilters),
    ]);
  }
}
