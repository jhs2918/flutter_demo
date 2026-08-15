// [06] 전체 카테고리를 통틀어 한 번에 선택할 수 있는 버튼 최대 개수.
const int kMaxSelectedButtons = 10;

// [06] "조치" 성격의 카테고리(⑰ 위생·청결 서비스, ⑱ 일상생활 지원 서비스,
// ⑲ 조치·대응 내용) id 목록. AI 기록 생성 시 이 중 하나도 선택되지 않았으면
// 안내 팝업을 띄우는 데 사용한다.
const Set<String> kActionCategoryIds = <String>{
  'category_17',
  'category_18',
  'category_19',
};

/// [02] 기록작성화면의 카테고리 하나.
class RecordCategory {
  const RecordCategory({
    required this.id,
    required this.name,
    this.subCategories = const <RecordSubCategory>[],
  });

  // 카테고리 고유 id. 저장소 키로도 사용한다.
  final String id;
  // 탭에 표시할 카테고리 이름.
  final String name;
  // [02-02] 카테고리 안의 세부 카테고리 목록.
  final List<RecordSubCategory> subCategories;
}

/// [02-02] 카테고리 안의 세부 카테고리 하나. 기본 제공 버튼을 묶는 단위.
class RecordSubCategory {
  const RecordSubCategory({
    required this.id,
    required this.name,
    this.presetButtons = const <String>[],
  });

  // 세부 카테고리 고유 id. 커스텀 버튼 저장소 키로도 사용한다.
  final String id;
  // 세부 카테고리 이름.
  final String name;
  // 세부 카테고리 기본 제공 버튼. 삭제할 수 없다.
  final List<String> presetButtons;
}

/// [02-01] 카테고리 탭 구성. 총 19개.
/// [02-06] 위생·청결 서비스, 일상생활 지원 서비스를 17·18번 자리에 추가하며
/// 기존 17번(조치·대응 내용)을 19번으로 옮겼다.
/// [02-02] 세부 카테고리는 다음 지침에서 실제 데이터로 채워질 예정이라
/// 지금은 빈 세부 카테고리 목록을 쓴다.
const List<String> _recordCategoryNames = <String>[
  '신체기능(이동·보행)',
  '통증',
  '식사·영양',
  '배설',
  '수면',
  '피부',
  '인지기능',
  '정서·심리',
  '복약',
  '낙상·사고',
  '응급·전조증상',
  '질병·건강',
  '보호자소통',
  '특이사항없음',
  '처치·대응결과',
  '욕구·의향',
  '위생·청결 서비스',
  '일상생활 지원 서비스',
  '조치·대응 내용',
];

// [02-02] 카테고리별 기본 제공 버튼.
const Map<String, List<String>> _recordCategoryPresetButtons =
    <String, List<String>>{
  'category_01': <String>[
    '자립보행', '부분도움', '완전도움', '부축', '워커사용', '휠체어', '낙상위험', '하지근력저하', '비틀거림', '침상생활',
  ],
  'category_02': <String>[
    '통증없음', '두통호소', '무릎통증', '허리통증', '어깨통증', '열감있음', '부종있음', '통증2/5', '통증3/5', '통증4/5',
  ],
  'category_03': <String>[
    '전량섭취', '70%섭취', '50%섭취', '30%섭취', '식욕없음', '식사거부', '사레걸림', '연하곤란', '수분부족', '경관영양',
  ],
  'category_04': <String>[
    '배변정상', '변비의심', '설사', '요실금', '배뇨통증', '혈변의심', '복부팽만', '기저귀착용', '이동변기사용', '분변매복의심',
  ],
  'category_05': <String>[
    '수면양호', '불면호소', '주간졸음심함', '야간자주깸', '밤낮바뀜', '수면환경정리함',
  ],
  'category_06': <String>[
    '이상없음', '발적관찰', '욕창의심', '상처발견', '멍발견', '피부건조', '부종', '보습제도포함',
  ],
  'category_07': <String>[
    '인지양호', '반복질문', '지남력저하', '배회', '망상의심', '환각호소', '공격적언행', '가족미인식',
  ],
  'category_08': <String>[
    '정서안정', '우울감호소', '말수감소', '불안증상', '감정기복심함', '외로워하심', '말벗제공함',
  ],
  'category_09': <String>[
    '복약완료', '복약거부', '복약후불편호소', '약변경됨', '부작용의심', '복약독려함',
  ],
  'category_10': <String>[
    '낙상없음', '낙상발생', '미끄러짐', '낙상위험있음', '골절의심', '외상없음', '119신고함',
  ],
  'category_11': <String>[
    '이상없음', '얼굴창백', '호흡가빠짐', '식은땀', '의식저하', '흉통호소', '고열', '청색증의심', '119신고함',
  ],
  'category_12': <String>[
    '고혈압', '당뇨', '치매', '파킨슨병', '뇌경색', '심부전', '골다공증', '요실금', '우울증', '증상안정적', '증상악화', '병원다녀오심',
  ],
  'category_13': <String>[
    '전화연락함', '문자전달함', '보호자부재', '연락안됨', '보호자확인완료', '센터장보고완료',
  ],
  'category_14': <String>[
    '전반적이상없음', '평소와동일', '활력징후이상없음', '서비스원활완료', '낙상사고없음',
  ],
  'category_15': <String>[
    '증상완화됨', '증상지속됨', '증상악화됨', '안정후호전됨', '지속관찰필요', '다음방문재확인',
  ],
  'category_16': <String>[
    '의욕부진', '운동하고싶다하심', '외출원하심', '가족보고싶다하심', '서비스거부', '특별욕구없음',
  ],
};

// [02-05][02-07] 세부 카테고리가 이름 붙은 여러 그룹으로 나뉘어 있는
// 카테고리들. 이름 없는 세부 카테고리 1개로 묶는 다른 카테고리와 달리
// 카테고리 id별로 이름 붙은 세부 카테고리 여러 개를 순서대로 갖는다.
const Map<String, Map<String, List<String>>> _recordCategorySubCategoryGroups =
    <String, Map<String, List<String>>>{
  'category_17': <String, List<String>>{
    '구강 위생': <String>[
      '구강 청결 제공함', '양치 보조함', '틀니 세척 보조함',
      '틀니 착용 보조함', '구강 건조 확인함', '구강 내 잔여물 확인함',
    ],
    '세면·세발': <String>[
      '세면 보조함', '세발(머리감기) 보조함',
      '머리 빗질 및 정돈함', '물수건으로 얼굴 닦아드림',
    ],
    '신체 청결': <String>[
      '몸 닦기 제공함(물수건)', '등 닦기 제공함',
      '발 닦기 및 발 상태 확인함', '손발톱 상태 확인함',
      '손발톱 정리함', '피부 보습제 도포함',
    ],
    '의복·침구': <String>[
      '의복 교체 보조함', '상의 교체 보조함', '하의 교체 보조함',
      '침구 정리함', '침구 교체함',
    ],
  },
  'category_18': <String, List<String>>{
    '가사 지원': <String>[
      '청소 보조함(거실/주방/화장실)', '세탁 보조함',
      '설거지 보조함', '쓰레기 정리함', '환기 시킴',
    ],
    '식사 준비': <String>[
      '식사 준비 보조함', '반찬 준비 보조함',
      '물·음료 준비함', '약 준비 보조함',
    ],
    '외출·동행': <String>[
      '장보기 동행함', '병원 동행함', '약국 동행함',
      '약 구매 동행함', '산책 동행함', '외출 보조함',
    ],
    '일상 지원': <String>[
      '전화 통화 보조함', '우편물 확인함',
      '냉장고 식품 상태 확인함', '안전 환경 점검함',
    ],
  },
  'category_19': <String, List<String>>{
    '즉각 신고·연락': <String>[
      '119 신고함', '보호자에게 즉시 전화 연락함', '보호자에게 문자 전달함', '센터장에게 즉시 보고함',
      '담당 의료진에게 연락함', '보호자 연락 안 됨(부재)',
    ],
    '신체 처치': <String>[
      '냉찜질 적용함', '온찜질 적용함', '보습제 도포함', '체위변경 시행함(2시간마다)',
      '복부 마사지 시행함(시계 방향 10분)', '상처 부위 소독함', '사진 촬영하여 보고함', '움직이지 않도록 안정시킴',
    ],
    '활력징후 측정': <String>[
      '혈압 측정함', '수축기/이완기 혈압 기록함', '체온 측정함', '맥박 확인함', '산소포화도 확인함',
      '혈당 측정함', '30분 후 재측정함', '측정값 보호자에게 공유함', '측정값 이상으로 센터장에게 보고함',
    ],
    '식사·수분 관련 조치': <String>[
      '수분 섭취 독려함(미온수 200ml)', '식사 속도 조절 안내함', '부드러운 음식으로 변경함',
      '죽식으로 변경하여 제공함', '소화 상태 관찰함', '식사 보조함',
    ],
    '안전·이동 조치': <String>[
      '낙상 주의 안내함', '안전하게 이동 보조함', '미끄럼 방지 안내함', '안전바 잡도록 유도함',
      '휴식 권유함', '침대 안전 확인함',
    ],
    '인지·정서 대응': <String>[
      '말로 안정시킴', '현실 인식 도움 제공함', '좋아하는 음악 틀어드림', '옛 추억 대화 나눔',
      '달력·시계 함께 확인함', '인지 자극 활동 진행함(20분)', '주의 환기함', '공감하며 경청함',
    ],
    '위생 관련 조치': <String>[
      '구강 청결 제공함', '세면 보조함', '몸 닦기 제공함', '기저귀 즉시 교체함',
      '음부 청결 제공함', '의복 교체 보조함', '틀니 세척 보조함',
    ],
    '복약 관련 조치': <String>[
      '복약 독려함', '10분 후 재권유하여 복용 완료', '식후 복약 안내함',
      '보호자에게 복약 거부 알림', '의사·약사 확인 권유함',
    ],
    '병원·외부 연계': <String>[
      '병원 진료 권유함', '병원 동행함', '외래 진료 예약 안내함',
      '보호자가 병원 예약하기로 함', '병원 이송함(119 동행)',
    ],
    '관찰·모니터링': <String>[
      '지속 관찰함', '다음 방문 시 재확인 예정', '30분 후 상태 재확인함',
      '이후 특이사항 없이 서비스 마침', '보호자 조치 예정으로 인계함',
    ],
  },
};

final List<RecordCategory> recordCategories = List<RecordCategory>.generate(
  _recordCategoryNames.length,
  (int index) {
    final String id = 'category_${(index + 1).toString().padLeft(2, '0')}';

    final Map<String, List<String>>? subCategoryGroups =
        _recordCategorySubCategoryGroups[id];
    if (subCategoryGroups != null) {
      final List<String> groupNames = subCategoryGroups.keys.toList();
      return RecordCategory(
        id: id,
        name: _recordCategoryNames[index],
        subCategories: List<RecordSubCategory>.generate(
          groupNames.length,
          (int groupIndex) {
            final String groupName = groupNames[groupIndex];
            return RecordSubCategory(
              id: '${id}_sub_${(groupIndex + 1).toString().padLeft(2, '0')}',
              name: groupName,
              presetButtons: subCategoryGroups[groupName]!,
            );
          },
        ),
      );
    }

    final List<String> presetButtons =
        _recordCategoryPresetButtons[id] ?? const <String>[];
    return RecordCategory(
      id: id,
      name: _recordCategoryNames[index],
      // 세부 카테고리가 아직 나뉘지 않아, 버튼이 있는 카테고리는 우선
      // 세부 카테고리 1개에 전부 묶어 둔다. 세분화는 다음 지침에서 진행한다.
      subCategories: presetButtons.isEmpty
          ? const <RecordSubCategory>[]
          : <RecordSubCategory>[
              RecordSubCategory(
                id: '${id}_sub_01',
                name: '',
                presetButtons: presetButtons,
              ),
            ],
    );
  },
);
