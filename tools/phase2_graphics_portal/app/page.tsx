import type { Metadata } from "next";
import { ConceptGallery } from "./ConceptGallery";

export const metadata: Metadata = {
  title: "Phase II Concept Archive — Gamble Battle",
  description:
    "The current repository-backed master concept for each Gamble Battle Phase II unit.",
};

export default function Home() {
  return <ConceptGallery />;
}
