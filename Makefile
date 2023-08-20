default:
		@echo "Check Makefile for tasks"

check:
		bundle exec rubocop --parallel
		bundle exec rake spec
