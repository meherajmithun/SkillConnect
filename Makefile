PYTHON ?= python
FLUTTER ?= flutter
DART ?= dart

.PHONY: help migrate backend mobile check check-backend check-mobile test test-backend test-mobile

help:
	@echo "migrate        Apply database migrations"
	@echo "backend        Run Django on port 8000"
	@echo "mobile         Run Flutter web on port 8080"
	@echo "check          Check Django, migrations and Flutter"
	@echo "test           Run backend and Flutter tests"
	@echo "Use check-backend, check-mobile, test-backend or test-mobile separately."

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
