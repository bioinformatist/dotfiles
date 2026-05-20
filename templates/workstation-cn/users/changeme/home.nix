{ ... }:
{
  programs.git = {
    enable = true;
    signing.format = "openpgp";
    settings = {
      user.name = "REPLACE_ME";
      user.email = "REPLACE_ME@example.com";
    };
  };
}
