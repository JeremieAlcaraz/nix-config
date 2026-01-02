{ config, pkgs, ... }:

{
  # === GEMINI CLI CONFIGURATION ===
  # Google's Gemini AI assistant for the terminal
  # Documentation: https://geminicli.com/docs/get-started/configuration/

  # Installation via npm (plus simple et toujours à jour)
  # Alternative 1: Utiliser le package binaire pré-compilé (actuellement v0.22.4 dans nixpkgs)
  # home.packages = with pkgs; [ unstable.gemini-cli-bin ];

  # Alternative 2: Installer directement via npm pour avoir la dernière version
  # Cette approche évite les problèmes de compilation et permet des mises à jour faciles
  home.packages = with pkgs; [
    (pkgs.writeShellScriptBin "gemini" ''
      # Utilise npx pour toujours avoir la dernière version nightly
      exec ${pkgs.nodejs}/bin/npx --yes @google/gemini-cli@nightly "$@"
    '')
  ];

  # === AUTHENTIFICATION ===
  # gemini-cli supporte deux méthodes d'authentification :
  #
  # 1. Login Google (Recommandé - AUCUNE CONFIG REQUISE)
  #    - Au premier lancement : `gemini` ouvre votre navigateur
  #    - Connectez-vous avec votre compte Google
  #    - Credentials cachés localement (keychain macOS)
  #    - Quota gratuit : 60 req/min, 1000 req/jour
  #    - Accès à Gemini 2.5 Pro (1M tokens contexte)
  #
  # 2. API Key (Optionnel - pour scripts/automation)
  #    - Si vous préférez utiliser une API key :
  #    a. Obtenez votre clé : https://aistudio.google.com/app/apikey
  #    b. Ajoutez à 1Password : op://Personal/gemini-api-key/credential
  #    c. Chiffrez avec SOPS : sops secrets/marigold.yaml
  #    d. Décommentez les lignes ci-dessous :
  #
  # sops.secrets.gemini_api_key = {
  #   sopsFile = ../secrets/marigold.yaml;
  # };
  #
  # home.sessionVariables = {
  #   GEMINI_API_KEY = "$(cat ${config.sops.secrets.gemini_api_key.path})";
  # };

  # Par défaut, utilisez simplement le login Google (aucune config nécessaire !)

  # === CONFIGURATION OPTIONNELLE ===
  # Pour personnaliser le modèle par défaut, utilisez :
  # home.sessionVariables = {
  #   GEMINI_MODEL = "gemini-2.5-flash";  # ou "gemini-2.5-pro", "auto"
  # };
}
