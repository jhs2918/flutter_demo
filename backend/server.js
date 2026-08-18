const express = require('express');
const cors = require('cors');
const Anthropic = require('@anthropic-ai/sdk');

const MODEL = 'claude-sonnet-5';
const MAX_SELECTED_ITEMS = 10;

// [06] 선택된 카테고리별 항목을 방문요양 상태변화기록 문장으로 바꾸는 규칙.
// 앱 프론트에서 넘어온 카테고리 키값과 항목만으로 판단하며, 요양보호사가 직접
// 검토·수정하는 초안을 생성하는 것이 목적이다.
const SYSTEM_PROMPT = `당신은 방문요양 상태변화기록지를 작성하는 요양보호사를 돕는 보조 도구입니다.
요양보호사가 선택한 카테고리별 관찰 항목을 바탕으로, 다음 규칙을 반드시 지켜 기록 문장을 생성하세요.

1. 같은 단어 조합이 다시 들어오더라도 매번 자연스럽게 다른 문장을 생성할 것.
2. 추측하지 말 것 - 입력된 관찰 사실만 기재할 것.
3. 감정 표현을 쓰지 말 것 - 예) "기분이 안 좋아 보임" 대신 "대답이 평소보다 짧음"으로 서술.
4. 의학적 판단을 내리지 말 것 - 예) "치매 악화" 대신 "반복 질문 횟수 증가"로 서술.
5. 수치·횟수 중심으로 서술할 것 - 예) "조금" 대신 "약 30% 섭취"로 서술.
6. 과거형 문체(~함 / ~하심 / ~하였음)로 통일할 것.
7. 상태 기록 후 취한 대응 행동을 반드시 포함할 것.
8. 문장 구조 순서를 "상태 관찰 → 어르신 반응 → 대응 조치 → 결과" 순으로 고정할 것.
9. "이에 따라 / 이후 / 확인 결과" 등 자연스러운 연결어로 문장을 이을 것.
10. 선택 항목 수에 따라 문장 길이를 조절할 것 - 1~3개 선택 시 1문장으로 간결하게, 4~10개 선택 시 2~3문장으로 작성하며, 어떤 경우에도 최대 3문장을 넘지 말 것. 단순 나열은 절대 금지.
11. 선택 항목을 단순 나열하지 말고 하나의 상황으로 통합하여 서술할 것.
12. 같은 주어가 반복되지 않도록 "어르신께서는" / "대상자" 등으로 교체하며 변주를 줄 것.
13. 낙상·출혈·통증·혈압이상·인지변화가 포함된 경우 보호자 알림 문구를 반드시 포함하고, 경미한 일상 상태만 있는 경우에는 알림 문구를 생략할 것.
14. 마무리 문장은 "지속적으로 관찰하며 서비스를 제공함" 또는 "이후 특이사항 없이 서비스를 마침" 중 하나로 통일할 것.
15. 입력된 카테고리 키값을 참고하여 문장 흐름에 맥락을 반영할 것.
16. 어르신의 이름을 문장에 직접 표기하지 말 것 - 이름 대신 항상 "어르신" 또는 "대상자"로 표현할 것.

출력은 완성된 기록 문장만 반환하고, 별도의 설명·인사말·목록 형식·따옴표는 포함하지 마세요.`;

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

// 선택된 카테고리별 항목을 Claude에게 전달할 사용자 메시지로 변환한다.
function buildUserMessage(selections) {
  const lines = Object.entries(selections)
    .filter(([, items]) => Array.isArray(items) && items.length > 0)
    .map(([category, items]) => `- ${category}: ${items.join(', ')}`);

  return [
    '다음은 이번 방문에서 선택된 카테고리별 관찰 항목입니다.',
    '',
    lines.join('\n'),
    '',
    '위 항목을 반영하여 규칙에 맞는 방문요양 상태변화기록 문장을 작성하세요.',
  ].join('\n');
}

function countSelectedItems(selections) {
  return Object.values(selections).reduce(
    (total, items) => total + (Array.isArray(items) ? items.length : 0),
    0,
  );
}

app.post('/generate', async (req, res) => {
  const { selections } = req.body ?? {};

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
    const message = await anthropic.messages.create({
      model: MODEL,
      max_tokens: 512,
      system: SYSTEM_PROMPT,
      messages: [{ role: 'user', content: buildUserMessage(selections) }],
    });

    const text = message.content
      .filter((block) => block.type === 'text')
      .map((block) => block.text)
      .join('\n')
      .trim();

    res.json({ text });
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
    const message = await anthropic.messages.create({
      model: MODEL,
      max_tokens: 200,
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
