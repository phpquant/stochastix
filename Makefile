installer:
	@docker build -f build/installer/Dockerfile -t ghcr.io/phpquant/stochastix-installer .

app:
	@docker build -f build/app.Dockerfile -t ghcr.io/phpquant/stochastix --target frankenphp_dev .
