import { getChatGPTUser } from "../../chatgpt-auth";
import {
  addUnitComment,
  readUnitReview,
  saveUnitDecision,
} from "../../../db/reviews";
import {
  isReviewDecision,
  normalizeComment,
} from "../../../lib/reviews";
import { unitConcepts } from "../../unitData";

export const dynamic = "force-dynamic";

function json(data: unknown, status = 200): Response {
  return Response.json(data, {
    status,
    headers: { "Cache-Control": "no-store" },
  });
}

async function authorize() {
  const user = await getChatGPTUser();
  if (!user) return null;
  return user;
}

function conceptFromRequest(request: Request) {
  const searchParams = new URL(request.url).searchParams;
  const unitId = searchParams.get("unit");
  const versionId = searchParams.get("version");
  const concept = unitConcepts.find((candidate) => candidate.id === unitId);
  if (!concept) return null;

  const version = versionId
    ? concept.versions.find((candidate) => candidate.id === versionId)
    : concept.versions.find(
        (candidate) => candidate.id === concept.currentVersionId,
      );
  if (!version) return null;

  return { concept, version };
}

function acceptsSameOriginJson(request: Request): boolean {
  const origin = request.headers.get("Origin");
  const contentType = request.headers.get("Content-Type") ?? "";
  return (
    origin === new URL(request.url).origin &&
    contentType.toLowerCase().startsWith("application/json")
  );
}

export async function GET(request: Request): Promise<Response> {
  const user = await authorize();
  if (!user) return json({ error: "Sign in required." }, 401);

  const resolved = conceptFromRequest(request);
  if (!resolved) return json({ error: "Unknown unit or version." }, 400);

  return json(
    await readUnitReview(resolved.concept.id, resolved.version.sha256),
  );
}

export async function PUT(request: Request): Promise<Response> {
  const user = await authorize();
  if (!user) return json({ error: "Sign in required." }, 401);
  if (!acceptsSameOriginJson(request)) {
    return json({ error: "Same-origin JSON request required." }, 403);
  }

  const resolved = conceptFromRequest(request);
  if (!resolved) return json({ error: "Unknown unit or version." }, 400);

  const payload = (await request.json().catch(() => null)) as {
    decision?: unknown;
  } | null;
  if (!payload || !isReviewDecision(payload.decision)) {
    return json({ error: "Choose Approve or Needs work." }, 400);
  }

  await saveUnitDecision(
    resolved.concept.id,
    resolved.version.sha256,
    payload.decision,
    user,
  );
  return json(
    await readUnitReview(resolved.concept.id, resolved.version.sha256),
  );
}

export async function POST(request: Request): Promise<Response> {
  const user = await authorize();
  if (!user) return json({ error: "Sign in required." }, 401);
  if (!acceptsSameOriginJson(request)) {
    return json({ error: "Same-origin JSON request required." }, 403);
  }

  const resolved = conceptFromRequest(request);
  if (!resolved) return json({ error: "Unknown unit or version." }, 400);

  const payload = (await request.json().catch(() => null)) as {
    body?: unknown;
  } | null;
  const body = normalizeComment(payload?.body);
  if (!body) {
    return json(
      { error: "Write a comment between 1 and 2,000 characters." },
      400,
    );
  }

  await addUnitComment(
    resolved.concept.id,
    resolved.version.sha256,
    body,
    user,
  );
  return json(
    await readUnitReview(resolved.concept.id, resolved.version.sha256),
    201,
  );
}
