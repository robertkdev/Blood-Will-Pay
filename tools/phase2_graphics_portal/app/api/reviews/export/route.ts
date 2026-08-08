import { readAllReviewRevisions } from "../../../../db/reviews";
import {
  buildReviewExport,
  reviewExportToMarkdown,
} from "../../../../lib/reviewExport";
import sourceManifest from "../../../../public/source-manifest.json";
import { unitConcepts } from "../../../unitData";

export const dynamic = "force-dynamic";

export async function GET(request: Request): Promise<Response> {
  try {
    const rows = await readAllReviewRevisions();
    const reviewExport = buildReviewExport(
      unitConcepts,
      sourceManifest.sourceHead,
      rows,
    );
    const format = new URL(request.url).searchParams.get("format");
    if (format === "markdown") {
      return new Response(reviewExportToMarkdown(reviewExport), {
        headers: {
          "Cache-Control": "no-store",
          "Content-Type": "text/markdown; charset=utf-8",
        },
      });
    }
    return Response.json(reviewExport, {
      headers: { "Cache-Control": "no-store" },
    });
  } catch (error: unknown) {
    console.error("Review export failed.", error);
    return Response.json(
      { error: "Review export is temporarily unavailable." },
      { status: 500, headers: { "Cache-Control": "no-store" } },
    );
  }
}
