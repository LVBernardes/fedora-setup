#!/usr/bin/env bash
RED='\e[1;91m'
GREEN='\e[1;92m'
BLUE='\e[1;94m'
ORANGE='\e[1;93m'
NO_COLOR='\e[0m'



echo "-----------------------------------------------------------------------"
echo -e "${BLUE}FEDORA-SETUP: Configuring dconf settings.${NO_COLOR}"
echo ""

# This indexer is nice, but can be detrimental for laptop users battery life
sudo -E -u $user_selected bash <<EOC
gsettings set org.freedesktop.Tracker3.Miner.Files index-on-battery false
gsettings set org.freedesktop.Tracker3.Miner.Files index-on-battery-first-time false
gsettings set org.freedesktop.Tracker3.Miner.Files throttle 15
EOC

# Nautilus (File Manager) configuration
{

# gsettings set org.gnome.nautilus.window-state sidebar-width 250

sudo -E -u $user_selected bash <<EOC
gsettings set org.gnome.nautilus.preferences default-folder-viewer 'list-view'
gsettings set org.gnome.nautilus.window-state maximized true
gsettings set org.gnome.nautilus.icon-view default-zoom-level 'standard'
gsettings set org.gnome.nautilus.list-view use-tree-view true
gsettings set org.gnome.nautilus.list-view default-column-order "['name','size','type','detailed_type','owner','group','permissions','where','date_modified','date_created','date_modified_with_time','date_accessed','recency','starred']"
gsettings set org.gnome.nautilus.list-view default-visible-columns "['name','size','type','detailed_type','date_modified','date_created','starred']"
EOC

echo ""
echo "FEDORA-SETUP: Succesfully configured Nautilus (File Manager)."
echo ""

} || {

echo ""
echo "FEDORA-SETUP: Failed to configure Nautilus (File Manager)."
echo ""

}


# File Chooser configuration
{

sudo -E -u $user_selected bash <<EOC
gsettings set org.gtk.Settings.FileChooser sort-directories-first true
gsettings set org.gtk.Settings.FileChooser date-format 'with-time'
gsettings set org.gtk.Settings.FileChooser show-hidden true
gsettings set org.gtk.Settings.FileChooser type-format 'mime'
EOC

echo ""
echo "FEDORA-SETUP: Succesfully configured File Chooser."
echo ""

} || {

echo ""
echo "FEDORA-SETUP: Failed to configure File Chooser."
echo ""

}

# Usability Improvements in GNOME Desktop Interface (buttons, periphericals, etc)
{

sudo -E -u $user_selected bash <<EOC
gsettings set org.gnome.shell.extensions.user-theme name 'Flat-Remix-Blue-Dark-fullPanel'
gsettings set org.gnome.desktop.interface clock-show-weekday true
gsettings set org.gnome.desktop.interface clock-show-seconds true
gsettings set org.gnome.desktop.interface gtk-theme 'Flat-Remix-GTK-Blue-Dark-Solid'
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
gsettings set org.gnome.desktop.interface font-antialiasing 'rgba'
gsettings set org.gnome.desktop.interface font-name 'Noto Sans 11'
gsettings set org.gnome.desktop.interface document-font-name 'Noto Sans Medium 11'
gsettings set org.gnome.desktop.interface monospace-font-name 'Noto Sans Mono 10'
gsettings set org.gnome.desktop.sound allow-volume-above-100-percent true
gsettings set org.gnome.desktop.calendar show-weekdate true
gsettings set org.gnome.desktop.wm.preferences resize-with-right-button true
gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'
gsettings set org.gnome.desktop.wm.preferences titlebar-font 'Noto Sans Bold 11'
gsettings set org.gnome.desktop.peripherals.mouse accel-profile 'adaptive'
gsettings set org.gnome.desktop.peripherals.keyboard numlock-state true
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true
gsettings set org.gnome.desktop.peripherals.touchpad two-finger-scrolling-enabled true
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us+intl'), ('xkb', 'br')]"
gsettings set org.gnome.shell.weather locations "[<(uint32 2, <('São Paulo', 'SBMT', true, [(-0.41044326824509736, -0.8139052020289248)], [(-0.41073414481823473, -0.81361432545578749)])>)>]"
gsettings set org.gnome.GWeather temperature-unit 'centigrade'

EOC

echo ""
echo "FEDORA-SETUP: Succesfully configured Usability Improvements in GNOME Desktop Interface (buttons, periphericals, etc)."
echo ""

} || {

echo ""
echo "FEDORA-SETUP: Failed to configure Usability Improvements in GNOME Desktop Interface (buttons, periphericals, etc)."
echo ""

}




# Usability Improvements in GNOME Desktop Interface (behaviours, locale, hotkeys)
{

sudo -E -u $user_selected bash <<EOC
gsettings set org.gnome.shell.overrides workspaces-only-on-primary false
gsettings set org.gnome.system.locale region 'pt_BR.UTF-8'
gsettings set org.gnome.settings-daemon.plugins.media-keys home "['<Super>e']"
gsettings set org.gnome.mutter center-new-windows true
gsettings set org.gnome.mutter workspaces-only-on-primary true
gsettings set org.gnome.tweaks show-extensions-notice false
EOC

echo ""
echo "FEDORA-SETUP: Succesfully configured Usability Improvements in GNOME Desktop Interface (behaviours, locale, hotkeys)."
echo ""

} || {

echo ""
echo "FEDORA-SETUP: Failed to configure Usability Improvements in GNOME Desktop Interface (behaviours, locale, hotkeys)."
echo ""

}

# Apps and UX configs for different Gnome Shell version equal or superior to 42
{

if [ "$(gnome-shell --version | cut -d" " -f3 | cut -d. -f1)" -ge 42 ]
then
    # Dark mode preference mode for compliant apps and extensions
    sudo -E -u $user_selected bash <<-EOC
gsettings set org.gnome.desktop.interface color-scheme prefer-dark
EOC

    # File Chooser configuration (GTK4+)
    sudo -E -u $user_selected bash <<-EOC
gsettings set org.gtk.gtk4.Settings.FileChooser sort-directories-first true
gsettings set org.gtk.gtk4.Settings.FileChooser date-format 'with-time'
gsettings set org.gtk.gtk4.Settings.FileChooser show-hidden true
gsettings set org.gtk.gtk4.Settings.FileChooser type-format 'mime'
EOC

    # Text Editor configuration (gedit substitute in GNOME 42+)
    sudo -E -u $user_selected bash <<-EOC
gsettings set org.gnome.TextEditor highlight-current-line true
gsettings set org.gnome.TextEditor indent-style 'space'
gsettings set org.gnome.TextEditor show-line-numbers true
gsettings set org.gnome.TextEditor show-map true
gsettings set org.gnome.TextEditor show-right-margin true
gsettings set org.gnome.TextEditor tab-width 4
gsettings set org.gnome.TextEditor right-margin-position 120
EOC

    # Weather widget configuration (GTK4+)
    sudo -E -u $user_selected bash <<-EOC
gsettings set org.gnome.GWeather4 temperature-unit 'centigrade'
EOC

mkdir -p /$home_selected/.config/gtk-4.0
cp -r /usr/share/themes/Flat-Remix-LibAdwaita-Blue-Dark-Solid/* /$home_selected/.config/gtk-4.0/
chown -R $user_selected:$user_selected $home_selected/.config/gtk-4.0/*

fi

echo ""
echo "FEDORA-SETUP: Succesfully configured GNOME Shell 43+ specifics."
echo ""

} || {

echo ""
echo "FEDORA-SETUP: Failed to configure GNOME Shell 43+ specifics)."
echo ""

}

# GNOME Shell Default Extensions Activation
{

sudo -E -u $user_selected bash <<EOC
gsettings set org.gnome.shell enabled-extensions "['user-theme@gnome-shell-extensions.gcampax.github.com', 'appindicatorsupport@rgcjonas.gmail.com']"

gsettings set org.gnome.shell disabled-extensions "['background-logo@fedorahosted.org']"
EOC

echo ""
echo "FEDORA-SETUP: Succesfully activated built-in GNOME shell extensions."
echo ""

} || {

echo ""
echo "FEDORA-SETUP: Failed to activated built-in GNOME shell extensions."
echo ""

}
