.DEFAULT_GOAL := dev
.PHONY: deps setup build_docker up_docker dev push_production pull_production help

GULP  := $(PWD)/node_modules/.bin/gulp
WPCLI := $(PWD)/dwp

THEME_NAME := new-website
THEME_DIR  := app/wp-content/themes/$(THEME_NAME)

deps: node_modules $(THEME_DIR)/vendor ## Install/Update dependencies

node_modules: package.json yarn.lock
	@yarn install
	touch $@

app/index.php:
	@$(WPCLI) core download --locale=fr_FR --version=4.9.7

app/wp-config.php:
	@$(WPCLI) core config --dbname=wordpress --dbuser=root --dbpass=password --dbhost=mysqldb --locale=fr_FR 
	@$(WPCLI) core install --url=localhost:3010 --title=Website --admin_user=admin --admin_password=password --admin_email=admin@new-website.com --skip-email

$(THEME_DIR)/vendor: $(THEME_DIR)/composer.json $(THEME_DIR)/composer.lock
	@cd $(THEME_DIR); composer install

setup: up_docker deps app/index.php app/wp-config.php ## Setup everything required to work on this WordPress installation
	@$(WPCLI) theme activate new-website
	@$(WPCLI) menu create "navbar"
	@$(WPCLI) menu item add-post navbar 2
	@$(WPCLI) menu create "navbar_footer"
	@$(WPCLI) menu item add-post navbar_footer 2

build_docker: Dockerfile docker-compose.yml
	@sudo HOST_UID=$(shell id -u) HOST_USER=$(shell whoami) docker-compose build

up_docker: build_docker ## Run WordPress on localhost:3010 and phpMyAdmin on localhost:3011
	@HOST_UID=$(shell id -u) HOST_USER=$(shell whoami) docker-compose up -d

dev: deps up_docker ## Run WordPress on localhost:3000 with livereload
	@$(GULP) --continue

build_assets: 
	@NODE_ENV=production $(GULP)

push_production: build_assets ## Push theme, plugins and languages from local to new-website.com 
	@wordmove push -t -p -l -e production

pull_production: ## Pull everything from new-website.com to local except the theme
	@wordmove pull --all --no-themes -e production

help: ## Print this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
