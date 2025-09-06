#!/bin/bash

cd /home/site/wwwroot

cp deployment/default /etc/nginx/sites-enabled/default
service nginx restart

for site in default jeannebriggs.com rss.tomboone.com; do
  vendor/bin/drush deploy --uri=$site
done
