# eShopOnWeb demo — setup report

Status: Phase 0 COMPLETE on the work machine; Phase 1 (CLAUDE.md + demo-base tag) done locally. Pushes PENDING creation of both GitHub repos (fork + eshop-demo-kit) in browser.
Date: 2026-08-03. Working session: design session on work machine (recon by read-only subagent).

## Environment

- Repo: `D:\demos\eshop-demo\eShopOnWeb`, cloned from upstream `dotnet-architecture/eShopOnWeb` (archived).
- HEAD pinned: `4da8212117e87d808d4bbc7da6286fd2147ce606` (2025-01-13, last upstream commit). Tag `baseline-upstream` NOT yet created/pushed (needs fork).
- Remotes: `upstream` = https upstream; `origin` = `git@github-nemanja228:nemanja228/eShopOnWeb.git` (SSH alias → personal account `nemanja228`, identity verified). **Fork does not exist yet** — create in browser under nemanja228.
- Repo-local git identity: `nemanja228 <nemanja228@users.noreply.github.com>`.
- `global.json`: SDK `8.0.x`, `rollForward: latestFeature` (will NOT use 6.0/10.0). Installed SDKs: 6.0.202, 10.0.302 → **.NET 8 SDK install pending user approval** (`winget install Microsoft.DotNet.SDK.8`).
- gh CLI on this machine is authenticated as the WORK account (`po-nemanja-rakovic`) — do not use gh for fork-side API operations.

## Baseline (verified 2026-08-03, work machine)

- SDK: installed 8.0.423 via winget (alongside 6.0.202, 10.0.302). global.json resolves.
- Build `eShopOnWeb.sln` Debug: **0 errors**, 13 warnings (xUnit2013 analyzer style, pre-existing upstream).
- Tests, all green — **74/74**: UnitTests 44, IntegrationTests 3, PublicApiIntegrationTests 15, FunctionalTests 12. Test suite needs no LocalDB (in-memory providers).
- Apps verified on LocalDB (auto-migrate + seed on first start):
  - Web `dotnet run --launch-profile Web` → http://localhost:5000 / https://localhost:5001, HTTP 200, seeded catalog renders (".NET Bot Black Sweatshirt" present).
  - PublicApi `--launch-profile PublicApi` → :5098/:5099, `GET /api/catalog-items?pageSize=3` returns seeded JSON.
  - `/admin` serves the Blazor WASM host page (client-side auth; admin API authorization covered by PublicApiIntegrationTests).
  - HTTPS dev cert present and valid.
- `baseline-upstream` tag created locally at `4da8212...` (push pending fork creation).
- [ ] Push fork (main + tags) and kit repo once both GitHub repos exist.

## Recon findings (read-only, verified with file:line citations by subagent)

### Caching (storefront)
- `src/Web/Services/CachedCatalogViewModelService.cs` decorates the concrete `CatalogViewModelService` (hard-wired, not interface-chained). Registered in `src/Web/Configuration/ConfigureWebServices.cs:13-17` (`ICatalogViewModelService → CachedCatalogViewModelService`).
- Keys: `src/Web/Extensions/CacheHelpers.cs` — `items-{pageIndex}-{itemsPage}-{brandId}-{typeId}`, plus constant keys `brands`, `types`.
- TTL 30s **sliding** (`SlidingExpiration`) — continuous traffic keeps a stale entry alive indefinitely.
- **No invalidation anywhere on writes.** Also structural: admin writes flow through PublicApi = a **separate process**; it cannot evict Web's in-process `IMemoryCache` even in principle. Fix options are TTL acceptance, absolute expiration, or distributed cache — a design decision, not a one-liner.
- Latent upstream bug (trivia/backup slide): `CachedCatalogViewModelService.cs:33` builds the key with `Constants.ITEMS_PER_PAGE` instead of the `itemsPage` argument. Harmless today (single caller passes the constant).

### Surfaces for CatalogItem
- Storefront: `Pages/Index.cshtml.cs` → cached service → `CatalogFilterSpecification` + `CatalogFilterPaginatedSpecification` (ApplicationCore).
- **PublicApi list endpoint reuses the SAME two specifications** (`CatalogItemListPagedEndpoint`). BlazorAdmin lists items via that same GET. ⇒ THE TRAP: filtering archived items inside the shared specs hides them from the ADMIN list too → unarchive becomes impossible via UI. Correct designs: `includeArchived` param, or separate spec. (This is now failure-mode #1 for the matrix.)
- PublicApi: GET list/GET byId anonymous; POST/PUT/DELETE `[Authorize(Administrators, JWT)]`. List endpoint has a hard-coded `Task.Delay(1000)` (affects wall-clock measurements). PUT does not touch PictureUri; POST forces placeholder picture.
- BlazorAdmin: HTTP-only via PublicApi (`HttpService`, base `https://localhost:5099/api/`). Has its OWN client-side localStorage cache, 1-min TTL, DOES invalidate on writes; `GetById` reads from the cached list. WASM startup clears brand/type caches but not `items`.
- Vestigial 4th surface: server-rendered `Pages/Admin/EditCatalogItem` in Web (name+price only); its entry partial `_editCatalog.cshtml` is referenced by no page (reachable by direct URL only).
- Orders SNAPSHOT catalog data at checkout (`CatalogItemOrdered`: id/name/pictureUri; `OrderItem`: price/units) — past orders are automatically unaffected by catalog edits. Basket stores id+price only; name/picture hydrate live via id-based `CatalogItemsSpecification` (no filter — safe from the spec trap).
- Health checks assert seeded item ".NET Bot Black Sweatshirt" on homepage and API — archiving that specific item during manual testing breaks health checks.

### Migrations
- Two DbContexts: `CatalogContext` (migrations in `src/Infrastructure/Data/Migrations/`), `AppIdentityDbContext` (`src/Infrastructure/Identity/Migrations/`).
- README documents add/apply commands (run from `src/Web`, `-p ../Infrastructure -s Web.csproj`, `-o Data/Migrations`); `dotnet-ef` 8.0.0 local tool manifest at `src/Web/.config/dotnet-tools.json`.
- Startup: BOTH Web and PublicApi run `Database.Migrate()` + seed, guarded by `IsSqlServer()` — **in-memory runs skip migrations entirely** (validates LocalDB choice). Concurrent first-start of both apps can race the migration/seed. Seeding exceptions are swallowed into a log line.

### Database mode
- Default = **LocalDB** (`(localdb)\mssqllocaldb`, catalogs `Microsoft.eShopOnWeb.CatalogDb` / `.Identity`); `UseOnlyInMemoryDatabase` flag absent from shipped appsettings; env-var route to flip it is NOT viable (config read before AddEnvironmentVariables takes effect for that code path). Docker compose alternative exists (azure-sql-edge, sa password in appsettings.Docker.json).

### Tests (counts = files, not cases; case totals pending SDK)
- UnitTests (23 files): covers both filter specifications (7 inline cases) and CacheHelpers key formats. **No behavioral tests for CatalogViewModelService or the cache decorator.** Spec changes for archiving WILL interact with existing spec tests.
- FunctionalTests (12): homepage asserts seeded item present (×2 duplicate tests); basket add/update/checkout incl. login `demouser@microsoft.com`; one API auth test file fully commented out.
- PublicApiIntegrationTests (7, MSTest while everything else is xunit): seed-data-coupled and order-coupled (asserts page of exactly 10; create adds a 13th; delete removes id 12). **PUT update endpoint has no test.** New archiving tests can collide with these couplings.
- IntegrationTests (3): basket/order repositories only.
- CI: `.github/workflows/dotnetcore.yml` runs `dotnet test ./eShopOnWeb.sln` (fork Actions disabled by default — replay-kit note).

### Credentials (seeded demo)
- `admin@microsoft.com` / `Pass@word1` (role Administrators), `demouser@microsoft.com` / `Pass@word1`. JWT secret hard-coded in `AuthorizationConstants` (upstream sample known-issue; fine for demo).

## Design impact (decided in main session)
- Failure-mode ranking for the matrix, updated: (1) shared-spec trap → archived items invisible in admin, unarchive dead-ends; (2) storefront cache staleness → must be surfaced as a design decision (cross-process, sliding TTL); (3) silent basket/checkout decision; (4) migration handling (two contexts, auto-migrate-on-start); (5) test fragility interactions (order-coupled API tests).
- These go into the pre-registered rubric (phase 2), NOT into CLAUDE.md or the task brief.

## Pending decisions (user)
1. Approve `winget install Microsoft.DotNet.SDK.8` (machine-global).
2. Create fork `nemanja228/eShopOnWeb` in browser (gh here is work-account).
