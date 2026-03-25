데이터 표시 카드(top badge) Y

Positioned(
  left: (x - 72).clamp(leftInset, math.max(leftInset, leftInset + plotWidth - 144)),
  top: 36, // 16px date stripe + 20px padding
  child: Builder(builder: (context) {
    final int i = touchedIndex!.clamp(0, widget.points.length - 1);
	

이벤트 아이콘 Y
if (x >= leftInset && x <= leftInset + plotWidth) {
  children.add(Positioned(
    // align icons on a bottom row inside plot, not on Y-axis
    top: 28,
    left: (x - 16).clamp(leftInset, leftInset + plotWidth - 32),
    child: _EventBadge(type: ordered[i].type, size: 32),