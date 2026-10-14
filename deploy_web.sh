#!/bin/bash
set -e

# Configuration
SERVER="archerwoods13@34.174.220.100"
DOMAIN="bybl.dev"
WWW_DOMAIN="www.bybl.dev"
WEB_DIR="/var/www/$DOMAIN"
FRONTEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/Frontend" && pwd)"

echo "Step 1: Building Flutter web app..."
cd "$FRONTEND_DIR"
flutter build web --release

echo "Step 2: Transferring files to a temporary location on the server..."
# Using rsync to transfer to /tmp first because we might not have write access to /var/www directly
rsync -avz --delete build/web/ "$SERVER:/tmp/bybl_web_build/"

echo "Step 3: Setting up the server and Nginx..."
# We use SSH to execute the remote setup commands
ssh -t "$SERVER" "
  set -e
  
  echo 'Creating web root directory...'
  sudo mkdir -p $WEB_DIR
  
  echo 'Copying files to web root...'
  sudo rsync -avz --delete /tmp/bybl_web_build/ $WEB_DIR/
  sudo chown -R www-data:www-data $WEB_DIR
  sudo chmod -R 755 $WEB_DIR

  echo 'Cleaning up temporary files...'
  rm -rf /tmp/bybl_web_build
"

echo ""
echo "✅ Deployment successful!"
echo "Next steps:"
echo "Run certbot on your server to set up SSL by executing:"
echo "ssh $SERVER 'sudo certbot --nginx -d $DOMAIN -d $WWW_DOMAIN'"
