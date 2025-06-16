#!/bin/sh
set -e

if [ "$1" = 'frankenphp' ] || [ "$1" = 'php' ] || [ "$1" = 'bin/console' ]; then
	# Install the project the first time PHP is started
	# After the installation, the following block can be deleted
	if [ ! -f composer.json ]; then
		rm -Rf tmp/
		composer create-project symfony/skeleton tmp --prefer-dist --no-progress --no-interaction --no-install

		cd tmp
		cp -Rp . ..
		cd -
		rm -Rf tmp/

		composer require "php:>=$PHP_VERSION" runtime/frankenphp-symfony
		composer config --json extra.symfony.docker 'true'
    	composer config --no-plugins allow-plugins.williarin/cook true
		composer config minimum-stability dev
		composer require stochastix/core
		composer require --dev symfony/maker-bundle

		sed -i '/###> doctrine\/doctrine-bundle ###/,/###< doctrine\/doctrine-bundle ###/d' compose.yaml
		sed -i '/###> symfony\/mercure-bundle ###/,/###< symfony\/mercure-bundle ###/d' compose.yaml
		sed -i '/###> doctrine\/doctrine-bundle ###/,/###< doctrine\/doctrine-bundle ###/d' compose.override.yaml
		sed -i '/###> symfony\/mercure-bundle ###/,/###< symfony\/mercure-bundle ###/d' compose.override.yaml
		sed -i '/###> doctrine\/doctrine-bundle ###/,/###< doctrine\/doctrine-bundle ###/d' .env
		sed -i '/###> symfony\/mercure-bundle ###/,/###< symfony\/mercure-bundle ###/d' .env

		if grep -q ^DATABASE_URL= .env; then
			exit 0
		fi
	fi

	if [ -z "$(ls -A 'vendor/' 2>/dev/null)" ]; then
		composer install --prefer-dist --no-progress --no-interaction
	fi

	# Display information about the current project
	# Or about an error in project initialization
	php bin/console -V

	if grep -q ^DATABASE_URL= .env; then
        DB_PATH="data/queue_dev.db"
        if [ ! -f "$DB_PATH" ]; then
            echo "Creating database at: $DB_PATH"
            php bin/console doctrine:database:create --no-interaction
            php bin/console make:migration --no-interaction
			php bin/console doctrine:migrations:migrate --no-interaction --all-or-nothing
        fi

		echo 'Waiting for database to be ready...'
		ATTEMPTS_LEFT_TO_REACH_DATABASE=60
		until [ $ATTEMPTS_LEFT_TO_REACH_DATABASE -eq 0 ] || DATABASE_ERROR=$(php bin/console dbal:run-sql -q "SELECT 1" 2>&1); do
			if [ $? -eq 255 ]; then
				# If the Doctrine command exits with 255, an unrecoverable error occurred
				ATTEMPTS_LEFT_TO_REACH_DATABASE=0
				break
			fi
			sleep 1
			ATTEMPTS_LEFT_TO_REACH_DATABASE=$((ATTEMPTS_LEFT_TO_REACH_DATABASE - 1))
			echo "Still waiting for database to be ready... Or maybe the database is not reachable. $ATTEMPTS_LEFT_TO_REACH_DATABASE attempts left."
		done

		if [ $ATTEMPTS_LEFT_TO_REACH_DATABASE -eq 0 ]; then
			echo 'The database is not up or not reachable:'
			echo "$DATABASE_ERROR"
			exit 1
		else
			echo 'The database is now ready and reachable'
		fi

		if [ "$( find ./migrations -iname '*.php' -print -quit )" ]; then
			php bin/console doctrine:migrations:migrate --no-interaction --all-or-nothing
		fi
	fi

	chown -R 1000:1000 .
	setfacl -R -m u:www-data:rwX -m u:"$(whoami)":rwX var
	setfacl -dR -m u:www-data:rwX -m u:"$(whoami)":rwX var

	echo 'PHP app ready!'
fi

exec docker-php-entrypoint "$@"
