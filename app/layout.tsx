import "./globals.css";
import type { Metadata } from "next";
import type { ReactNode } from "react";

export const metadata: Metadata = {
  title: {
    default: "My Joe",
    template: "%s | My Joe",
  },
  description:
    "My Joe helps creators generate KDP-safe, 1-bit colouring pages and interiors for KDP, Etsy, and beyond.",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-black text-zinc-50 antialiased">
        <a
          href="#main"
          className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-50 focus:rounded-md focus:bg-zinc-900 focus:px-3 focus:py-2 focus:text-xs focus:font-medium focus:text-zinc-50"
        >
          Skip to main content
        </a>
        <div className="flex min-h-screen flex-col">
          <header className="border-b border-zinc-800 bg-zinc-950/80 backdrop-blur-sm">
            <div className="mx-auto flex h-14 max-w-5xl items-center justify-between px-4">
              <span className="text-sm font-semibold tracking-tight">
                My Joe
              </span>
              <span className="text-xs text-zinc-400">
                Creator & admin console · Stage 1
              </span>
            </div>
          </header>
          <main id="main" className="flex-1">
            {children}
          </main>
        </div>
      </body>
    </html>
  );
}
