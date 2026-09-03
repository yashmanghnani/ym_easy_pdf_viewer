import 'package:flutter/material.dart';
import 'package:numberpicker/numberpicker.dart';

class PagePicker extends StatefulWidget {
  const PagePicker({
    required this.title,
    required this.maxValue,
    required this.initialValue,
    this.numberPickerConfirmWidget,
    super.key,
  });

  final String title;
  final int maxValue;
  final int initialValue;
  final Widget? numberPickerConfirmWidget;

  @override
  State<PagePicker> createState() => _PagePickerState();
}

class _PagePickerState extends State<PagePicker> {
  late int _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.initialValue;
  }

  @override
  void didUpdateWidget(PagePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      _currentValue = widget.initialValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: NumberPicker(
        minValue: 1,
        maxValue: widget.maxValue,
        value: _currentValue,
        onChanged: (int value) => setState(() => _currentValue = value),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(_currentValue),
          child: widget.numberPickerConfirmWidget ?? const Text('OK'),
        ),
      ],
    );
  }
}
