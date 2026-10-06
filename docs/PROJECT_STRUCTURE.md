# Project structure

SkillConnect uses a single repository for its Django API and Flutter client.
The existing implementation follows this layout:

```text
SkillConnect/
├── backend/
│   ├── config/                 # Django settings, root URLs and WSGI entry point
│   ├── marketplace/
│   │   ├── models.py           # Database entities
│   │   ├── serializers.py      # API validation and representations
│   │   ├── views.py            # API endpoints and permissions
│   │   ├── services.py         # Business logic
│   │   ├── urls.py             # Marketplace routes
│   │   ├── admin.py            # Administration interface
│   │   ├── migrations/         # Versioned database schema
│   │   ├── management/commands/ # Demo data and notification delivery
│   │   └── tests/              # Backend tests
│   ├── manage.py
│   ├── requirements.txt        # Runtime dependencies
│   ├── requirements-dev.txt    # Development dependencies
│   └── Dockerfile
├── mobile/
│   ├── lib/
│   │   ├── main.dart           # App entry point and navigation
│   │   ├── api.dart            # API client and authentication
│   │   ├── push.dart           # Native push integration
│   │   ├── ui.dart             # Shared interface components
│   │   └── screens/            # Discovery, profiles, activity and account
│   ├── test/                  # Flutter tests
│   ├── android/               # Android platform project
│   ├── ios/                   # iOS platform project
│   ├── web/                   # Browser platform project
│   └── pubspec.yaml           # Flutter dependencies and app metadata
├── docs/                      # API, proposal coverage and setup guides
├── .github/workflows/ci.yml    # Backend and Flutter validation
├── .env.example               # Docker environment template
├── .gitignore                 # Secrets and generated-file exclusions
├── compose.yaml               # API and PostgreSQL services
├── pytest.ini                 # Backend test configuration
├── Makefile                   # Common development commands
└── README.md                  # Setup and usage
```

## Adding code

Add backend entities to `models.py`, API representations to `serializers.py`,
and endpoint behavior to `views.py`. Keep reusable business rules in
`services.py`. Generate migrations after changing models and add behavior
tests under `backend/marketplace/tests/`.

Add app pages under `mobile/lib/screens/`, reusable widgets in `ui.dart`,
and server communication in `api.dart`. Keep credentials and server-only
business rules in the backend. Add Flutter tests under `mobile/test/`.

## Development commands

Follow the root README to install dependencies and activate a Python 3.12+
virtual environment. From the repository root:

```sh
make help
make migrate
make backend
make mobile
make check
make test
```

Override tools when needed, for example
`make backend PYTHON=.venv312/bin/python`.
The mobile target runs a browser client on port 8080 with local HTTP enabled.
For Android emulator and deployment commands, see the root README.

Local virtual environments, database files, uploaded media, build outputs and
secrets are excluded from Git. Commit application source, dependency manifests,
migrations, platform scaffolding and documentation.
