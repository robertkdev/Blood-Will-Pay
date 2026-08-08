import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: "Gamble Battle — RGA Matrix Explorer",
    template: "%s — Gamble Battle",
  },
  description:
    "A planning laboratory for Gamble Battle's RGA counter web, trait capstones, and numbered bridge roster.",
  applicationName: "Gamble Battle RGA Matrix Explorer",
  openGraph: {
    type: "website",
    title: "Gamble Battle — RGA Matrix Explorer",
    description:
      "Explore a zero-sum counter web, complete trait capstones, 23 numbered bridge units, and fieldable double-vertical teams.",
    images: [
      {
        url: "/og-card.png",
        width: 1200,
        height: 630,
        alt: "Gamble Battle RGA Matrix Explorer counter web",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "Gamble Battle — RGA Matrix Explorer",
    description:
      "A mathematical counter web and complete bridge-unit plan for 21 active traits.",
    images: ["/og-card.png"],
  },
  other: {
    "theme-color": "#090a0f",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
