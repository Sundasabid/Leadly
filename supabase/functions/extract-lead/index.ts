const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
const GEMINI_MODEL = "gemini-2.5-flash";

// Structured output schema - mirrors the leads table check constraints exactly.
// propertyOrdering is required by Gemini 2.x+ for predictable structured output field order.
// Placing transcript first enforces the chain-of-thought approach: transcribe then extract.
const RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    transcript: {
      type: "STRING",
      description: "Literal transcription of the voice note. Generated first so all field extractions are grounded in what was actually said.",
    },
    name:         { type: "STRING",  nullable: true },
    phone:        { type: "STRING",  nullable: true },
    budget_pkr:   { type: "NUMBER",  nullable: true },
    area_society: { type: "STRING",  nullable: true },
    property_type: {
      type: "STRING",
      enum: ["house", "plot", "apartment", "commercial", "other"],
      nullable: true,
    },
    intent: {
      type: "STRING",
      enum: ["buy", "rent", "invest"],
      nullable: true,
    },
    timeline: {
      type: "STRING",
      enum: ["immediate", "within_1_month", "1_3_months", "3_6_months", "6_plus_months"],
      nullable: true,
    },
    notes: {
      type: "STRING",
      nullable: true,
      description: "Anything relevant that does not fit the structured fields - preferred floor, specific features, urgency, follow-up requests, etc.",
    },
    confidence: {
      type: "NUMBER",
      description: "Overall extraction confidence 0-1. Lower if audio was unclear or many fields are null.",
    },
  },
  // propertyOrdering controls the generation order - transcript must come first
  // so the model transcribes before extracting, improving numeric field accuracy.
  propertyOrdering: [
    "transcript",
    "name",
    "phone",
    "budget_pkr",
    "area_society",
    "property_type",
    "intent",
    "timeline",
    "notes",
    "confidence",
  ],
  required: ["transcript", "confidence"],
};

const SYSTEM_INSTRUCTION = `You are an AI assistant helping Pakistani real estate agents log lead information from voice notes.

The agent may speak in Roman Urdu (Urdu written in Latin script), Urdu, English, or freely mix all three mid-sentence. This code-switching is completely normal - extract details accurately regardless of language used.

RULES:
1. Transcribe exactly what you hear first (the transcript field), then extract the structured fields from your own transcription. This grounding step improves field accuracy.
2. Be conservative: only populate a field if the information is clearly and unambiguously stated. Return null if a field is unclear, partially audible, or not mentioned at all.
3. Phone numbers: Pakistani agents often read numbers in grouped chunks rather than digit-by-digit. Each chunk is spoken as its own number word - including hundred-compounds where "sou/sau" is part of the chunk value, not a multiplier for the whole phrase. Recognize chunk boundaries from speech structure and concatenate the literal digit value of each chunk in order. Examples: "ikaasi chatees ek sou assi" = chunks (81)(36)(180) -> "8136180"; "zero teen sou do" = chunks (0)(3)(22) -> "0322"; "paanch sou do sou bees" = chunks (502)(220) -> "502220"; "ek sou chaar tees" = chunks (104)(30) -> "10430". Do not compute a single mathematical value from the whole phrase - treat each spoken chunk as an independent digit group and concatenate. If chunk boundaries are ambiguous, any chunk is unclear, or the result length seems wrong for a Pakistani mobile number, return null - a wrong number is worse than no number.
4. Budget: numeric PKR value only, no currency symbols or formatting. Convert Pakistani shorthand precisely: lakh/lac = 100,000 (so "20 lakh" = 2000000), crore/karor = 10,000,000. Return null if the amount is vague or unclear.
5. Property type mapping: makan/ghar = house, plot/zameen/land = plot, flat/apartment = apartment, dukaan/shop/office/commercial = commercial.
6. Intent mapping: khareedna/kheridna/buy/lena = buy, kiraya/rent/lease = rent, invest/lagana/paisa lagana = invest.
7. Timeline: map to the closest enum value. "Jaldi/urgent/immediate" = immediate, "iss mahine/this month" = within_1_month, etc.
8. Notes: capture anything not covered by the structured fields - preferred floor, facing direction, specific features, urgency phrases, follow-up requests.
9. Confidence: reflects only the accuracy of the fields you DID extract, not how many fields are present. If the agent simply did not mention name or phone, null is the correct answer - it is not a confidence penalty. Return high confidence (0.8-1.0) when the fields you did extract were clearly stated and accurately captured. Only lower confidence when the audio itself was unclear, a value you extracted is ambiguous, or you are uncertain about something you did fill in.`;

function jsonResponse(data: unknown, status: number): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed", message: "POST only." }, 405);
  }

  if (!GEMINI_API_KEY) {
    console.error("GEMINI_API_KEY is not set");
    return jsonResponse({ error: "configuration_error", message: "Service is not configured." }, 500);
  }

  // ── Parse request body ───────────────────────────────────────────────────────
  let audio: string;
  let mimeType: string;
  try {
    const body = await req.json();
    if (typeof body.audio !== "string" || !body.audio) {
      throw new Error("missing audio");
    }
    if (typeof body.mimeType !== "string" || !body.mimeType) {
      throw new Error("missing mimeType");
    }
    audio = body.audio as string;
    mimeType = body.mimeType as string;
  } catch {
    return jsonResponse({
      error: "bad_request",
      message: "Body must be JSON with 'audio' (base64 string) and 'mimeType' fields.",
    }, 400);
  }

  // ── Call Gemini ──────────────────────────────────────────────────────────────
  const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`;

  const payload = {
    system_instruction: {
      parts: [{ text: SYSTEM_INSTRUCTION }],
    },
    contents: [{
      parts: [
        { inline_data: { mime_type: mimeType, data: audio } },
        { text: "Extract the lead information from this voice note." },
      ],
    }],
    generationConfig: {
      responseMimeType: "application/json",
      responseSchema: RESPONSE_SCHEMA,
      // thinkingBudget: 0 disables thinking mode - appropriate for a
      // deterministic structured extraction task with no multi-step reasoning.
      thinkingConfig: { thinkingBudget: 0 },
    },
  };

  let geminiRes: Response;
  try {
    geminiRes = await fetch(geminiUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
  } catch {
    return jsonResponse({
      error: "network_error",
      message: "Could not reach the extraction service. Check your connection.",
    }, 502);
  }

  // ── Handle Gemini HTTP errors - don't leak internals ─────────────────────────
  if (!geminiRes.ok) {
    if (geminiRes.status === 429) {
      return jsonResponse({
        error: "rate_limited",
        message: "Too many requests. Please wait a moment and try again.",
      }, 429);
    }
    if (geminiRes.status === 400) {
      // Typically: unsupported MIME type, malformed base64, or empty audio.
      return jsonResponse({
        error: "invalid_audio",
        message: "The audio could not be processed. Ensure it is a valid recording.",
      }, 400);
    }
    // Gemini 5xx or anything else unexpected.
    console.error("Gemini error:", geminiRes.status);
    return jsonResponse({
      error: "extraction_failed",
      message: "Lead extraction failed. Please try again.",
    }, 502);
  }

  // ── Parse Gemini response ────────────────────────────────────────────────────
  let geminiData: Record<string, unknown>;
  try {
    geminiData = await geminiRes.json();
  } catch {
    return jsonResponse({
      error: "parse_error",
      message: "Unexpected response from extraction service.",
    }, 502);
  }

  const candidates = geminiData?.candidates as Array<Record<string, unknown>> | undefined;
  const candidate = candidates?.[0];

  // Safety block - Gemini refused the content.
  if ((candidate?.finishReason as string | undefined) === "SAFETY") {
    return jsonResponse({
      error: "content_filtered",
      message: "The audio content was blocked by safety filters.",
    }, 422);
  }

  const rawText = (
    (candidate?.content as Record<string, unknown>)
      ?.parts as Array<Record<string, unknown>>
  )?.[0]?.text as string | undefined;

  if (!rawText) {
    return jsonResponse({
      error: "empty_response",
      message: "No extraction result was returned.",
    }, 502);
  }

  // With responseMimeType: application/json, rawText is a JSON string.
  let extracted: Record<string, unknown>;
  try {
    extracted = JSON.parse(rawText);
  } catch {
    return jsonResponse({
      error: "parse_error",
      message: "Could not parse the extraction result.",
    }, 502);
  }

  return jsonResponse(extracted, 200);
});
