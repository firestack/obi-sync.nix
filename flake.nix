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
				# The usual flake attributes can be defined here, including system-
				# agnostic ones like nixosModule and system-enumerating ones, although
				# those are more easily expressed in perSystem.

			};
		};
}
