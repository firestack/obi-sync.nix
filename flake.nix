{
	description = "Description for the project";

	inputs = {
		nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

		flake-parts = {
			url = "github:hercules-ci/flake-parts";
			inputs.nixpkgs-lib.follows = "/nixpkgs";
		};

		obi-sync-src.follows = "/";
	};

	outputs = inputs@{ flake-parts, obi-sync-src, ... }:
		flake-parts.lib.mkFlake { inherit inputs; } {
			imports = [
				# To import a flake module
				# 1. Add foo to inputs
				# 2. Add foo as a parameter to the outputs function
				# 3. Add here: foo.flakeModule

			];
			systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
			perSystem = { config, self', inputs', pkgs, system, ... }: {
				# Per-system attributes can be defined here. The self' and inputs'
				# module parameters provide easy access to attributes of the same
				# system.

				# Equivalent to  inputs'.nixpkgs.legacyPackages.hello;
				packages.default = self'.packages.obi-sync;
				packages.obi-sync = pkgs.buildGoModule {
					pname = "obi-sync";
					version = "v0.1.3";

					src = obi-sync-src;

					vendorSha256 = "sha256-A/WQ9GCGiA9rncGI+zTy/iqmaXsOa4TIU7XS9r6wMnQ=";
				};
			};
			flake = {
				nixosModules.obi-sync-server = {config, pkgs, lib, cfg, ...}: {
					options.services.obsidian-sync = {
						enable = lib.mkEnableOption "obsidian-sync server";

						package = lib.mkOption {
							default = inputs.self.packages.${pkgs.system}.obi-sync;
						};

						dataDir = lib.mkOption {
							default = "/var/lib/obsidian-sync/";
						};

						host = {
							# The domain name or IP address of your server. Include port if not on 80 or 433. The default is localhost:3000
							https = lib.mkEnableOption "https protocol";

							host = lib.mkOption {
								default = "localhost";
							};
							port = lib.mkOption {
								default = "3000";
							};
						};

						listenAddress = lib.mkOption {
							default = "127.0.0.1:3000";
							description = "Server listener address. The default is 127.0.0.1:3000";
						};

						signupKey = lib.mkOption {
							default = null;
							description = "Signup API is at /user/signup. This optionally restricts users who can sign up.";
						};
					};

					config = let cfg = config.services.obsidian-sync; in lib.mkIf cfg.enable {
						users.users.obsidian-sync = {
							isSystemUser = true;
							group = "obsidian-sync";
							createHome = true;
							home = "/var/lib/obsidian-sync";
						};
						users.groups.obsidian-sync = {};

						systemd.services."obsidian-sync-server" = {
							wantedBy = [ "default.target" ];
							serviceConfig = {
								User = "obsidian-sync";
							};
							environment = lib.mkMerge [
								{
									DATA_DIR = cfg.dataDir;
									DOMAIN_NAME = let
											protocol = if cfg.host.https then "https" else "http" ;
										in "${protocol}://${cfg.host.host}:${cfg.host.port}"; # -

									ADDR_HTTP = cfg.listenAddress;
								}
								(lib.mkIf (cfg.signupKey != null) {
									SIGNUP_KEY = cfg.signupKey;
								})
							];

							script = "${cfg.package}/bin/obsidian-sync";
						};

						# TODO, configure backups.
					};
				};

			};
		};
}
