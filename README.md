# atom-ipython-exec
Send `python code` from `Atom` to be executed into an `ipython` session running inside a `terminal`. Tested on *Mac OS X* and *Ubuntu*; in the former case, the reference terminal application is [`iTerm2`](https://www.iterm2.com/), whereas [`gnome-terminal`](https://wiki.gnome.org/Apps/Terminal) is used in the latter.

On *Ubuntu*, it requires both `xdotool` and `xvkbd` to be installed; please install them with:
```bash
sudo apt-get install xdotool
sudo apt-get install xvkbd
```

**NB:** This package is a fork of [r-exec](https://github.com/pimentel/atom-r-exec).
