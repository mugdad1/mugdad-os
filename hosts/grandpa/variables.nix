{
  username = "mugdad";
  timezone = "Asia/Riyadh";
  locale = "en_US.UTF-8";

  gitUser = "mugdad1";
  gitEmail = "mugdad02@tutamail.com";

  # No browser/terminal/launcher on purpose: this host is headless.
  # modules/core/user.nix imports only modules/home/apps/git.nix here, so the
  # git identity and aliases apply without pulling in the desktop home stack.
}
