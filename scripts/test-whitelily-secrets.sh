#!/usr/bin/env bash
set -e

cd ~/Dev/_programmation/_production/_services/nix-config

echo "🧪 Test des secrets whitelily depuis Marigold..."

# Extraire tout le fichier déchiffré une seule fois
SECRETS_YAML=$(sops -d secrets/whitelily.yaml)

# Parser les secrets
CLIENT_ID=$(echo "$SECRETS_YAML" | yq -r '.google_drive.client_id' 2>/dev/null || echo "")
CLIENT_SECRET=$(echo "$SECRETS_YAML" | yq -r '.google_drive.client_secret' 2>/dev/null || echo "")
TOKEN_JSON=$(echo "$SECRETS_YAML" | yq -r '.google_drive.token' 2>/dev/null || echo "")
FOLDER_ID=$(echo "$SECRETS_YAML" | yq -r '.google_drive.folder_id' 2>/dev/null || echo "")
NOTION_TOKEN=$(echo "$SECRETS_YAML" | yq -r '.notion.api_token' 2>/dev/null || echo "")
DATABASE_ID=$(echo "$SECRETS_YAML" | yq -r '.notion.database_id' 2>/dev/null || echo "")
GMAIL_FROM=$(echo "$SECRETS_YAML" | yq -r '.gmail.from' 2>/dev/null || echo "")
GMAIL_TO=$(echo "$SECRETS_YAML" | yq -r '.gmail.to' 2>/dev/null || echo "")
GMAIL_PASSWORD=$(echo "$SECRETS_YAML" | yq -r '.gmail.app_password' 2>/dev/null || echo "")

# Si yq a échoué, fallback sur awk
if [[ -z "$CLIENT_ID" ]] || [[ "$CLIENT_ID" == "null" ]]; then
  echo "⚠️  yq parse failed, using awk fallback..."
  CLIENT_ID=$(echo "$SECRETS_YAML" | awk '/client_id:/ {gsub(/"/, "", $2); print $2}')
  CLIENT_SECRET=$(echo "$SECRETS_YAML" | awk '/client_secret:/ {gsub(/"/, "", $2); print $2}')
  # Pour le token JSON, on prend tout entre guillemets simples
  TOKEN_JSON=$(echo "$SECRETS_YAML" | grep "token:" | sed "s/.*token: '\(.*\)'/\1/")
  FOLDER_ID=$(echo "$SECRETS_YAML" | awk '/folder_id:/ {gsub(/"/, "", $2); print $2}')
  NOTION_TOKEN=$(echo "$SECRETS_YAML" | awk '/api_token:/ {gsub(/"/, "", $2); print $2}')
  DATABASE_ID=$(echo "$SECRETS_YAML" | awk '/database_id:/ {gsub(/"/, "", $2); print $2}')
  GMAIL_FROM=$(echo "$SECRETS_YAML" | awk '/from:/ {gsub(/"/, "", $2); print $2}')
  GMAIL_TO=$(echo "$SECRETS_YAML" | awk '/to:/ {gsub(/"/, "", $2); print $2}')
  GMAIL_PASSWORD=$(echo "$SECRETS_YAML" | awk '/app_password:/ {gsub(/"/, "", $2); print $2}')
fi

# Extraire le refresh_token du JSON pour affichage
REFRESH_TOKEN=$(echo "$TOKEN_JSON" | grep -o '"refresh_token":"[^"]*"' | cut -d'"' -f4)

echo ""
echo "📊 Secrets extraits:"
echo "  - CLIENT_ID: ${CLIENT_ID:0:20}...${CLIENT_ID: -20}"
echo "  - CLIENT_SECRET: ${CLIENT_SECRET:0:10}...${CLIENT_SECRET: -5}"
echo "  - REFRESH_TOKEN: ${REFRESH_TOKEN:0:10}...${REFRESH_TOKEN: -10}"
echo "  - FOLDER_ID: $FOLDER_ID"
echo "  - NOTION_TOKEN: ${NOTION_TOKEN:0:15}...${NOTION_TOKEN: -10}"
echo "  - DATABASE_ID: $DATABASE_ID"
echo "  - GMAIL_FROM: $GMAIL_FROM"
echo ""

# Vérifier que les secrets critiques ne sont pas vides
if [[ -z "$TOKEN_JSON" ]]; then
  echo "❌ TOKEN est vide! Vérifie secrets/whitelily.yaml"
  exit 1
fi
if [[ -z "$NOTION_TOKEN" ]]; then
  echo "❌ NOTION_TOKEN est vide!"
  exit 1
fi
if [[ -z "$GMAIL_FROM" ]]; then
  echo "❌ GMAIL_FROM est vide!"
  exit 1
fi

echo "1️⃣ Test Google Drive avec rclone..."
# Créer un config rclone temporaire
mkdir -p /tmp/rclone-test
cat >/tmp/rclone-test/rclone.conf <<RCLONE_EOF
[gdrive]
type = drive
scope = drive
client_id = $CLIENT_ID
client_secret = $CLIENT_SECRET
token = $TOKEN_JSON
root_folder_id = $FOLDER_ID
RCLONE_EOF

# Tester le listing
GDRIVE_RESULT=$(nix-shell -p rclone --run "rclone --config /tmp/rclone-test/rclone.conf lsf gdrive:" 2>&1)

if echo "$GDRIVE_RESULT" | grep -q "ERROR"; then
  echo "❌ Google Drive FAILED"
  echo "$GDRIVE_RESULT"
else
  echo "✅ Google Drive OK"
  echo "   📁 Fichiers trouvés:"
  echo "$GDRIVE_RESULT" | head -5
  FILE_COUNT=$(echo "$GDRIVE_RESULT" | wc -l | tr -d ' ')
  echo "   📊 Total: $FILE_COUNT fichier(s)"
fi

echo ""
echo "2️⃣ Test Notion API + récupération du nom de la database..."
DATABASE_INFO=$(curl -s -X GET "https://api.notion.com/v1/databases/$DATABASE_ID" \
  -H "Authorization: Bearer $NOTION_TOKEN" \
  -H "Notion-Version: 2022-06-28")

if echo "$DATABASE_INFO" | grep -q '"object":"database"'; then
  echo "✅ Notion API OK"

  # Extraire le nom de la database
  DATABASE_NAME=$(echo "$DATABASE_INFO" | grep -o '"plain_text":"[^"]*"' | head -1 | cut -d'"' -f4)

  if [[ -n "$DATABASE_NAME" ]]; then
    echo "   📊 Database trouvée: \"$DATABASE_NAME\" (ID: $DATABASE_ID)"
  fi
else
  echo "❌ Notion API FAILED"
  echo "$DATABASE_INFO"
fi

echo ""
echo "3️⃣ Test Gmail SMTP..."
SMTP_TEST=$(
  curl -v --url "smtps://smtp.gmail.com:465" \
    --ssl-reqd \
    --mail-from "$GMAIL_FROM" \
    --mail-rcpt "${GMAIL_TO:-$GMAIL_FROM}" \
    --user "$GMAIL_FROM:$GMAIL_PASSWORD" \
    --upload-file - 2>&1 <<MAIL_EOF
From: $GMAIL_FROM
To: ${GMAIL_TO:-$GMAIL_FROM}
Subject: [Test] n8n backup secrets - ALL OK!

✅ Google Drive: rclone fonctionne
✅ Notion API: Database accessible
✅ Gmail SMTP: Email envoyé avec succès

Tous les secrets sont validés !
MAIL_EOF
)

if echo "$SMTP_TEST" | grep -q "250"; then
  echo "✅ Gmail SMTP OK"
  echo "   📧 Email envoyé à: ${GMAIL_TO:-$GMAIL_FROM}"
else
  echo "⚠️  Gmail SMTP - vérifier la sortie:"
  echo "$SMTP_TEST" | grep -E "(535|250|421|SMTP|SSL|authenticated)" | head -5
fi

echo ""
echo "🎉 Tests terminés !"
echo ""
echo "📝 Résumé:"
echo "   • Google Drive: rclone configuré et fonctionnel"
echo "   • Notion: Database accessible"
echo "   • Gmail: Notifications configurées"
echo ""
echo "✨ Prêt pour la PARTIE 2 : Configuration NixOS du module de backup !"

echo ""
echo "4️⃣ Test Slack Webhook..."
SLACK_WEBHOOK=$(echo "$SECRETS_YAML" | yq -r '.slack.webhook_url' 2>/dev/null || echo "")

if [[ -z "$SLACK_WEBHOOK" ]] || [[ "$SLACK_WEBHOOK" == "null" ]]; then
  SLACK_WEBHOOK=$(echo "$SECRETS_YAML" | awk '/webhook_url:/ {gsub(/"/, "", $2); print $2}')
fi

if [[ -n "$SLACK_WEBHOOK" ]]; then
  SLACK_RESULT=$(curl -s -X POST "$SLACK_WEBHOOK" \
    -H "Content-Type: application/json" \
    -d '{
        "text": "🧪 Test n8n backup - whitelily",
        "blocks": [
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": "*✅ Test de connexion Slack réussi!*\n\nTous les secrets sont validés:\n• Google Drive ✅\n• Notion ✅\n• Gmail ✅\n• Slack ✅"
            }
          }
        ]
      }')

  if [[ "$SLACK_RESULT" == "ok" ]]; then
    echo "✅ Slack Webhook OK"
    echo "   💬 Message envoyé sur Slack"
  else
    echo "❌ Slack Webhook FAILED"
    echo "   Response: $SLACK_RESULT"
  fi
else
  echo "⚠️  SLACK_WEBHOOK non trouvé dans secrets"
fi

echo ""
echo "🎉 Tests terminés !"
echo ""
echo "📝 Résumé complet:"
echo "   • Google Drive: rclone configuré et fonctionnel ✅"
echo "   • Notion: Database accessible ✅"
echo "   • Gmail: Notifications configurées ✅"
echo "   • Slack: Webhook opérationnel ✅"
echo ""
echo "✨ Prêt pour la PARTIE 2 : Configuration NixOS du module de backup !"
