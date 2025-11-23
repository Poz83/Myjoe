export default function HomePage() {
  return (
    <main className="mx-auto flex min-h-[calc(100vh-3.5rem)] max-w-5xl flex-col items-start justify-center gap-8 px-4 py-10">
      <section className="space-y-2">
        <h1 className="text-3xl font-semibold tracking-tight">
          My Joe – creator console
        </h1>
        <p className="max-w-xl text-sm text-zinc-300">
          You&apos;re in Stage 1 (Core user experience & admin API).
          This shell will grow into the dashboard where you manage users,
          projects, credits, and generation jobs for your KDP/Etsy workflows.
        </p>
      </section>

      <section className="grid w-full gap-4 text-sm text-zinc-300 sm:grid-cols-2">
        <div className="rounded-xl border border-zinc-800 bg-zinc-950/60 p-4">
          <h2 className="mb-1 text-xs font-semibold uppercase tracking-wide text-zinc-400">
            Stage status
          </h2>
          <p>Stage 1 – wiring up the core app and Joe View admin APIs.</p>
        </div>

        <div className="rounded-xl border border-zinc-800 bg-zinc-950/60 p-4">
          <h2 className="mb-1 text-xs font-semibold uppercase tracking-wide text-zinc-400">
            Next focus
          </h2>
          <p>Connect admin endpoints to Supabase and build Joe View screens.</p>
        </div>

        <div className="rounded-xl border border-zinc-800 bg-zinc-950/60 p-4 sm:col-span-2">
          <h2 className="mb-1 text-xs font-semibold uppercase tracking-wide text-zinc-400">
            Quick mental model
          </h2>
          <p>
            Think of this app as two halves: the creator side (where you
            generate and manage colouring pages and interiors) and the Joe
            View side (where you inspect users, credits and jobs). Right now
            we&apos;re putting down the rails for both.
          </p>
        </div>
      </section>
    </main>
  );
}
