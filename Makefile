NPM ?= npm
NODE ?= node
FLUTTER ?= flutter
DART ?= dart
PROTOTYPE_PORT ?= 8082

.PHONY: help install install-backend install-mobile doctor seed prototype migrate backend mobile check check-backend check-mobile test test-backend test-mobile

help:
	@echo "install        Install Node.js and Flutter dependencies"
	@echo "doctor         Check local development prerequisites"
	@echo "seed           Seed examples (requires DEMO_PASSWORD)"
	@echo "prototype      Planning prototype on port $(PROTOTYPE_PORT)"
	@echo "migrate        Initialize the JavaScript database schema"
	@echo "backend        Run Node.js API on port 8000"
	@echo "mobile         Run Flutter web on port 8080"
	@echo "check          Check JavaScript and Flutter"
	@echo "test           Run backend and Flutter tests"

install: install-backend install-mobile

install-backend:
	$(NPM) ci

install-mobile:
	cd mobile && $(FLUTTER) pub get

doctor:
	$(NODE) scripts/dev-doctor.js

seed:
	$(NPM) run seed

prototype:
	PROTOTYPE_PORT=$(PROTOTYPE_PORT) $(NODE) scripts/prototype-server.js

migrate:
	$(NPM) run migrate

backend:
	$(NPM) run dev

mobile:
	cd mobile && $(FLUTTER) run -d chrome --web-port=8080 --dart-define=ALLOW_HTTP=true

check: check-backend check-mobile

check-backend:
	$(NPM) run check

check-mobile:
	cd mobile && $(DART) format --output=none --set-exit-if-changed lib test
	cd mobile && $(FLUTTER) analyze

test: test-backend test-mobile

test-backend:
	$(NPM) test

test-mobile:
	cd mobile && $(FLUTTER) test
