#!/usr/bin/env fish
# Regenerate po/weather.pot from all i18n() strings in the QML.
# Run from the plasmoid root:  ./po/update-pot.fish
cd (dirname (status filename))/..
xgettext --from-code=UTF-8 --language=JavaScript \
  --keyword=i18n:1 --keyword=i18nc:1c,2 --keyword=i18np:1,2 --keyword=i18ncp:1c,2,3 \
  --package-name="org.bvlthvzvr.weather" \
  --msgid-bugs-address="https://github.com/bvlthvzvr/BareWeather/issues" \
  -o po/weather.pot (find contents -name '*.qml')

# xgettext rewrites the top comment block ("# SOME DESCRIPTIVE TITLE...") every run,
# so re-inject the translator how-to here. Keep everything from the header entry
# (msgid "") onward; replace only the leading comment lines above it.
set -l tmp (mktemp)
sed -n '/^msgid ""/,$p' po/weather.pot > $tmp
begin
    printf '%s\n' \
        "# Bare Weather — KDE Plasma weather widget." \
        "# Translation template, under the same MIT license as the widget." \
        "#" \
        "# ==========================================================================" \
        "# HOW TO ADD A TRANSLATION (no coding required):" \
        "#   1. Change the file name to <lang>.po  — e.g. es.po (Spanish), fr.po (French)." \
        "#   2. Open it in a PO editor (Lokalize, Poedit) or any text editor." \
        "#   3. For each entry, put your translation inside the empty msgstr \"\":" \
        "#        msgid  = original English — DO NOT edit it" \
        "#        msgstr = your translation goes here" \
        "#   4. Send it back (pull request or issue) — it ships in the next release." \
        "#" \
        "# NOTES:" \
        "#   - Placeholders like %1, %2 must also appear in your translation." \
        "#   - Lines starting with '#.' are hints, '#:' are source locations — ignore both." \
        "# ==========================================================================" \
        "#, fuzzy"
    cat $tmp
end > po/weather.pot
rm $tmp

echo "Updated po/weather.pot ("(grep -c '^msgid ' po/weather.pot)" strings)"
