const express = require('express');
const cors = require('cors');
const Anthropic = require('@anthropic-ai/sdk');

const MODEL = 'claude-haiku-4-5';
const MAX_SELECTED_ITEMS = 10;

// [06][11] 선택된 카테고리별 항목을 방문요양 상태변화기록 문장으로 바꾸는
// 규칙. 앱 프론트에서 넘어온 카테고리 키값과 항목만으로 판단하며, 요양보호사가
// 직접 검토·수정하는 초안을 생성하는 것이 목적이다. 화면에 [상태]/[조치] 칸이
// 따로 있으므로, 상태 관찰과 그에 대한 조치를 한 문단으로 섞지 않고 두 필드로
// 나눠 반환한다.
const SYSTEM_PROMPT = `당신은 방문요양 상태변화기록지를 작성하는 요양보호사를 돕는 보조 도구입니다.
요양보호사가 선택한 카테고리별 관찰 항목을 바탕으로, 다음 규칙을 반드시 지켜 "status"(상태)와
"action"(조치) 두 문장을 각각 작성하세요. 화면에 [상태] 칸과 [조치] 칸이 따로 있으므로 절대
한쪽에 섞어 쓰지 마세요.

절대 규칙: 입력된 관찰 항목에 없는 증상·부위·수치·행동·감정 변화는 status에도 action에도
"단 하나도" 지어내지 마세요. 입력이 항목 1개뿐이면 문장도 그 항목 1개만으로 짧게 쓰세요.
예를 들어 입력이 "건조함" 하나뿐인데 "발적", "인지 변화", "정서 변화", "체온 측정" 같은
입력에 없는 내용을 문장에 넣는 것은 절대 금지입니다. 있어 보이게 문장을 꾸미거나 완결된
서사로 만들려고 내용을 추가하지 마세요 - 부족하면 부족한 대로 짧게 쓰는 것이 항상 정답입니다.

1. 같은 단어 조합이 다시 들어오더라도 매번 자연스럽게 다른 문장을 생성할 것(단, 위 절대
   규칙을 어기면서까지 변주를 주지는 말 것).
2. 감정 표현을 쓰지 말 것 - 예) "기분이 안 좋아 보임" 대신 "대답이 평소보다 짧음"으로 서술.
3. 의학적 판단을 내리지 말 것 - 예) "치매 악화" 대신 "반복 질문 횟수 증가"로 서술.
4. 수치·횟수는 입력에 실제로 포함된 경우에만 서술할 것 - 입력에 없는 수치를 지어내지 말 것.
5. 과거형 문체(~함 / ~하심 / ~하였음)로 통일할 것.
6. "status" 필드: 선택된 관찰 항목만으로 상태를 서술할 것. 조치·대응 내용은 절대 넣지 말 것.
7. "action" 필드: 그 상태에 대해 실제로 취한 조치와 그 결과만 서술할 것. 상태를 다시 나열하지
   말고 조치 중심으로 쓸 것. 입력에 조치 관련 항목이 전혀 없으면, 새로운 상태나 증상을 지어내지
   말고 "경과를 관찰함" 정도의 최소한의 조치 문장만 쓸 것.
8. "이에 따라 / 이후 / 확인 결과" 등 자연스러운 연결어를 각 필드 안에서 사용할 것.
9. 선택 항목 수에 따라 문장 길이를 조절할 것 - 각 필드 1~2문장으로 간결하게 쓰고, 어떤 경우에도
   필드당 최대 2문장을 넘지 말 것. 단순 나열은 절대 금지.
10. 선택 항목을 단순 나열하지 말고 하나의 상황으로 통합하여 서술할 것(단, 항목이 1개뿐이면
    통합할 것도 없으니 그 항목만 그대로 서술할 것).
11. 같은 주어가 반복되지 않도록 "어르신께서는" / "대상자" 등으로 교체하며 변주를 줄 것.
12. 입력에 낙상·출혈·통증·혈압이상·인지변화 항목이 실제로 포함된 경우에만 "action"에 보호자
    알림 문구를 반드시 포함할 것. 입력에 없으면 알림 문구도, 그 상태 자체도 지어내지 말 것.
13. "특이사항 없음", "이상 없음", "이후 특이사항 없이 서비스를 마침", "지속적으로 관찰하며
    서비스를 제공함" 같은 상투적이고 내용 없는 마무리 문구는 절대 쓰지 말 것. 실제로 관찰되거나
    수행된 내용으로만 문장을 끝맺을 것.
14. 입력된 카테고리 키값을 참고하여 문장 흐름에 맥락을 반영할 것.
15. 어르신의 이름을 문장에 직접 표기하지 말 것 - 이름 대신 항상 "어르신" 또는 "대상자"로 표현할 것.

예시(입력 항목이 1개뿐일 때 - 절대 다른 증상을 추가하지 않는다):
입력: "- 피부상태: 건조함"
출력: {"status": "어르신의 피부 상태를 확인한 결과 건조함이 관찰됨", "action": "경과를 관찰함"}

반드시 아래 JSON 객체 하나만 반환하세요. 다른 설명·인사말·목록 형식·마크다운·코드블록은
절대 포함하지 마세요.
{"status": "상태 문장", "action": "조치 문장"}`;

// [10] 조치 항목 없이 결과 확인을 누르면, 선택된 상태 키워드를 보고 적절한
// 조치 2~3개를 추천해 팝업으로 보여준다. 랜덤이 아니라 상태와 실제로
// 인과관계가 있는 조치만 추천하도록 규칙을 둔다.
const ACTION_SUGGEST_SYSTEM_PROMPT = `당신은 노인장기요양 기록에서 관찰된 상태에 대해 적절한 조치를 추천하는 보조 도구입니다.
요양보호사·사회복지사가 선택한 상태 관찰 항목을 보고, 그 상황에 실제로 필요한 조치를 2~3개 추천하세요.

규칙:
1. 입력된 상태 항목과 인과관계가 있는 현실적인 조치만 추천할 것. 막연하거나 상투적인 조치는 금지.
2. 각 조치는 2~10자 내외의 짧은 버튼 문구로 작성할 것 (예: "보호자 알림", "경과 관찰", "체위변경 실시").
3. 낙상·출혈·통증 급증·인지 급변 등 위중한 상태가 포함되면 "보호자 알림" 또는 "관리자 보고"류 조치를 반드시 하나 포함할 것.
4. 서로 겹치지 않는 다양한 대응 조치를 추천할 것.
5. 출력은 반드시 JSON 배열만 반환할 것. 다른 설명, 인사말, 마크다운, 코드블록은 절대 포함하지 말 것.

출력 예시: ["보호자 알림", "경과 관찰", "체위변경 실시"]`;

function buildActionSuggestUserMessage({ statusKeywords, facilityType, recordType }) {
  return [
    facilityType ? `시설유형: ${facilityType}` : null,
    recordType ? `기록유형: ${recordType}` : null,
    `선택된 상태 항목: ${statusKeywords.join(', ')}`,
    '',
    '위 상태에 적절한 조치 2~3개를 JSON 배열로만 추천하세요.',
  ]
    .filter((line) => line !== null)
    .join('\n');
}

// [11] /generate 응답에서 {"status": ..., "action": ...} 객체를 뽑아낸다.
// 둘 다 비어 있으면(모델이 형식을 안 지킨 경우) null을 돌려줘서 호출부가
// 502로 처리하게 한다.
function parseStatusActionObject(text) {
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
  const status = typeof parsed.status === 'string' ? parsed.status.trim() : '';
  const action = typeof parsed.action === 'string' ? parsed.action.trim() : '';
  if (!status && !action) return null;
  return { status, action };
}

function parseSuggestionArray(text) {
  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch {
    const match = text.match(/\[[\s\S]*\]/);
    if (!match) return [];
    try {
      parsed = JSON.parse(match[0]);
    } catch {
      return [];
    }
  }
  if (!Array.isArray(parsed)) return [];
  return parsed
    .filter((item) => typeof item === 'string' && item.trim())
    .map((item) => item.trim())
    .slice(0, 3);
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
  if (Array.isArray(payload['추천조치']) && payload['추천조치'].length) {
    lines.push('', `AI 추천 후 사용자가 선택한 조치: ${payload['추천조치'].join(', ')}`);
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
      system: SYSTEM_PROMPT,
      messages: [{ role: 'user', content: buildUserMessage(payload) }],
    });

    const text = message.content
      .filter((block) => block.type === 'text')
      .map((block) => block.text)
      .join('\n')
      .trim();

    const parsed = parseStatusActionObject(text);
    if (!parsed) {
      console.error(
        'AI 응답 형식 오류(status/action JSON 아님):',
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

app.post('/suggest-actions', async (req, res) => {
  const { statusKeywords, facilityType, recordType } = req.body ?? {};

  if (!Array.isArray(statusKeywords) || statusKeywords.length === 0) {
    return res.status(400).json({ error: 'statusKeywords 필드가 필요합니다.' });
  }

  if (!process.env.ANTHROPIC_API_KEY) {
    console.error('ANTHROPIC_API_KEY 환경변수가 설정되어 있지 않습니다.');
    return res.status(500).json({ error: '서버 설정 오류입니다.' });
  }

  try {
    // [15][모델 변경] output_config.effort는 claude-haiku-4-5에서 지원하지
    // 않아(400 오류) 뺐다 - Sonnet 5 전용이었던 튜닝값이라 모델을 바꾸며
    // 함께 제거한다.
    const message = await anthropic.messages.create({
      model: MODEL,
      max_tokens: 600,
      system: ACTION_SUGGEST_SYSTEM_PROMPT,
      messages: [
        {
          role: 'user',
          content: buildActionSuggestUserMessage({
            statusKeywords,
            facilityType,
            recordType,
          }),
        },
      ],
    });

    const text = message.content
      .filter((block) => block.type === 'text')
      .map((block) => block.text)
      .join('\n')
      .trim();

    res.json({ suggestions: parseSuggestionArray(text) });
  } catch (error) {
    console.error('조치 추천 실패:', error);
    res.status(502).json({ error: '조치 추천에 실패했습니다. 잠시 후 다시 시도해주세요.' });
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
