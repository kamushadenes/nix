{ pkgs, ... }:
let
  inherit (pkgs) fetchFromGitHub;
in
{
  autopair = {
    name = "autopair.fish";
    src = fetchFromGitHub {
      owner = "jorgebucaran";
      repo = "autopair.fish";
      rev = "4d1752ff5b39819ab58d7337c69220342e9de0e2";
      hash = "sha256-qt3t1iKRRNuiLWiVoiAYOu+9E7jsyECyIqZJ/oRIT1A=";
    };
  };
  done = {
    name = "done";
    src = fetchFromGitHub {
      owner = "franciscolourenco";
      repo = "done";
      rev = "eb32ade85c0f2c68cbfcff3036756bbf27a4f366";
      hash = "sha256-DMIRKRAVOn7YEnuAtz4hIxrU93ULxNoQhW6juxCoh4o=";
    };
  };
  evalcache = {
    name = "fish-evalcache";
    src = fetchFromGitHub {
      owner = "kamushadenes";
      repo = "fish-evalcache";
      rev = "5b84bf49524c8adc37cc52d1bb7aaeb687d09c3d";
      hash = "sha256-zrkTX1FP9biysaUnhcChCTDQ6wP5z7jV2vzVA0k5VdM=";
    };
  };
  fish-async-prompt = {
    name = "fish-async-prompt";
    src = fetchFromGitHub {
      owner = "acomagu";
      repo = "fish-async-prompt";
      rev = "316aa03c875b58e7c7f7d3bc9a78175aa47dbaa8";
      hash = "sha256-J7y3BjqwuEH4zDQe4cWylLn+Vn2Q5pv0XwOSPwhw/Z0=";
    };
  };
  puffer-fish = {
    name = "puffer-fish";
    src = fetchFromGitHub {
      owner = "nickeb96";
      repo = "puffer-fish";
      rev = "12d062eae0ad24f4ec20593be845ac30cd4b5923";
      hash = "sha256-2niYj0NLfmVIQguuGTA7RrPIcorJEPkxhH6Dhcy+6Bk=";
    };
  };
  safe-rm = {
    name = "safe-rm";
    src = fetchFromGitHub {
      owner = "fishingline";
      repo = "safe-rm";
      rev = "4c65dc566dd0fd6a9c59e959f1b40ce66cc6bfd3";
      hash = "sha256-BqLfvm4oADP9oPNkOCatyNfZ3RGqAtldiqeeORIo3Bc=";
    };
  };
  spark = {
    name = "spark.fish";
    src = fetchFromGitHub {
      owner = "jorgebucaran";
      repo = "spark.fish";
      rev = "90a60573ec8a8ecb741a861e0bfca2362f297e5f";
      hash = "sha256-cRSZeqtXSaEKuHeTSk3Kpmwf98mKJ986x1KSxa/HggU=";
    };
  };
  fish_ssh_agent = {
    name = "fish_ssh_agent";
    src = fetchFromGitHub {
      owner = "ivakyb";
      repo = "fish_ssh_agent";
      rev = "c7aa080d5210f5f525d078df6fdeedfba8db7f9b";
      hash = "sha256-v9VZY5DCo+iWZawRKVgFvsi33UKwtriSpUzrMhL0S14=";
    };
  };
}
