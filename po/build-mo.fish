#!/usr/bin/env fish
# Compile every po/<lang>.po into the package's locale tree as
# contents/locale/<lang>/LC_MESSAGES/plasma_applet_org.bvlthvzvr.weather.mo
cd (dirname (status filename))/..
set domain plasma_applet_org.bvlthvzvr.weather
for po in po/*.po
    set lang (basename $po .po)
    set dir contents/locale/$lang/LC_MESSAGES
    mkdir -p $dir
    msgfmt $po -o $dir/$domain.mo
    echo "built $lang"
end
