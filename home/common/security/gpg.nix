{
  config,
  pkgs,
  private,
  ...
}:
{
  age.secrets = {
    "341C34CD6BED86F0FFC045609BFB331DE0590F01.key.age" = {
      file = "${private}/home/common/security/resources/gpg/private-keys-v1.d/341C34CD6BED86F0FFC045609BFB331DE0590F01.key.age";
      path = "${config.home.homeDirectory}/.gnupg/private-keys-v1.d/341C34CD6BED86F0FFC045609BFB331DE0590F01.key";
    };

    "C47C3D2E60A2BD8D72E025AD0DB9C0C6E8CA2F76.key.age" = {
      file = "${private}/home/common/security/resources/gpg/private-keys-v1.d/C47C3D2E60A2BD8D72E025AD0DB9C0C6E8CA2F76.key.age";
      path = "${config.home.homeDirectory}/.gnupg/private-keys-v1.d/C47C3D2E60A2BD8D72E025AD0DB9C0C6E8CA2F76.key";
    };

    "CB456C8ACD2B6E442EFAE57EE2BBC93F97B77037.key.age" = {
      file = "${private}/home/common/security/resources/gpg/private-keys-v1.d/CB456C8ACD2B6E442EFAE57EE2BBC93F97B77037.key.age";
      path = "${config.home.homeDirectory}/.gnupg/private-keys-v1.d/CB456C8ACD2B6E442EFAE57EE2BBC93F97B77037.key";
    };

    "D6D774C67E02990E2C1618D03CF448155C21B39B.key.age" = {
      file = "${private}/home/common/security/resources/gpg/private-keys-v1.d/D6D774C67E02990E2C1618D03CF448155C21B39B.key.age";
      path = "${config.home.homeDirectory}/.gnupg/private-keys-v1.d/D6D774C67E02990E2C1618D03CF448155C21B39B.key";
    };
  };

  programs.gpg = {
    enable = true;
    mutableKeys = false;
    mutableTrust = false;
  };

  home.packages = with pkgs; [
    gpgme
  ];
}
