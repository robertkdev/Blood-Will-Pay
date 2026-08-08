import type { Metadata } from "next";
import { Explorer } from "./Explorer";

export const metadata: Metadata = {
  title: {
    absolute: "Gamble Battle — RGA Matrix Explorer",
  },
  description:
    "Explore the proven RGA counter web, trait capstones, numbered bridge units, and fieldable double-vertical teams.",
};

export default function Home() {
  return <Explorer />;
}
