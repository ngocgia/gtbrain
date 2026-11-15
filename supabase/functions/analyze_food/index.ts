// Edge Function: analyze_food
// Nhận ảnh món ăn (base64) -> gọi Gemini Vision -> trả về danh sách món + dinh dưỡng.
// API key được lưu dưới dạng secret:  supabase secrets set GEMINI_API_KEY=xxx
//
// Xác thực: deploy với verify_jwt=true — Supabase chặn request không có JWT
// hợp lệ trước khi vào function, nên không cần verify tay bên trong.

// Model mặc định + model dự phòng khi model chính quá tải (HTTP 503).
const GEMINI_MODEL = Deno.env.get('GEMINI_MODEL') ?? 'gemini-3-flash-preview';
const GEMINI_FALLBACK_MODEL =
  Deno.env.get('GEMINI_FALLBACK_MODEL') ?? 'gemini-3.1-flash-lite';
const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY') ?? '';

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const PROMPT = `Bạn là chuyên gia dinh dưỡng am hiểu ẩm thực Việt Nam và châu Á.
Phân tích ảnh thức ăn và ước lượng dinh dưỡng.

Yêu cầu:
- Nhận diện TẤT CẢ các món/thức uống có trong ảnh.
- Tên món bằng tiếng Việt (VD: "Phở bò", "Cơm tấm sườn bì chả", "Cà phê sữa đá").
- Ước lượng khối lượng mỗi món (gram) dựa trên đĩa/bát trong ảnh.
- calories = tổng kcal cả món; protein_g/carbs_g/fat_g tính theo gram.

Trả về ĐÚNG một JSON object, không markdown, không giải thích:
{
  "items": [
    { "name": string, "portion_g": number, "calories": number,
      "protein_g": number, "carbs_g": number, "fat_g": number }
  ],
  "total_calories": number,
  "is_food": boolean
}
Nếu ảnh không phải thức ăn: { "items": [], "total_calories": 0, "is_food": false }`;

interface FoodItem {
  name: string;
  portion_g: number;
  calories: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
}

interface GeminiResponse {
  candidates?: {
    content?: {
      parts?: { text?: string }[];
    };
  }[];
  error?: { message?: string; status?: string };
}

function sanitizeItem(raw: Record<string, unknown>): FoodItem {
  const num = (v: unknown): number => {
    const n = typeof v === 'string' ? parseFloat(v) : Number(v);
    return Number.isFinite(n) && n >= 0 ? Math.round(n * 10) / 10 : 0;
  };
  const name = typeof raw.name === 'string' && raw.name.trim().length > 0
    ? raw.name.trim().slice(0, 120)
    : 'Món không xác định';
  return {
    name,
    portion_g: num(raw.portion_g),
    calories: Math.round(num(raw.calories)),
    protein_g: num(raw.protein_g),
    carbs_g: num(raw.carbs_g),
    fat_g: num(raw.fat_g),
  };
}

/** Tách JSON khỏi phản hồi có thể bị bọc trong ```json ... ``` hoặc văn bản thừa */
function extractJson(text: string): Record<string, unknown> | null {
  const cleaned = text
    .replace(/```json/gi, '')
    .replace(/```/g, '')
    .trim();
  const start = cleaned.indexOf('{');
  const end = cleaned.lastIndexOf('}');
  if (start === -1 || end === -1 || end <= start) return null;
  try {
    return JSON.parse(cleaned.slice(start, end + 1));
  } catch {
    return null;
  }
}

async function callGeminiOnce(
  model: string,
  imageBase64: string,
  mimeType: string,
) {
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;

  const body = {
    contents: [
      {
        role: 'user',
        parts: [
          { inline_data: { mime_type: mimeType, data: imageBase64 } },
          { text: PROMPT },
        ],
      },
    ],
    generationConfig: {
      temperature: 0.1,
      responseMimeType: 'application/json',
      maxOutputTokens: 2048,
    },
  };

  const res = await fetch(`${url}?key=${GEMINI_API_KEY}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

  const json: GeminiResponse = await res.json();
  return { ok: res.ok, status: res.status, json };
}

/** Gọi model chính; nếu quá tải (503) hoặc bị khai tử (404) thì thử model dự phòng. */async function callGemini(imageBase64: string, mimeType: string) {
  const primary = await callGeminiOnce(GEMINI_MODEL, imageBase64, mimeType);
  if (primary.ok) return primary.json;

  const overload =
    primary.status === 503 || primary.status === 404 || primary.status === 429;
  if (overload) {
    console.warn(
      `Model ${GEMINI_MODEL} lỗi ${primary.status}, thử fallback ${GEMINI_FALLBACK_MODEL}`,
    );
    const fallback = await callGeminiOnce(
      GEMINI_FALLBACK_MODEL,
      imageBase64,
      mimeType,
    );
    if (fallback.ok) return fallback.json;
    const msg = fallback.json.error?.message ?? `Gemini HTTP ${fallback.status}`;
    throw new Error(msg);
  }

  const msg = primary.json.error?.message ?? `Gemini HTTP ${primary.status}`;
  throw new Error(msg);
}

/**
 * Kiểm tra Authorization là JWT của user đã đăng nhập (role=authenticated),
 * không chấp nhận anon key — tránh bị lạm dụng endpoint tốn quota Gemini.
 */
function isUserJwt(req: Request): boolean {
  const auth = req.headers.get('Authorization') ?? '';
  if (!auth.startsWith('Bearer ')) return false;
  const parts = auth.slice(7).split('.');
  if (parts.length !== 3) return false;
  try {
    const payload = JSON.parse(atob(parts[1].replace(/-/g, '+').replace(/_/g, '/')));
    return payload.role === 'authenticated' && typeof payload.sub === 'string';
  } catch {
    return false;
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method không hỗ trợ' }), {
      status: 405,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
    });
  }

  if (!isUserJwt(req)) {
    return new Response(JSON.stringify({ error: 'Chưa đăng nhập' }), {
      status: 401,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
    });
  }

  if (!GEMINI_API_KEY) {
    return new Response(
      JSON.stringify({ error: 'Server chưa cấu hình GEMINI_API_KEY' }),
      { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } },
    );
  }

  try {
    const { imageBase64, mimeType } = await req.json();
    if (
      typeof imageBase64 !== 'string' || imageBase64.length < 100 ||
      typeof mimeType !== 'string' || !mimeType.startsWith('image/')
    ) {
      return new Response(JSON.stringify({ error: 'Ảnh không hợp lệ' }), {
        status: 400,
        headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
      });
    }
    // Giới hạn ~7MB base64 (~5MB ảnh)
    if (imageBase64.length > 7_000_000) {
      return new Response(JSON.stringify({ error: 'Ảnh quá lớn (tối đa 5MB)' }), {
        status: 413,
        headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
      });
    }

    const geminiRes = await callGemini(imageBase64, mimeType);
    const text = geminiRes.candidates?.[0]?.content?.parts?.[0]?.text ?? '';
    const parsed = extractJson(text);
    if (!parsed || !Array.isArray(parsed.items)) {
      return new Response(
        JSON.stringify({
          error: 'AI không phân tích được ảnh này',
          is_food: false,
          items: [],
          total_calories: 0,
        }),
        { status: 422, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } },
      );
    }

    const items = (parsed.items as Record<string, unknown>[])
      .slice(0, 15)
      .map(sanitizeItem)
      .filter((i) => i.calories >= 0);
    const totalCalories = items.reduce((sum, i) => sum + i.calories, 0);

    return new Response(
      JSON.stringify({
        is_food: parsed.is_food !== false && items.length > 0,
        items,
        total_calories: totalCalories,
      }),
      { headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Lỗi không xác định';
    console.error('analyze_food error:', message);
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
    });
  }
});
