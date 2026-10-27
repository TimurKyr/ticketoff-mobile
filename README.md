# ticketoff-mobile

Ticket-verification app for **ticketoff** Event Admins (academic MVP).

- **Stack:** Flutter · Dart
- **Role owner:** Mobile dev
- **Purpose:** sign in, select assigned event, scan ticket QR, validate in real time, record/undo check-in, manual attendee search.
- **API client:** generated from backend `/openapi.json` via openapi-generator (dart-dio).

## Getting started

The app starts on the Events screen and requests `GET /health` from the
configured backend. For the Android emulator the default URL is
`http://10.0.2.2:8000`; override it for another environment with
`--dart-define=API_BASE_URL=https://api.example.com`.

```bash
flutter pub get
flutter run
```

## API client generation

Install OpenAPI Generator CLI with the `dart-dio` generator available, then run
the script from the repository root:

```bash
bash tool/gen_api.sh
```

The generator reads `http://localhost:8000/openapi.json` by default. Set
`OPENAPI_URL` to use another backend, for example:

```bash
OPENAPI_URL=https://api.example.com/openapi.json bash tool/gen_api.sh
```

Generated files are written to `lib/generated/api/`.

## Conventions
Branching, commits, and PR rules: see CONTRIBUTING.md (WIP).

## Team & workflow

- **Task tracking:** Jira (Scrum, 2-week sprints).
- **Branching & PR rules:** see the shared team git-flow guide (posted in the team chat).
- All changes land on `main` through a **Pull Request** (1 approval, squash merge, linear history).
