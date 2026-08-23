import 'package:flutter/material.dart';

/// [21] 입체(3D) 스타일 낱말카드 버튼. 위/아래 그라데이션 + blurRadius 0인
/// 그림자로 옆면을 표현해 입체감을 낸다(흐리면 옆면이 아니라 그냥 그림자로
/// 보여서 입체감이 사라진다). 누르는 동안에는 옆면이 얇아지며 버튼이 아래로
/// 눌리고, 선택되면 반쯤 눌린 상태로 고정된다.
class GlossyChip extends StatefulWidget {
  const GlossyChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.isCustom = false,
    this.scale = 1.0,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  // 내가 직접 추가한 낱말카드 삭제(길게 누르기)에 쓴다.
  final VoidCallback? onLongPress;
  // 내가 직접 추가한 카드 표시(별 아이콘)에 쓴다.
  final bool isCustom;
  final double scale;

  @override
  State<GlossyChip> createState() => _GlossyChipState();
}

class _GlossyChipState extends State<GlossyChip> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final bool on = widget.selected;
    final Color top = on ? const Color(0xFFFF7DAE) : const Color(0xFFFFFFFF);
    final Color bottom = on
        ? const Color(0xFFE83F7E)
        : const Color(0xFFF7E4EC);
    final Color side = on ? const Color(0xFFC42260) : const Color(0xFFE5C2D2);
    final Color fg = on ? Colors.white : const Color(0xFF7A3B54);
    // 옆면(side) 두께가 곧 "눌린 정도"다 - 누르는 중이면 가장 얇고(1.0),
    // 선택된 상태면 반쯤 눌린 채로 고정되며(2.5), 평소엔 5.0으로 가장
    // 도드라진다. margin top을 그만큼 더 줘서(offset) 버튼이 차지하는
    // 전체 세로 공간은 항상 같게 유지한다 - 눌러도 주변 레이아웃이
    // 흔들리지 않는다.
    final double depth = _down ? 1.0 : (on ? 2.5 : 5.0);
    final double offset = 5.0 - depth;

    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
        margin: EdgeInsets.only(top: offset, bottom: depth),
        // [21][확인사항] 글자 크기를 80%까지 줄여도 터치 영역은 44 아래로
        // 내려가면 안 된다 - 확대(scale>1)될 때만 같이 커지게 한다.
        constraints: BoxConstraints(
          minHeight: (44 * widget.scale).clamp(44.0, double.infinity),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[top, bottom],
          ),
          border: Border.all(color: side, width: 1),
          boxShadow: <BoxShadow>[
            // [핵심] blurRadius는 반드시 0 - 흐리면 옆면이 아니라 평범한
            // 그림자로 보여서 입체감이 사라진다.
            BoxShadow(color: side, offset: Offset(0, depth), blurRadius: 0),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: <Widget>[
              // 상단 흰 하이라이트 - 빛이 반사되는 것처럼 보이게 한다.
              Positioned.fill(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: FractionallySizedBox(
                    heightFactor: 0.55,
                    widthFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Colors.white.withValues(alpha: on ? 0.35 : 0.6),
                            Colors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 16 * widget.scale,
                  vertical: 10 * widget.scale,
                ),
                // [22][버그 수정] Center는 기본적으로 부모가 준 너비(Wrap이
                // 넘겨준, 화면 남은 공간만큼의 bounded maxWidth)를 그대로
                // 채워버린다 - widthFactor: 1을 줘야 자식(Row) 크기만큼만
                // 차지해서 Wrap이 글자 길이대로 여러 개를 한 줄에 배치할 수
                // 있다. Row 안의 Text도 Flexible로 감싸면 같은 이유로 남은
                // 공간을 다시 다 차지해버리므로 감싸지 않는다.
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        widget.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w700,
                          fontSize: 14 * widget.scale,
                        ),
                      ),
                      if (widget.isCustom) ...<Widget>[
                        SizedBox(width: 4 * widget.scale),
                        Icon(Icons.star, size: 12 * widget.scale, color: fg),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
