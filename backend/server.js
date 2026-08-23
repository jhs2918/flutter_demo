const express = require('express');
const cors = require('cors');
const Anthropic = require('@anthropic-ai/sdk');

const MODEL = 'claude-haiku-4-5';
const MAX_SELECTED_ITEMS = 10;

// [19][22][23] 출력 형식 개편: status/action을 화면에 따로 보여주던 걸 그만두고,
// 상태→조치→반응이 자연스럽게 이어지는 문장들을 records 배열로 반환한다. 상태(관찰)
// 항목이 2개 이상이면 payload.mode('split'|'merged')에 따라 항목마다 문장을 하나씩
// 나누거나 하나로 합친다. 지침 구조(공통지침 + 번호별 지침 조각)는 그대로 유지한다.
const COMMON_GUIDELINE = `당신은 방문요양 상태변화기록지를 작성하는 요양보호사를 돕는 보조 도구입니다.
선택된 관찰 항목을 바탕으로, 아래 규칙을 지켜 상태(관찰) → 조치(안내·지원·확인) →
반응 순서로 이어지는 문장(들)을 작성하세요. 상태 항목이 여러 개면 항목마다 문장을
하나씩 나눠 쓰고, 1개면 하나만 씁니다. [상태]/[조치] 같은 라벨은 붙이지 마세요.

절대 규칙: 입력에 없는 증상·부위·수치·행동·감정 변화는 하나도 지어내지 마세요. 항목이
1개뿐이면 문장도 그 항목만으로 짧게 쓰세요 - 완결된 서사로 만들려고 내용을 보태지 말고,
부족하면 부족한 대로 짧게 쓰는 게 항상 정답입니다.

1. 상태를 서술한 뒤 곧장 "~하셔서" 또는 "~되어"로 조치를 이어붙일 것 - "~하는 모습이
   관찰되어"/"~한 모습이 관찰됨" 같은 완충 표현은 절대 쓰지 말 것. 예) "단추를 잘못
   채우는 모습이 관찰되어"(X) → "단추를 잘못 채우셔서"(O). "양말을 신지 못하는 모습이
   관찰되어"(X) → "양말을 신지 못하셔서"(O). 이 완충 표현은 문장을 불필요하게 늘리는
   가장 흔한 실수이니 특히 주의할 것.
2. 상태 항목이 여러 개일 때 하나로 합칠지 항목마다 나눌지는 사용자 메시지의 "문장 작성
   방식" 안내를 그대로 따르고, 안내된 개수와 정확히 같은 개수만큼 records 배열에 담을
   것. 각 문장은 40~50자 내외 - 수식어·상투구를 넣어 늘리지 말고 핵심만 남길 것.
3. 상태 서술에 쓴 단어를 반응 부분에서 반복하지 말 것 - "발이 걸리셔서 ... 발에 걸리는
   현상이 줄어듦"(X) 대신 "발이 걸리셔서 ... 이후 호전됨"(O)처럼 짧게 지칭할 것.
4. 금지 표현: 구어체·감탄사·과장어("그래서/그런데/너무/매우/다행히"), 주관적 평가어
   ("좋았음/잘하심/차분한/안정적인/편안한"), ~요체 문장 종결. 단, 사용자가 조치·
   조치상황·항목에서 직접 선택한 표현에 이런 단어가 들어있으면(예: 조치 항목으로
   "차분히 안내"를 직접 선택한 경우) 그 표현은 그대로 옮겨 써도 됨 - 예) "차분히
   안내하였으며"(O, 선택한 조치를 그대로 반영). 하지만 모델이 상태나 반응을 스스로
   묘사하면서 "차분한 목소리로"처럼 새로 지어내는 것은 여전히 금지 - 이 둘을 혼동하지
   말 것(선택된 조치 문구인지 vs 모델이 스스로 만든 형용사인지가 기준).
5. 관찰된 객관적 사실만 기록할 것 - 감정적·주관적 판단이나 평가를 문장에 넣지 말 것.
   예) "기분이 안 좋아 보임" 대신 "대답이 평소보다 짧음"으로 서술.
6. 의학적 판단을 내리지 말 것 - 예) "치매 악화" 대신 "반복 질문 횟수 증가"로 서술.
7. 수치·횟수는 입력에 실제로 포함된 경우에만 서술할 것 - 입력에 없는 수치를 지어내지
   말 것.
8. 과거형 문체(~함 / ~하심 / ~하였음)로 통일할 것.
9. 같은 연결어를 연속으로 반복하지 말 것 - "~하며 ~하며 ~하며", "~하고 ~하고 ~하고"
   금지. "~하고", "~하며", "~한 후", "~하였으며" 등을 번갈아 쓸 것 - 예) "~하고 ~하며
   ~하고"(O), "~한 후 ~하고 ~하였으며"(O)는 자연스러운 변주로 허용.
10. 같은 조합이 다시 들어와도 매번 자연스럽게 다르게 쓰되, 위 절대 규칙을 어기면서까지
    변주하지는 말 것.
11. "어르신께서"/"대상자는" 같은 주어를 앞에 붙이지 말고 상태를 서술어로 바로 시작할
    것 - 존댓말 어미(~하심/~드림)가 이미 대상을 드러냄. 부득이 주어가 필요하면 실명
    대신 "어르신" 또는 "대상자"만 쓸 것.
12. "특이사항 없음", "이상 없음" 같은 상투적이고 내용 없는 마무리 문구는 사용자가 조치
    항목에서 직접 선택한 경우가 아니면 쓰지 말 것 - 실제로 관찰·수행된 내용으로만
    끝맺을 것.
13. 입력된 카테고리 키값을 참고해 문장 흐름에 맥락을 반영할 것.

올바른 예시(상태 1개): "시간 혼동을 보이셔서 현재 시간과 요일을 알려드렸으며 이후 질문
횟수가 줄어드심"
올바른 예시(상태 2개 - 항목마다 문장 분리): "단추를 잘못 채우셔서 채울 수 있도록
도와드렸으며 이후 스스로 채우심. 양말을 신지 못하셔서 신을 수 있도록 도와드렸으며 이후
편하게 신으심"
잘못된 예시(절대 이렇게 쓰지 말 것):
"차분한 목소리로 안내하여 안정적인 태도를 보이심" (주관적 평가어를 모델이 스스로 지어냄)
"너무 걱정되셔서 다행히 좋아지셨어요" (감탄사·과장어·구어체)
"안내하며 확인하며 기록하며 마무리하심" (같은 연결어 "~하며" 연속 반복)
"단추를 잘못 채우는 모습이 관찰되어 ~" (완충 표현 - "단추를 잘못 채우셔서"로 연결할 것)
"양말을 신지 못하는 모습이 관찰되어 ~" (같은 이유)

반드시 아래 JSON 객체 하나만 반환하세요. records 배열의 문자열 개수는 "문장 작성 방식"
안내의 문장 개수와 정확히 같아야 합니다. 설명·인사말·목록·마크다운·코드블록은 절대
포함하지 마세요.
{"records": ["문장1", "문장2", "..."]}`;

const GUIDELINES = {
  // 조치 서술 규칙. 선택된 조치가 있으면 그대로 반영하고, 없으면 상태에
  // 맞는 상식적인 조치를 자유롭게 새로 쓰되 "보호자에게 알림"/"관리자
  // 보고"/"특이사항 없음" 같은 상투적 표현은 직접 선택했을 때만 허용한다.
  1: `조치 서술 규칙(순서대로 확인):
a) 조치(action)·조치상황(care_level) 항목이 있으면 그 내용을 실제 수행한 것처럼
   서술할 것. 문장을 나누는 경우("문장 작성 방식" 안내가 나누기)면 상태와 조치를
   나열 순서대로 짝지어 각 문장에 반영할 것(상태1↔조치1, 상태2↔조치2 ...) - 조치가
   모자라면 남는 문장엔 b)처럼 새로 지어낼 것. 합치는 경우(안내가 합치기)면 조치들을
   한 문장에 자연스럽게 녹일 것.
b) 조치·조치상황이 전혀 없으면 관찰한 상태와 실제로 관련 있는, 상식적인 조치를 새로
   작성할 것(아무거나 지어내지 말 것). 예) 기침·가래 → "따뜻한 물을 제공하고 환기를
   실시함", 치아 통증 → "반찬을 잘게 다져 제공함", 실내에만 계심 → "실버체조
   스트레칭을 도와드림".
c) "보호자에게 알림", "관리자 보고", "특이사항 없음"(또는 같은 뜻의 표현)은 사용자가
   조치(action) 항목에서 그 표현을 직접 선택했을 때만 쓸 수 있음 - b)처럼 상태만 보고
   스스로 조치를 지어낼 때는 이 표현들을 절대 포함하지 말 것.
d) 관련 조치를 떠올릴 근거가 전혀 없을 만큼 상태가 애매하면 조치·반응 없이 상태만
   짧게 서술해도 되지만, 이런 경우는 드뭅니다 - 상태가 있으면 보통 b)를 따르세요.

반응 서술 규칙(조치를 서술한 모든 경우에 적용 - a)~b) 중 어느 경우로 조치를 작성했든
문장 끝에 반드시 적용): 조치 내용 뒤에 그 조치를 취한 이후의 결과·반응을 반드시
덧붙일 것. 결과는 앞서 서술한 상태와 실제로 관련 있는 내용이어야 하되, 상태 서술에
쓴 단어를 그대로 반복하지 말고 짧게 지칭할 것(예: "이후 다소 줄어듦", "이후 다소
편안해지심"). "완전히 호전됨", "즉시 좋아지심", "완쾌되심" 같은 완전한 회복·즉각적
완치를 뜻하는 표현은 절대 쓰지 말 것 - "다소", "조금", "잠시 후" 같은 현실적인 정도
표현만 사용하고, 과장 없이 실제로 관찰될 법한 수준으로만 서술할 것.

예시 1(조치 항목을 선택했을 때 - 그 내용을 그대로 반영 + 결과를 끝에 덧붙임):
입력: "- 피부상태:
  상태(status): 건조함
  조치(action): 보습제 도포"
출력: {"records": ["건조하셔서 보습제를 도포하였으며, 이후 다소 편안해짐"]}

예시 2(조치를 선택하지 않았을 때 - 상태에 맞는 상식적인 조치를 새로 작성 + 결과를 끝에 덧붙임):
입력: "- 신체상태:
  상태(status): 기침, 가래"
출력: {"records": ["기침과 가래 증상을 보이셔서 따뜻한 물을 제공하고 환기를 실시하였으며, 이후 다소 줄어듦"]}

예시 3(상태 항목이 2개 이상이고 "문장 작성 방식" 안내가 나누라고 했을 때 - 항목마다
문장을 하나씩, 순서대로 조치를 짝지음. "차분히 안내"처럼 사용자가 직접 고른 조치
표현은 규칙 4의 예외에 따라 그대로 반영함):
입력: "- 인지상태:
  항목: 단추 잘못 채우심, 양말 신지 못하심
  조치(action): 단추 채울 수 있도록 도움드림, 양말을 신을 수 있도록 도움드림"
출력: {"records": ["단추를 잘못 채우셔서 채울 수 있도록 도와드렸으며 이후 스스로 채우심", "양말을 신지 못하셔서 신을 수 있도록 도와드렸으며 이후 편하게 신으심"]}

예시 4(같은 입력이지만 "문장 작성 방식" 안내가 하나로 합치라고 했을 때 - 문자열 1개로
통합):
입력: 예시 3과 동일
출력: {"records": ["단추를 잘못 채우고 양말을 신지 못하셔서 채우고 신을 수 있도록 도와드렸으며, 이후 스스로 하시는 모습이 늘어남"]}`,
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

// [23] /generate 응답에서 {"records": ["...", ...]} 객체를 뽑아낸다. 배열이
// 비어 있으면(모델이 형식을 안 지킨 경우) null을 돌려줘서 호출부가 502로
// 처리하게 한다.
function parseRecordsObject(text) {
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
  if (!Array.isArray(parsed.records)) return null;
  const records = parsed.records
    .filter((r) => typeof r === 'string')
    .map((r) => r.trim())
    .filter((r) => r.length > 0);
  if (records.length === 0) return null;
  return { records };
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

  const observationCount = typeof payload.observation_item_count === 'number'
    ? payload.observation_item_count
    : countObservationItems(selections);
  // [23] 상태 항목이 2개 이상일 때만 "합치기/나누기" 선택이 의미가 있다 - 화면에서
  // 팝업으로 물어보고 고른 값을 payload.mode로 보낸다('split' | 'merged').
  // 1개 이하거나 mode가 없으면(구버전 클라이언트 등) 항상 문장 1개로 합친다.
  let sentenceInstruction;
  if (observationCount >= 2 && payload.mode === 'split') {
    sentenceInstruction =
      `문장 작성 방식: 상태(관찰) 관련 선택 항목이 ${observationCount}개이고, 사용자가 ` +
      `"항목별로 따로" 작성을 선택했습니다. 항목마다 별도 문장을 하나씩 작성해서 records ` +
      `배열에 정확히 ${observationCount}개의 문자열로 담으세요. 각 문장은 40~50자 내외로 ` +
      '간결하게 쓰세요.';
  } else if (observationCount >= 2) {
    const maxChars = observationCount >= 3 ? 60 : 50;
    sentenceInstruction =
      `문장 작성 방식: 상태(관찰) 관련 선택 항목이 ${observationCount}개이고, 사용자가 ` +
      `"한 문장으로" 작성을 선택했습니다(또는 선택하지 않았습니다). 모든 항목을 자연스럽게 ` +
      `하나의 문장으로 통합해서 records 배열에 문자열 1개만 담으세요. 문장 길이는 최대 ` +
      `${maxChars}자까지 허용됩니다.`;
  } else {
    sentenceInstruction =
      '문장 작성 방식: 상태(관찰) 관련 선택 항목이 1개 이하이므로 records 배열에 문자열 ' +
      '1개만, 40~50자 내외로 간결하게 담으세요.';
  }
  lines.push('', sentenceInstruction);

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

// [20] 조치(action)·조치상황(care_level)·방향/부위(수식어)를 뺀, 문장의
// "상태(관찰)" 쪽 분량을 좌우하는 선택 개수. 앱의 문장 길이 경고 배너와
// 같은 기준이다 - 값을 안 보내는 호출(구버전 클라이언트, 직접 테스트 등)도
// 대비해 selections에서 다시 계산하는 걸 기본으로 쓴다.
function countObservationItems(selections) {
  let total = 0;
  for (const data of Object.values(selections)) {
    if (!data || typeof data !== 'object') continue;
    total += (data.status?.length || 0) + (data.items?.length || 0);
    if (data.body_part && typeof data.body_part === 'object') {
      total += data.body_part.symptom?.length || 0;
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
    // [24] 프롬프트 캐싱: 지침(system)은 record_type이 같으면 요청마다 완전히
    // 동일한 문자열이라 - 그 부분만 cache_control로 캐시해둔다. 첫 요청은
    // 그대로 과금되고(cache_creation_input_tokens, 약 1.25배), 이후 같은
    // 지침으로 오는 요청은 캐시 히트로 입력 토큰 비용이 크게 줄어든다
    // (cache_read_input_tokens, 약 0.1배). 기본 TTL(5분)을 그대로 쓴다.
    const message = await anthropic.messages.create({
      model: MODEL,
      max_tokens: 1536,
      system: [
        {
          type: 'text',
          text: buildSystemPrompt(payload.record_type),
          cache_control: { type: 'ephemeral' },
        },
      ],
      messages: [{ role: 'user', content: buildUserMessage(payload) }],
    });

    console.log(
      '토큰 사용량:',
      JSON.stringify({
        input: message.usage?.input_tokens,
        cache_write: message.usage?.cache_creation_input_tokens,
        cache_read: message.usage?.cache_read_input_tokens,
        output: message.usage?.output_tokens,
      }),
    );

    const text = message.content
      .filter((block) => block.type === 'text')
      .map((block) => block.text)
      .join('\n')
      .trim();

    const parsed = parseRecordsObject(text);
    if (!parsed) {
      console.error(
        'AI 응답 형식 오류(records JSON 아님):',
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
