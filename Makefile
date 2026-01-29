.PHONY: test lint format install-hooks

# Run all tests
test:
	bats tests/

# Run shellcheck and shfmt check
lint:
	shellcheck gbeads
	shfmt -d -i 2 -ci gbeads

# Format gbeads script in place
format:
	shfmt -w -i 2 -ci gbeads

# Install pre-commit hooks
install-hooks:
	pre-commit install
