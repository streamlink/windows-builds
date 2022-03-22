streamlink/windows-installer
====

Windows installer builds for [Streamlink](https://github.com/streamlink/streamlink).

Please see [Streamlink's install documentation](https://streamlink.github.io/install.html) for more details and different install methods.


## Installer contents

- [an embedded Python environment](https://github.com/streamlink/python-windows-embed)
- [Streamlink and its dependencies](https://github.com/streamlink/streamlink)
- [FFmpeg, for muxing streams](https://github.com/streamlink/FFmpeg-Builds)


## Flavors

- Python 3.10, x86_64
- Python 3.10, x86
- Python 3.8, x86_64
- Python 3.8, x86

[Python 3.8](https://endoflife.date/python) is the last Python branch which still supports [Windows 7](https://endoflife.date/windows).


## Download

### Stable releases

Builds of official Streamlink releases.  
Download from the [releases page](https://github.com/streamlink/windows-installer/releases).

### Nightly builds  

Built once each day at midnight UTC from Streamlink's master branch.  
This includes the most recent changes, but is not considered "stable".  
Download from the build-artifacts of the [scheduled nightly build runs](https://github.com/streamlink/windows-installer/actions?query=event%3Aschedule+is%3Asuccess+branch%3Amaster) (requires a GitHub login).


## Notes

The installers perform the following tasks:

- The `bin` subdirectory of the installation path gets added to the system's `PATH` environment variable, so the `streamlink.exe` and `streamlinkw.exe` executables can be resolved without having to specify the absolute or relative path to these files.
- An entry gets added to the system's list of installed software, and an uninstaller gets generated.
- When installing, the `pkgs` subdirectory gets deleted recursively before unpacking any files, to ensure that old and unsupported python package files of previous installations don't exist when upgrading without uninstalling.


## Additional notes

Both the embedded Python builds and FFmpeg builds are unofficial and unsigned, as we're building them ourselves. Due to this circumstance, certain antivirus programs might trigger false positive alerts. The sources, build instructions and build logs can be read and observed in the repositories linked above.


## Developer notes

### Build requirements

- GNU/Linux environment
- [git](https://git-scm.com/)
- [Python 3.7+](https://www.python.org/) and the most recent version of [pip](https://pip.pypa.io/en/stable/)
  - [virtualenv](https://pypi.org/project/virtualenv/)
  - [pynsist](https://pypi.org/project/pynsist/) >=2.8
  - [distlib](https://pypi.org/project/distlib/) >=0.3.3, !=0.3.4
- [NSIS](https://nsis.sourceforge.io/Main_Page)
- [jq](https://stedolan.github.io/jq/)
- [gawk](https://www.gnu.org/software/gawk/)
- [Imagemagick](https://imagemagick.org/index.php)
- [Inkscape](https://inkscape.org/)

### How to

The installer build configurations can be found in the `config.json` file. Here, the default Streamlink source and version are defined that will be used when building, in addition to installer assets, and most importantly, the various build flavors.

The `installer.cfg` file defines the pynsist configuration, and the `installer.nsi` file is used as an extension for pynsist's default NSIS template.

Each build flavor includes the source of an embedded Python build and the fixed set of Streamlink's dependency versions plus checksums for that specific build (Streamlink doesn't provide its own dependency lockfile).

In order to get an update for the dependency JSON data of a specific build flavor, run

```sh
./get-dependencies.sh "${FLAVOR}" "${GITSOURCE}" "${GITREF}"
```

with `GITSOURCE` and `GITREF` being an optional override.

Building the installer works the same way, by running

```sh
./build.sh "${FLAVOR}" "${GITSOURCE}" "${GITREF}"
```

with `GITSOURCE` and `GITREF` being once again optional overrides.  
Building the installer requires an activated virtual Python environment.

Successfully built installers can be found in the `./dist` directory. NSIS unfortunately doesn't support reproducible builds, so the checksums will always vary.
