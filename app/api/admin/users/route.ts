import { NextRequest, NextResponse } from "next/server";
import { cookies } from "next/headers";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { createServerClient, type CookieOptions } from "@supabase/ssr";

export const runtime = "nodejs";

/**
 * Environment variables
 *
 * - NEXT_PUBLIC_SUPABASE_URL: Supabase project URL
 * - NEXT_PUBLIC_SUPABASE_ANON_KEY: anon / publishable key (for user session)
 * - SUPABASE_SERVICE_ROLE_KEY: service role key (server-side only!)
 */
const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL;
const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error(
    "Missing Supabase env vars. Ensure NEXT_PUBLIC_SUPABASE_URL, " +
      "NEXT_PUBLIC_SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY are set.",
  );
}

type AdminRole = "owner" | "support" | "read_only";

interface AdminUser {
  id: string;
  email: string | null;
  role: AdminRole;
}

interface JoeViewUserSummary {
  userId: string;
  email: string;
  displayName: string | null;
  planId: string | null;
  planName: string | null;
  subscriptionStatus: string | null;
  creditBalance: number;
  projectCount: number;
  jobCount: number;
  generationCount: number;
  lastActiveAt: string | null;
}

interface UsersListResponse {
  data: JoeViewUserSummary[];
  page: number;
  pageSize: number;
  total: number;
  hasMore: boolean;
}

/**
 * Supabase client using the anon / publishable key and cookies.
 * Used to get the currently logged-in user.
 *
 * Matches the official @supabase/ssr + Next.js pattern:
 * - cookies() is treated as async,
 * - we use getAll/setAll.
 */
async function createSupabaseRouteClient(): Promise<SupabaseClient> {
  const cookieStore = await cookies();

  return createServerClient(SUPABASE_URL!, SUPABASE_ANON_KEY!, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          cookiesToSet.forEach(
            ({ name, value, options }: { name: string; value: string; options: CookieOptions }) => {
              cookieStore.set(name, value, options);
            },
          );
        } catch {
          // If called from a Server Component, writes are ignored.
        }
      },
    },
  });
}

/**
 * Supabase client using the service_role key.
 * This bypasses RLS and is only safe on the server.
 */
function createSupabaseAdminClient(): SupabaseClient {
  return createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });
}

/**
 * Ensure the caller is an admin.
 *
 * 1) Look up the current Supabase user from cookies.
 * 2) Check admin.admin_roles for that user via the service-role client.
 *
 * Any problem reading the auth user is treated as "not logged in"
 * (returns null), not as a 500 error.
 */
async function requireAdminUser(): Promise<AdminUser | null> {
  const supabase = await createSupabaseRouteClient();

  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();

  if (userError) {
    console.error("Error fetching auth user (treated as unauthenticated):", userError);
    return null;
  }

  if (!user) {
    // Not logged in at all
    return null;
  }

  const adminClient = createSupabaseAdminClient();

  const { data: rows, error: adminError } = await adminClient
    .schema("admin")
    .from("admin_roles")
    .select("role")
    .eq("user_id", user.id)
    .limit(1);

  if (adminError) {
    console.error("Error checking admin role:", adminError);
    throw new Error("Failed to check admin role.");
  }

  if (!rows || rows.length === 0) {
    // User exists but is not marked as an admin
    return null;
  }

  const role = rows[0].role as AdminRole;

  if (role === "owner" || role === "support" || role === "read_only") {
    return {
      id: user.id,
      email: user.email ?? null,
      role,
    };
  }

  return null;
}

/**
 * GET /api/admin/users
 *
 * Query params:
 * - q: search string (email/display_name)
 * - planId: filter by plan_id
 * - status: filter by subscription_status
 * - page: page number (1-based, default 1)
 * - pageSize: page size (default 20, max 100)
 * - sort: sort key (last_active_at_desc, last_active_at_asc, credits_desc, credits_asc)
 */
export async function GET(request: NextRequest) {
  try {
    // 1. Authorise caller as admin
    const admin = await requireAdminUser();

    if (!admin) {
      return NextResponse.json(
        { error: "Not authorised to access admin API." },
        { status: 403 },
      );
    }

    // 2. Parse query params
    const { searchParams } = new URL(request.url);

    const q = (searchParams.get("q") ?? "").trim();
    const planId = searchParams.get("planId")?.trim() || null;
    const status = searchParams.get("status")?.trim() || null;
    const sort = searchParams.get("sort") ?? "last_active_at_desc";

    const pageParam = parseInt(searchParams.get("page") ?? "1", 10);
    const pageSizeParam = parseInt(searchParams.get("pageSize") ?? "20", 10);

    const page = Number.isFinite(pageParam) && pageParam > 0 ? pageParam : 1;
    let pageSize =
      Number.isFinite(pageSizeParam) && pageSizeParam > 0 ? pageSizeParam : 20;

    if (pageSize > 100) {
      pageSize = 100;
    }

    const from = (page - 1) * pageSize;
    const to = from + pageSize - 1;

    // 3. Query admin.vw_user_overview via the service-role client
    const adminClient = createSupabaseAdminClient();

    let query = adminClient
      .schema("admin")
      .from("vw_user_overview")
      .select(
        `
        user_id,
        email,
        display_name,
        plan_id,
        plan_name,
        subscription_status,
        credit_balance,
        project_count,
        job_count,
        generation_count,
        last_active_at
      `,
        { count: "exact" },
      );

    if (q) {
      const like = `%${q}%`;
      // Search across email and display_name
      query = query.or(`email.ilike.${like},display_name.ilike.${like}`);
    }

    if (planId) {
      query = query.eq("plan_id", planId);
    }

    if (status) {
      query = query.eq("subscription_status", status);
    }

    switch (sort) {
      case "credits_asc":
        query = query.order("credit_balance", { ascending: true });
        break;
      case "credits_desc":
        query = query.order("credit_balance", { ascending: false });
        break;
      case "last_active_at_asc":
        query = query.order("last_active_at", { ascending: true });
        break;
      case "last_active_at_desc":
      default:
        query = query.order("last_active_at", { ascending: false });
        break;
    }

    const { data, error, count } = await query.range(from, to);

    if (error) {
      console.error("Error querying admin.vw_user_overview:", error);
      return NextResponse.json(
        { error: "Failed to load users.", details: error.message },
        { status: 500 },
      );
    }

    const rows = data ?? [];

    const users: JoeViewUserSummary[] = rows.map((row: any) => ({
      userId: row.user_id,
      email: row.email,
      displayName: row.display_name,
      planId: row.plan_id,
      planName: row.plan_name,
      subscriptionStatus: row.subscription_status,
      creditBalance: Number(row.credit_balance ?? 0),
      projectCount: Number(row.project_count ?? 0),
      jobCount: Number(row.job_count ?? 0),
      generationCount: Number(row.generation_count ?? 0),
      lastActiveAt: row.last_active_at,
    }));

    const total = typeof count === "number" ? count : users.length;
    const hasMore = from + users.length < total;

    const responseBody: UsersListResponse = {
      data: users,
      page,
      pageSize,
      total,
      hasMore,
    };

    return NextResponse.json(responseBody, { status: 200 });
  } catch (error: unknown) {
    console.error("Unhandled error in GET /api/admin/users:", error);

    const message =
      error instanceof Error ? error.message : "Unknown error occurred";

    return NextResponse.json(
      {
        error: "Unexpected error in admin users endpoint.",
        details: message,
      },
      { status: 500 },
    );
  }
}
