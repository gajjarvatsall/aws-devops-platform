SHELL := /bin/bash
TERRAFORM_DIRS := environments/staging bootstrap/backend
TERRAFORM_MODULE_DIRS := $(wildcard modules/*)

.PHONY: test lint docker-build terraform-fmt terraform-validate security-scan check
test:
	python3 -m pytest app/tests
lint:
	python3 -m ruff check app
docker-build:
	docker build -t cloudops-demo:local ./app
terraform-fmt:
	terraform fmt -check -recursive
terraform-validate:
	@for dir in $(TERRAFORM_DIRS); do \
		echo "Validating $$dir"; \
		terraform -chdir=$$dir init -backend=false -input=false; \
		terraform -chdir=$$dir validate; \
	done
	@for dir in $(TERRAFORM_MODULE_DIRS); do \
		echo "Validating $$dir"; \
		terraform -chdir=$$dir init -backend=false -input=false; \
		terraform -chdir=$$dir validate; \
	done
security-scan:
	checkov -d . --framework terraform --quiet
check: test lint terraform-fmt terraform-validate
