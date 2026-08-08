import type { Metadata } from "next";
import { headers } from "next/headers";
import "./globals.css";

export async function generateMetadata(): Promise<Metadata> {
  const incoming = await headers();
  const host =
    incoming.get("x-forwarded-host") ?? incoming.get("host") ?? "localhost";
  const protocol =
    incoming.get("x-forwarded-proto") ??
    (host.startsWith("localhost") ? "http" : "https");
  const socialImage = `${protocol}://${host}/og.png`;

  return {
    title: "Phase II Concept Archive — Gamble Battle",
    description:
      "A private, repository-backed inspection gallery for Gamble Battle Phase II unit concepts.",
    icons: {
      icon: "/units/creep.png",
      shortcut: "/units/creep.png",
    },
    openGraph: {
      title: "Gamble Battle — Phase II Concept Archive",
      description: "Twelve current unit directions in one private inspection wall.",
      type: "website",
      images: [
        {
          url: socialImage,
          width: 1744,
          height: 912,
          alt: "Gamble Battle Phase II Concept Archive",
        },
      ],
    },
    twitter: {
      card: "summary_large_image",
      title: "Gamble Battle — Phase II Concept Archive",
      description: "Twelve current unit directions in one private inspection wall.",
      images: [socialImage],
    },
  };
}

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
