{
  description = "Mind Palace — cold data storage, labeling, and retrieval system with OAuth2 support.";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
	let
	pkgs = import nixpkgs {
	inherit system;
	config.allowUnfree = true;
	};
	authentikInfra = import ./infra/authentik.nix { inherit pkgs; };
	yamlFormat = pkgs.formats.yaml {};
	processComposeConfig = yamlFormat.generate "process-compose.yaml" {
	  version = "0.5";
	  processes = authentikInfra.processes;
	};
	infraShell = import ./shells/infra.nix { inherit pkgs processComposeConfig; };
	devShellNix = import ./shells/dev.nix { inherit pkgs infraShell; };
	in
	{
	devShells = rec {
	  infra   = infraShell;
	  dev     = devShellNix;
	  default = dev;
	};
	}
  );
}
