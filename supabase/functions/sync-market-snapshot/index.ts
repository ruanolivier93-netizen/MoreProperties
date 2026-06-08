import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

type Bracket = {
  min_value: number;
  max_value: number | null;
  base_amount: number;
  marginal_rate: number;
  threshold: number;
};

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const syncToken = Deno.env.get("MARKET_SYNC_TOKEN") ?? "";

if (!supabaseUrl || !serviceRoleKey) {
  throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
}

const db = createClient(supabaseUrl, serviceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return json({ error: "Method not allowed" }, 405);
    }

    if (syncToken) {
      const auth = req.headers.get("authorization") ?? "";
      const token = auth.replace(/^Bearer\s+/i, "").trim();
      if (token != syncToken) {
        return json({ error: "Unauthorized" }, 401);
      }
    }

    const { data: existing } = await db
      .from("market_snapshot")
      .select()
      .eq("id", "za")
      .maybeSingle();

    const [sarsHtml, sarbHtml] = await Promise.all([
      fetchText("https://www.sars.gov.za/tax-rates/transfer-duty/"),
      fetchText("https://www.resbank.co.za/en/home/what-we-do/monetary-policy"),
    ]);

    const parsedPrime = parsePrimeRate(sarbHtml);
    const parsedBrackets = parseTransferDutyBrackets(sarsHtml);

    const next = {
      id: "za",
      prime_rate: parsedPrime?.rate ?? existing?.prime_rate ?? 10.5,
      prime_rate_as_of: parsedPrime?.asOf ?? existing?.prime_rate_as_of ?? isoDate(new Date()),
      prime_rate_source: "SARB current market rates",
      cape_town_house_price_yoy: existing?.cape_town_house_price_yoy ?? "+8.4%",
      cape_town_source: existing?.cape_town_source ?? "House price index",
      gauteng_rentals_yoy: existing?.gauteng_rentals_yoy ?? "+5.1%",
      gauteng_source: existing?.gauteng_source ?? "PayProp rental index",
      transfer_duty_effective_label:
        parsedBrackets?.effectiveLabel ??
        existing?.transfer_duty_effective_label ??
        "SARS 2025/26",
      transfer_duty_source: "SARS transfer duty rates",
      transfer_duty_brackets:
        parsedBrackets?.brackets ?? existing?.transfer_duty_brackets ?? defaultBrackets,
      synced_at: new Date().toISOString(),
    };

    const { error } = await db.from("market_snapshot").upsert(next);
    if (error) throw error;

    return json({
      ok: true,
      prime_rate: next.prime_rate,
      prime_rate_as_of: next.prime_rate_as_of,
      transfer_duty_effective_label: next.transfer_duty_effective_label,
      bracket_count: Array.isArray(next.transfer_duty_brackets)
        ? next.transfer_duty_brackets.length
        : 0,
    });
  } catch (error) {
    return json(
      {
        ok: false,
        error: error instanceof Error ? error.message : String(error),
      },
      500,
    );
  }
});

const defaultBrackets: Bracket[] = [
  { min_value: 1, max_value: 1210000, base_amount: 0, marginal_rate: 0, threshold: 1210000 },
  { min_value: 1210001, max_value: 1663800, base_amount: 0, marginal_rate: 0.03, threshold: 1210000 },
  { min_value: 1663801, max_value: 2329300, base_amount: 13614, marginal_rate: 0.06, threshold: 1663800 },
  { min_value: 2329301, max_value: 2994800, base_amount: 53544, marginal_rate: 0.08, threshold: 2329300 },
  { min_value: 2994801, max_value: 13310000, base_amount: 106784, marginal_rate: 0.11, threshold: 2994800 },
  { min_value: 13310001, max_value: null, base_amount: 1241456, marginal_rate: 0.13, threshold: 13310000 },
];

async function fetchText(url: string): Promise<string> {
  const res = await fetch(url, {
    headers: {
      "user-agent": "more-properties-market-sync/1.0",
      accept: "text/html,application/xhtml+xml",
    },
  });
  if (!res.ok) {
    throw new Error(`Failed to fetch ${url}: ${res.status}`);
  }
  return await res.text();
}

function parsePrimeRate(html: string): { rate: number; asOf: string } | null {
  const text = toPlainText(html);
  const prime = text.match(/PRIME\s*([0-9]+(?:\.[0-9]+)?)%/i);
  if (!prime) return null;

  const rate = Number(prime[1]);
  if (!Number.isFinite(rate) || rate <= 0) return null;

  const near = text.slice(Math.max(0, prime.index! - 120), prime.index! + 120);
  const asOfMatch = near.match(/(\d{1,2}\s+[A-Za-z]{3,9}\s+20\d{2})/);

  return {
    rate,
    asOf: asOfMatch?.[1] ?? isoDate(new Date()),
  };
}

function parseTransferDutyBrackets(
  html: string,
): { effectiveLabel: string; brackets: Bracket[] } | null {
  const text = toPlainText(html);
  const sectionMatch = text.match(
    /2026\s*\(With effect from 1 April 2025\)([\s\S]*?)2025\s*\(/i,
  );
  if (!sectionMatch) return null;

  const section = sectionMatch[1].replace(/\s+/g, " ");

  const bracket2 = section.match(
    /1\s*210\s*001\s*[\-–]\s*1\s*663\s*800\s*3%\s*of\s*the\s*value\s*above\s*R?\s*1\s*210\s*000/i,
  );
  const bracket3 = section.match(
    /1\s*663\s*801\s*[\-–]\s*2\s*329\s*300\s*R\s*13\s*614\s*\+\s*6%\s*of\s*the\s*value\s*above\s*R\s*1\s*663\s*800/i,
  );
  const bracket4 = section.match(
    /2\s*329\s*301\s*[\-–]\s*2\s*994\s*800\s*R\s*53\s*544\s*\+\s*8%\s*of\s*the\s*value\s*above\s*R\s*2\s*329\s*300/i,
  );
  const bracket5 = section.match(
    /2\s*994\s*801\s*[\-–]\s*13\s*310\s*000\s*R\s*106\s*784\s*\+\s*11%\s*of\s*the\s*value\s*above\s*R\s*2\s*994\s*800/i,
  );
  const bracket6 = section.match(
    /13\s*310\s*001\s*and\s*above\s*R\s*1\s*241\s*456\s*\+\s*13%\s*of\s*the\s*value\s*exceeding\s*R\s*13\s*310\s*000/i,
  );

  if (!bracket2 || !bracket3 || !bracket4 || !bracket5 || !bracket6) {
    return null;
  }

  return {
    effectiveLabel: "SARS 2025/26",
    brackets: defaultBrackets,
  };
}

function toPlainText(html: string): string {
  return html
    .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/\s+/g, " ")
    .trim();
}

function isoDate(d: Date): string {
  return d.toISOString().slice(0, 10);
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body, null, 2), {
    status,
    headers: { "content-type": "application/json" },
  });
}
