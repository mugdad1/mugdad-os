{
  username = "mugdad";
  timezone = "Asia/Riyadh";
  locale = "en_US.UTF-8";

  gitUser = "mugdad1";
  gitEmail = "mugdad02@tutamail.com";

  # No browser/terminal/launcher on purpose: the desktop home stack needs them.
  # modules/core/user.nix imports only modules/home/apps/git.nix on headless
  # hosts, so git identity and aliases apply without a desktop.
}
