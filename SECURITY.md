# Budget Studio — Security

Full security guide (architecture threats, Supabase Auth/RLS checklist, client defenses, OWASP mapping, tests):

**→ [`docs/SECURITY.md`](docs/SECURITY.md)**

Related: [`LAUNCH_CHECKLIST.md`](LAUNCH_CHECKLIST.md) · [`docs/PRODUCTION_AUDIT.md`](docs/PRODUCTION_AUDIT.md) · [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)

Live site: https://elcomparob111.github.io/budget-studio/

This app ships only the **anon / publishable** key. Never put `service_role` in the client or git.
