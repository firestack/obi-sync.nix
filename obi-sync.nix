{ src
, version
, vendorSha256

, buildGoModule
, ... }:

buildGoModule {
	pname = "obi-sync";
	# version = "v0.1.3";

	inherit version src vendorSha256;

	# vendorSha256 = "sha256-A/WQ9GCGiA9rncGI+zTy/iqmaXsOa4TIU7XS9r6wMnQ=";

	meta.mainProgram = "obsidian-sync";
}
