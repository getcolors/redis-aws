{ pkgs, ... }:
{
  languages.clojure.enable = true;
  languages.opentofu.enable = true;
  # redis for the workstation-side acceptance gate (redis-cli through the tunnel);
  # awscli2 for read-only checks against the account; bun and uv for ./red and ./blue.
  packages = with pkgs; [ ansible awscli2 babashka bun curl jq openssh openssl rclone redis uv ];
}
