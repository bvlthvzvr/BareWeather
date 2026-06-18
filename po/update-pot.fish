#!/usr/bin/env fish
# Regenerate po/weather.pot from all i18n() strings in the QML.
# Run from the plasmoid root:  ./po/update-pot.fish
cd (dirname (status filename))/..
xgettext --from-code=UTF-8 --language=JavaScript \
  --keyword=i18n:1 --keyword=i18nc:1c,2 --keyword=i18np:1,2 --keyword=i18ncp:1c,2,3 \
  --package-name="org.bvlthvzvr.weather" \
  -o po/weather.pot (find contents -name '*.qml')
echo "Updated po/weather.pot ("(grep -c '^msgid ' po/weather.pot)" strings)"
