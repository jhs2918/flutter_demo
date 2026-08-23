const express = require('express');
const cors = require('cors');
const Anthropic = require('@anthropic-ai/sdk');

const MODEL = 'claude-haiku-4-5';
const MAX_SELECTED_ITEMS = 10;

// [19] 출력 형식 개편: status/action을 화면에 따로 보여주던 걸 그만두고,
// 상태→조치→반응이 한 문장으로 자연스럽게 이어지는 record 하나만 반환한다.
// 지침 구조(공통지침 + 번호별 지침 조각)는 그대로 유지한다.
const COMMON_GUIDELINE = `당신은 방문요양 상태변화기록지를 작성하는 요양보호사를 돕는 보조 도구입니다.
요양보호사가 선택한 카테고리별 관찰 항목을 바탕으로, 다음 규칙을 반드시 지켜 상태(관찰) →
조치(안내·지원·확인) → 반응 순서로 자연스럽게 이어지는 하나의 문장(record)을 작성하세요.
[상태]/[조치]처럼 문장을 나누거나 라벨을 붙이지 말고, 처음부터 끝까지 하나로 읽히는
문장으로 쓰세요.

절대 규칙: 입력된 관찰 항목에 없는 증상·부위·수치·행동·감정 변화는 "단 하나도" 지어내지
마세요. 입력이 항목 1개뿐이면 문장도 그 항목 1개만으로 짧게 쓰세요. 예를 들어 입력이
"건조함" 하나뿐인데 "발적", "인지 변화", "정서 변화", "체온 측정" 같은 입력에 없는 내용을
문장에 넣는 것은 절대 금지입니다. 있어 보이게 문장을 꾸미거나 완결된 서사로 만들려고
내용을 추가하지 마세요 - 부족하면 부족한 대로 짧게 쓰는 것이 항상 정답입니다.

1. 문장 구조: 상태(관찰) → 조치(안내·지원·확인) → 반응 순서로 이어지는 하나의 문장으로
   작성할 것. 상태와 조치 사이는 "~하여" 또는 "~되어"로 연결할 것.
2. 문장은 1~2문장으로 간결하게 작성할 것 - 어떤 경우에도 2문장을 넘지 말 것. 단순 나열은
   절대 금지이며, 선택 항목을 하나의 상황으로 통합하여 서술할 것(단, 항목이 1개뿐이면
   통합할 것도 없으니 그 항목만 그대로 서술할 것).
3. 다음 표현은 절대 쓰지 말 것 - 구어체·감탄사·과장어: "그래서", "그런데", "너무", "매우",
   "다행히" 등. 주관적 평가어: "좋았음", "잘하심", "차분한", "안정적인", "편안한" 등. 문장을
   ~요체(구어체 존댓말)로 끝맺지 말 것. 단, 입력의 조치(action)·조치상황(care_level)·항목
   (items)에 사용자가 직접 선택한 표현 자체("차분히 안내" 등)에 이런 단어가 포함되어 있으면
   그 조치를 서술할 때는 그대로 옮겨 써도 됨 - 이 예외는 사용자가 실제로 선택한 표현에만
   해당하며, 모델이 상태나 반응을 스스로 묘사할 때 새로 이런 단어를 지어내는 것은 여전히
   금지.
4. 관찰된 객관적 사실만 기록할 것 - 감정적·주관적 판단이나 평가를 문장에 넣지 말 것. 예)
   "기분이 안 좋아 보임" 대신 "대답이 평소보다 짧음"으로 서술.
5. 의학적 판단을 내리지 말 것 - 예) "치매 악화" 대신 "반복 질문 횟수 증가"로 서술.
6. 수치·횟수는 입력에 실제로 포함된 경우에만 서술할 것 - 입력에 없는 수치를 지어내지 말 것.
7. 과거형 문체(~함 / ~하심 / ~하였음)로 통일할 것.
8. 문장 연결어 규칙: 같은 연결어를 연속으로 반복 쓰지 말 것 - 예) "~하며 ~하며 ~하며",
   "~하고 ~하고 ~하고" 금지. "~하고", "~하며", "~한 후", "~하였으며" 등을 번갈아 가며
   사용할 것 - 예) "~하고 ~하며 ~하고", "~한 후 ~하고 ~하였으며"는 허용.
9. 같은 단어 조합이 다시 들어오더라도 매번 자연스럽게 다른 문장을 생성할 것(단, 위 절대
   규칙을 어기면서까지 변주를 주지는 말 것).
10. 같은 주어가 반복되지 않도록 "어르신께서는" / "대상자" 등으로 교체하며 변주를 줄 것.
11. "특이사항 없음", "이상 없음", "이후 특이사항 없이 서비스를 마침", "지속적으로 관찰하며
    서비스를 제공함" 같은 상투적이고 내용 없는 마무리 문구는 절대 쓰지 말 것(단, 아래 조치
    작성 규칙에서 사용자가 그 표현을 직접 선택한 경우는 예외). 실제로 관찰되거나 수행된
    내용으로만 문장을 끝맺을 것.
12. 입력된 카테고리 키값을 참고하여 문장 흐름에 맥락을 반영할 것.
13. 어르신의 이름을 문장에 직접 표기하지 말 것 - 이름 대신 항상 "어르신" 또는 "대상자"로 표현할 것.

올바른 예시:
"어르신께서 시간 혼동을 보이며 같은 질문을 반복하는 모습이 관찰되어, 현재 시간과 요일을
알려드리고 낮은 목소리로 대답을 반복 제공하였으며 이후 질문 횟수가 줄어드심"

잘못된 예시(절대 이렇게 쓰지 말 것):
"차분한 목소리로 안내하여 안정적인 태도를 보이심" (주관적 평가어)
"너무 걱정되셔서 다행히 좋아지셨어요" (감탄사·과장어·구어체)
"안내하며 확인하며 기록하며 마무리하심" (같은 연결어 "~하며" 연속 반복)

반드시 아래 JSON 객체 하나만 반환하세요. 다른 설명·인사말·목록 형식·마크다운·코드블록은
절대 포함하지 마세요.
{"record": "완성된 문장"}`;

const GUIDELINES = {
  // 조치 서술 규칙. 선택된 조치가 있으면 그대로 반영하고, 없으면 상태에
  // 맞는 상식적인 조치를 자유롭게 새로 쓰되 "보호자에게 알림"/"관리자
  // 보고"/"특이사항 없음" 같은 상투적 표현은 직접 선택했을 때만 허용한다.
  1: `조치 서술 규칙(중요, 순서대로 확인):
a) 입력에 조치(action)·조치상황(care_level) 항목이 있으면 - 그 내용을 바탕으로 실제
   수행한 것처럼 서술할 것.
b) 조치·조치상황 항목이 전혀 없으면 - 관찰한 상태를 보고, 요양보호사가 그 어르신을 위해
   상식적으로 해줄 수 있는 구체적인 조치를 자연스럽게 새로 작성할 것. 그 상태와 실제로
   관련 있는 조치여야 하며 아무거나 지어내면 안 됨. 예) 기침·가래 → "따뜻한 물을 제공하고
   환기를 실시함", 치아 통증 → "반찬을 잘게 다져 제공함", 실내에만 계심 → "실버체조
   스트레칭을 도와드림".
c) "보호자에게 알림", "관리자 보고", "특이사항 없음"(또는 같은 뜻의 표현)은 사용자가
   조치(action) 항목에서 그 표현을 직접 선택했을 때만 쓸 수 있음 - b)처럼 상태만 보고
   스스로 조치를 지어낼 때는 이 표현들을 절대 포함하지 말 것.
d) 관련 조치를 떠올릴 근거가 전혀 없을 만큼 상태가 애매하면 조치·반응 없이 상태만 짧게
   서술해도 되지만, 이런 경우는 드뭅니다 - 상태가 있으면 보통 b)를 따르세요.

반응 서술 규칙(조치를 서술한 모든 경우에 적용 - a)~b) 중 어느 경우로 조치를 작성했든
문장 끝에 반드시 적용):
- 조치 내용 뒤에, 그 조치를 취한 이후의 결과·반응을 문장 끝에 반드시 덧붙일 것. 결과는
  앞서 서술한 상태와 실제로 관련 있는 내용이어야 함. 예) 기침·가래 상태 → "이후 기침이
  다소 줄어든 모습이 관찰됨", 식욕 없음 상태 → "이후 식사를 잘 하심", 통증 호소 상태 →
  "이후 조금 편안해지신 모습이 관찰됨".
- "완전히 호전됨", "즉시 좋아지심", "완쾌되심" 같은 완전한 회복·즉각적 완치를 뜻하는 표현은
  절대 쓰지 말 것. "다소", "조금", "잠시 후" 같은 현실적인 정도 표현만 사용하고, 과장 없이
  실제로 관찰될 법한 수준으로만 서술할 것.

예시 1(조치 항목을 선택했을 때 - 그 내용을 그대로 반영 + 결과를 끝에 덧붙임):
입력: "- 피부상태:\\n  상태(status): 건조함\\n  조치(action): 보습제 도포"
출력: {"record": "어르신의 피부 상태를 확인한 결과 건조함이 관찰되어 보습제를 도포하였으며, 이후 피부가 다소 편안해진 모습이 관찰됨"}

예시 2(조치를 선택하지 않았을 때 - 상태에 맞는 상식적인 조치를 새로 작성 + 결과를 끝에 덧붙임):
입력: "- 신체상태:\\n  상태(status): 기침, 가래"
출력: {"record": "어르신께서 기침과 가래 증상을 보이셔서 따뜻한 물을 제공하고 환기를 실시하였으며, 이후 기침이 다소 줄어든 모습이 관찰됨"}`,
};

// record_type -> 참조할 지침 번호 목록. 아직 전용 지침이 없는(또는 목록에
// 없는) 기록유형은 DEFAULT_GUIDELINE_IDS를 쓴다.
const RECORD_TYPE_GUIDELINE_IDS = {
  상태변화일지: [1],
};
const DEFAULT_GUIDELINE_IDS = [1];

// 공통지침 + 기록유형이 참조하는 번호별 지침을 합쳐 최종 system prompt를
// 만든다. 여러 카테고리가 같은 번호를 참조해도 중복 삽입되지 않도록
// Set으로 번호를 한 번씩만 포함한다.
function buildSystemPrompt(recordType) {
  const ids = RECORD_TYPE_GUIDELINE_IDS[recordType] || DEFAULT_GUIDELINE_IDS;
  const parts = [COMMON_GUIDELINE];
  for (const id of new Set(ids)) {
    if (GUIDELINES[id]) parts.push(GUIDELINES[id]);
  }
  return parts.join('\n\n');
}

// [19] /generate 응답에서 {"record": "..."} 객체를 뽑아낸다. 비어 있으면
// (모델이 형식을 안 지킨 경우) null을 돌려줘서 호출부가 502로 처리하게 한다.
function parseRecordObject(text) {
  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch {
    const match = text.match(/\{[\s\S]*\}/);
    if (!match) return null;
    try {
      parsed = JSON.parse(match[0]);
    } catch {
      return null;
    }
  }
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) return null;
  const record = typeof parsed.record === 'string' ? parsed.record.trim() : '';
  if (!record) return null;
  return { record };
}

const anthropic = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY,
});

const app = express();
app.use(cors());
app.use(express.json({ limit: '1mb' }));

// [14] 카테고리별 항목이 status/action/care_level/body_part/items로 이미
// 나뉘어 들어온다(앱 쪽 card_select_screen._buildPayload 참고) - 역할을
// 라벨로 명시해서 Claude에게 전달한다. 예전에는 한 카테고리의 모든 선택
// 항목이 구분 없이 한 줄로 뭉쳐서 넘어가 AI가 어떤 게 상태고 어떤 게
// 조치인지 라벨 의미만으로 추측해야 했다 - 그게 환각(입력에 없는 내용을
// 지어내는 문제)의 원인 중 하나였다.
function buildUserMessage(payload) {
  const lines = [];
  if (payload.facility_type) {
    lines.push(`시설유형(facility_type): ${payload.facility_type}`);
  }
  if (payload.record_type) {
    lines.push(`기록유형(record_type): ${payload.record_type}`);
  }

  const selections = payload.selections || {};
  lines.push('', '선택된 카테고리별 관찰 항목:');
  for (const [category, data] of Object.entries(selections)) {
    if (!data || typeof data !== 'object') continue;
    lines.push(`- ${category}:`);
    if (Array.isArray(data.status) && data.status.length) {
      lines.push(`  상태(status): ${data.status.join(', ')}`);
    }
    if (Array.isArray(data.action) && data.action.length) {
      lines.push(`  조치(action): ${data.action.join(', ')}`);
    }
    if (Array.isArray(data.care_level) && data.care_level.length) {
      lines.push(`  조치상황(care_level): ${data.care_level.join(', ')}`);
    }
    if (data.body_part && typeof data.body_part === 'object') {
      const bp = data.body_part;
      const parts = [];
      if (bp.direction?.length) parts.push(`방향 ${bp.direction.join('/')}`);
      if (bp.part?.length) parts.push(`부위 ${bp.part.join('/')}`);
      if (bp.symptom?.length) parts.push(`증상 ${bp.symptom.join('/')}`);
      if (parts.length) lines.push(`  신체부위(body_part): ${parts.join(', ')}`);
    }
    if (Array.isArray(data.items) && data.items.length) {
      lines.push(`  항목: ${data.items.join(', ')}`);
    }
  }

  if (Array.isArray(payload['입력값']) && payload['입력값'].length) {
    lines.push('', `입력값: ${payload['입력값'].join(', ')}`);
  }
  if (payload.extra_note) {
    lines.push('', `수급자·보호자 의견(extra_note): ${payload.extra_note}`);
  }
  if (payload['추가요청']) {
    lines.push('', `추가 요청: ${payload['추가요청']}`);
  }

  lines.push('', '위 항목을 반영하여 규칙에 맞는 방문요양 상태변화기록 문장을 작성하세요.');
  return lines.join('\n');
}

function countSelectedItems(selections) {
  let total = 0;
  for (const data of Object.values(selections)) {
    if (!data || typeof data !== 'object') continue;
    total += (data.status?.length || 0) + (data.action?.length || 0) +
      (data.care_level?.length || 0) + (data.items?.length || 0);
    if (data.body_part && typeof data.body_part === 'object') {
      const bp = data.body_part;
      total += (bp.direction?.length || 0) + (bp.part?.length || 0) +
        (bp.symptom?.length || 0);
    }
  }
  return total;
}

app.post('/generate', async (req, res) => {
  const payload = req.body ?? {};
  const { selections } = payload;

  if (!selections || typeof selections !== 'object' || Array.isArray(selections)) {
    return res.status(400).json({ error: 'selections 필드가 필요합니다.' });
  }

  const totalItems = countSelectedItems(selections);
  if (totalItems === 0) {
    return res.status(400).json({ error: '선택된 항목이 없습니다.' });
  }
  if (totalItems > MAX_SELECTED_ITEMS) {
    return res
      .status(400)
      .json({ error: `선택 항목은 최대 ${MAX_SELECTED_ITEMS}개까지 가능합니다.` });
  }

  if (!process.env.ANTHROPIC_API_KEY) {
    console.error('ANTHROPIC_API_KEY 환경변수가 설정되어 있지 않습니다.');
    return res.status(500).json({ error: '서버 설정 오류입니다.' });
  }

  try {
    // [15][모델 변경] claude-haiku-4-5로 전환. claude-sonnet-5는 thinking
    // 파라미터를 안 넘겨도 기본적으로 adaptive thinking이 켜져 있어 짧은
    // 답변에도 사고 토큰을 많이 써버리는 문제가 있었지만(그래서 thinking을
    // 명시적으로 껐었다), Haiku 4.5 같은 구형 티어는 thinking이 기본 꺼짐
    // 상태이고 `{type: "disabled"}` 형태 자체를 지원하지 않으므로 파라미터를
    // 아예 넘기지 않는다.
    const message = await anthropic.messages.create({
      model: MODEL,
      max_tokens: 1536,
      system: buildSystemPrompt(payload.record_type),
      messages: [{ role: 'user', content: buildUserMessage(payload) }],
    });

    const text = message.content
      .filter((block) => block.type === 'text')
      .map((block) => block.text)
      .join('\n')
      .trim();

    const parsed = parseRecordObject(text);
    if (!parsed) {
      console.error(
        'AI 응답 형식 오류(record JSON 아님):',
        JSON.stringify({
          text,
          stop_reason: message.stop_reason,
          usage: message.usage,
          blockTypes: message.content.map((b) => b.type),
        }),
      );
      return res
        .status(502)
        .json({ error: 'AI 응답 형식 오류입니다. 잠시 후 다시 시도해주세요.' });
    }

    res.json(parsed);
  } catch (error) {
    console.error('Claude API 호출 실패:', error);
    res.status(502).json({ error: 'AI 기록 생성에 실패했습니다. 잠시 후 다시 시도해주세요.' });
  }
});

app.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
});

const PORT = process.env.PORT || 3000;
// Railway 등 컨테이너 환경에서는 호스트를 명시하지 않으면 외부 프록시가
// 접속하지 못하는 경우가 있어 0.0.0.0에 명시적으로 바인딩한다.
app.listen(PORT, '0.0.0.0', () => {
  console.log(`서버가 ${PORT}번 포트에서 실행 중입니다.`);
});
