import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ColorPickerWidget extends StatelessWidget {
  final int selectedColorValue;
  final ValueChanged<int> onColorChanged;

  const ColorPickerWidget({
    super.key,
    required this.selectedColorValue,
    required this.onColorChanged,
  });

  // 洗練された12色のプリセットカラー
  static const List<int> presetColors = [
    0xFF3B82F6, // Blue
    0xFF06B6D4, // Cyan
    0xFF10B981, // Emerald
    0xFF84CC16, // Lime
    0xFFF59E0B, // Amber
    0xFFF97316, // Orange
    0xFFEF4444, // Red / Coral
    0xFFEC4899, // Pink
    0xFF8B5CF6, // Purple
    0xFF6366F1, // Indigo
    0xFF14B8A6, // Teal
    0xFF64748B, // Slate
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '予定カラー',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.palette_outlined, size: 16),
              label: const Text('カスタム', style: TextStyle(fontSize: 12)),
              onPressed: () => _showCustomColorPicker(context),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...presetColors.map((colorVal) {
              final isSelected = selectedColorValue == colorVal;
              return InkWell(
                onTap: () => onColorChanged(colorVal),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Color(colorVal),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(colorVal).withValues(alpha: isSelected ? 0.6 : 0.2),
                        blurRadius: isSelected ? 8 : 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 18,
                        )
                      : null,
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  void _showCustomColorPicker(BuildContext context) {
    Color pickerColor = Color(selectedColorValue);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('カスタムカラー選択'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (color) {
                pickerColor = color;
              },
              pickerAreaHeightPercent: 0.7,
              enableAlpha: false,
              displayThumbColor: true,
              paletteType: PaletteType.hsvWithHue,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () {
                onColorChanged(pickerColor.toARGB32());
                Navigator.of(dialogContext).pop();
              },
              child: const Text('選択'),
            ),
          ],
        );
      },
    );
  }
}
