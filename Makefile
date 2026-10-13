PYTHON ?= python
FLUTTER ?= flutter
DART ?= dart
PROTOTYPE_PYTHON ?= python3
PROTOTYPE_PORT ?= 8082

.PHONY: help install install-backend install-mobile doctor seed prototype migrate backend mobile check check-backend check-mobile test test-backend test-mobile

help:
	@echo "install        Install backend and Flutter development dependencies"
	@echo "doctor         Check local development prerequisites"
	@echo "seed           Create demo data (requires DEMO_PASSWORD)"
	@echo "prototype      Sprint 1 phone prototype on port $(PROTOTYPE_PORT)"
	@echo "migrate        Apply database migrations"
	@echo "backend        Run Django on port 8000"
	@echo "mobile         Run Flutter web on port 8080"
	@echo "check          Check Django, migrations and Flutter"
	@echo "test           Run backend and Flutter tests"
	@echo "Use check-backend, check-mobile, test-backend or test-mobile separately."

install: install-backend install-mobile

install-backend:
	$(PYTHON) -m pip install -r backend/requirements-dev.txt

install-mobile:
	cd mobile && $(FLUTTER) pub get

doctor:
	$(PYTHON) scripts/dev_doctor.py --flutter "$(FLUTTER)" --dart "$(DART)"

seed:
	$(PYTHON) backend/manage.py seed_demo

prototype:
	$(PROTOTYPE_PYTHON) -m http.server $(PROTOTYPE_PORT) --bind 127.0.0.1 --directory docs/sprint-1/prototype

migrate:
	$(PYTHON) backend/manage.py migrate

backend:
	$(PYTHON) backend/manage.py runserver 0.0.0.0:8000

mobile:
	cd mobile && $(FLUTTER) run -d chrome --web-port=8080 --dart-define=ALLOW_HTTP=true

check: check-backend check-mobile

check-backend:
	$(PYTHON) backend/manage.py check
	$(PYTHON) backend/manage.py makemigrations --check --dry-run

check-mobile:
	cd mobile && $(DART) format --output=none --set-exit-if-changed lib test
	cd mobile && $(FLUTTER) analyze

test: test-backend test-mobile

test-backend:
	$(PYTHON) -m pytest -q

test-mobile:
	cd mobile && $(FLUTTER) test
