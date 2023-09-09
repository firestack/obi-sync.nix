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

					meta.mainProgram = "obsidian-sync";
				};
			};

			flake = {
				nixosModules.obsidian-sync-server = {config, pkgs, lib, cfg, ...}: let
					cfg = config.services.obsidian-sync.server;
				in {
					options.services.obsidian-sync.server = {
						enable = lib.mkEnableOption "obsidian-sync server";

						package = lib.mkOption {
							default = inputs.self.packages.${pkgs.system}.obi-sync;
						};

						dataDir = lib.mkOption {
							default = "/var/lib/obsidian-sync/";
						};

						maxStorageGB = lib.mkOption { default = null; };

						maxSitesPerUser = lib.mkOption { default = null; };

						host = {
							protocol = lib.mkOption {
								default = "http";
							};

							# https = lib.mkEnableOption "https protocol";

							name = lib.mkOption {
								default = cfg.listen.host;
							};

							port = lib.mkOption {
								default = cfg.listen.port;
							};

							url = lib.mkOption {
								default = let
									# protocol = if cfg.host.https then "https" else "http";
									portString = if cfg.host.port != null
										then ":${toString cfg.host.port}"
										else "";
								in "${cfg.host.protocol}://${cfg.host.name}${portString}";
								# in "${protocol}://${cfg.host.name}${portString}";
								readOnly = true;
							};
						};

						listen = {
							protocol = lib.mkOption { default = "http"; };
							host = lib.mkOption { default = "127.0.0.1"; };
							port = lib.mkOption { default = 3000; };

							socketAddr = lib.mkOption {
								default = "${cfg.listen.host}:${toString cfg.listen.port}";
								readOnly = true;
							};

							url = lib.mkOption {
								default = "${cfg.listen.protocol}://${cfg.listen.socketAddr}";
							};
						};

						signupKey = lib.mkOption {
							default = null;
							description = "Signup API is at /user/signup. This optionally restricts users who can sign up.";
						};
					};

					config = lib.mkIf cfg.enable {
						users.groups.obsidian-sync = {};
						users.users.obsidian-sync = {
							isSystemUser = true;

							createHome = true;
							home = "/var/lib/obsidian-sync";

							group = "obsidian-sync";

							# Add `signup` tool to PATH for the user
							packages = [ cfg.package ];
						};


						systemd.services."obsidian-sync-server" = {
							wantedBy = [ "default.target" ];
							serviceConfig = {
								User = "obsidian-sync";
							};

							environment = {
								DATA_DIR = cfg.dataDir;
								DOMAIN_NAME = cfg.host.url;
								ADDR_HTTP = cfg.listen.socketAddr;
								MAX_STORAGE_GB = cfg.maxStorageGB;
								MAX_SITES_PER_USER = cfg.maxSitesPerUser;
								SIGNUP_KEY = cfg.signupKey;
							};

							script = "${cfg.package}/bin/${cfg.package.meta.mainProgram}";
						};
					};
				};

				nixosModules.obsidian-sync-nginx = {lib, config, ...}: let
					cfg = config.services.obsidian-sync;
				in {
					options.services.obsidian-sync.nginx = {
						enable = lib.mkEnableOption "obsidian-sync nginx frontend";

						# publish.enable = lib.mkEnableOption "obsidian-sync publish nginx frontend";

						extraConfig = lib.mkOption {
							default = {};
						};

						forceSSL = lib.mkOption {
							default = config.services.obsidian-sync.server.host.protocol == "https";
						};
					};

					config = lib.mkMerge [
						{ services.obsidian-sync.nginx.enable = lib.mkDefault config.services.nginx.enable; }
						(lib.mkIf cfg.nginx.enable {
							services.nginx.virtualHosts.${cfg.server.host.name} = lib.mkMerge [
								cfg.nginx.extraConfig
								{
									forceSSL = cfg.nginx.forceSSL;
									locations."/" = {
										proxyPass = cfg.server.listen.url;
										proxyWebsockets = true;
									};
								}
							];
						})
					];
				};

				# TODO, configure backups.

				nixosConfigurations.obsidian-sync-server = inputs.nixpkgs.lib.nixosSystem {
					system = "aarch64-linux";
					modules = [
						inputs.self.nixosModules.obsidian-sync-server
						inputs.self.nixosModules.obsidian-sync-nginx
						{
							services.obsidian-sync.server.enable = true;
							services.nginx.enable = true;
						}

						# VM Configuration
						{
							system.stateVersion = "22.05";

							# Configure networking
							networking.useDHCP = false;
							networking.interfaces.eth0.useDHCP = true;

							# Create user "test"
							services.getty.autologinUser = "test";
							users.users.test.isNormalUser = true;

							# Enable passwordless ‘sudo’ for the "test" user
							users.users.test.extraGroups = ["wheel"];
							security.sudo.wheelNeedsPassword = false;

							# Second Module

							# Make VM output to the terminal instead of a separate window
							virtualisation.vmVariant.virtualisation.graphics = false;
						}
						{ virtualisation.vmVariant.virtualisation.host.pkgs = inputs.nixpkgs.legacyPackages.aarch64-darwin; }

					];
				};

				packages.aarch64-darwin.darwinVM = inputs.self.nixosConfigurations.obsidian-sync-server.config.system.build.vm;
			};
		};
}
