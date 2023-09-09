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
				nixosModules.obsidian-sync-server = {config, pkgs, lib, cfg, ...}: {
					options.services.obsidian-sync.server = {
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

							name = lib.mkOption {
								default = "localhost";
							};

							port = lib.mkOption {
								default = "3000";
							};

							socketAddr = lib.mkOption {
								readOnly = true;
							};

							url = lib.mkOption {
								readOnly = true;
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

					config = let cfg = config.services.obsidian-sync.server; in lib.mkIf cfg.enable {
						services.obsidian-sync.server.host.socketAddr = "${cfg.host.name}:${cfg.host.port}";
						services.obsidian-sync.server.host.url = let
								protocol = if cfg.host.https then "https" else "http" ;
							in "${protocol}://${cfg.host.socketAddr}";

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
							environment = lib.mkMerge [
								{
									DATA_DIR = cfg.dataDir;
									ADDR_HTTP = cfg.listenAddress;
									DOMAIN_NAME = cfg.host.url;
								}
								(lib.mkIf (cfg.signupKey != null) {
									SIGNUP_KEY = cfg.signupKey;
								})
							];

							script = "${cfg.package}/bin/${cfg.package.meta.mainProgram}";
						};
					};
				};

				# TODO, configure backups.

				nixosModules.obsidian-sync-nginx = {lib, config, ...}: let
					cfg = config.services.obsidian-sync;
				in {
					options.services.obsidian-sync.nginx = {
						enable = lib.mkEnableOption "obsidian-sync nginx frontend";
						publish.enable = lib.mkEnableOption "obsidian-sync publish nginx frontend";

						extraConfig = lib.mkOption {
							default = {};
						};
						forceSSL = lib.mkOption {
							default = config.services.obsidian-sync.server.host.https;
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
										proxyPass = "http://${cfg.server.host.socketAddr}";
										proxyWebsockets = true;
									};
								}
							];
						})
					];
				};

				nixosModules.vm = {...}: {
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
				};

				nixosConfigurations.obsidian-sync-server = inputs.nixpkgs.lib.nixosSystem {
					system = "aarch64-linux";
					modules = [
						inputs.self.nixosModules.obsidian-sync-server
						inputs.self.nixosModules.obsidian-sync-nginx
						inputs.self.nixosModules.vm

						{ virtualisation.vmVariant.virtualisation.host.pkgs = inputs.nixpkgs.legacyPackages.aarch64-darwin; }
						{
							services.obsidian-sync.server.enable = true;
							services.nginx.enable = true;
						}
					];
				};

				packages.aarch64-darwin.darwinVM = inputs.self.nixosConfigurations.obsidian-sync-server.config.system.build.vm;
			};
		};
}
