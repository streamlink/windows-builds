streamlink/windows-builds
====

Windows installer and portable archive builds for [Streamlink](https://github.com/streamlink/streamlink).

Please see [Streamlink's install documentation](https://streamlink.github.io/install.html) for more details and different install methods.

The windows-builds changelog can be found [here](https://github.com/streamlink/windows-builds/blob/master/CHANGELOG.md).


## Contents

- [an embedded Python environment](https://github.com/streamlink/python-windows-embed)
- [Streamlink and its dependencies](https://github.com/streamlink/streamlink)
- [FFmpeg, for muxing streams](https://github.com/streamlink/FFmpeg-Builds)


## Download

### Stable releases

Builds of official Streamlink releases.  
Download from the [releases page](https://github.com/streamlink/windows-builds/releases).

### Preview builds

Built on each push to Streamlink's master branch.  
This includes the most recent changes, but is not considered "stable".  
Download from the build-artifacts of the [preview-build runs](https://github.com/streamlink/windows-builds/actions/workflows/preview-build.yml) (requires a GitHub login).


## Notes

### Installers

- When installing, the `bin` subdirectory of the installation path gets added to the system's `PATH` environment variable, so the `streamlink.exe` and `streamlinkw.exe` executables can be resolved without having to specify the absolute or relative path to these files.
- An entry gets added to the system's list of installed software, and an uninstaller gets generated.
- When installing, the `pkgs` subdirectory gets deleted recursively before unpacking any files, to ensure that old and unsupported python package files of previous installations don't exist when upgrading without uninstalling.
- A default config file gets written to `%APPDATA%\streamlink\config` if it doesn't exist.
- The [`ffmpeg-ffmpeg`](https://streamlink.github.io/cli.html#cmdoption-ffmpeg-ffmpeg) argument in the config file always gets updated to the current install-location.
- Python modules not part of the standard library will be byte-compiled after installation.

### Portable archives

- The `bin` directory with the `streamlink.exe` and `streamlinkw.exe` executables won't be added to the `PATH` environment variable.
- Since no config file will be generated either, users will need to create one themselves, including the [`ffmpeg-ffmpeg`](https://streamlink.github.io/cli.html#cmdoption-ffmpeg-ffmpeg) argument. Otherwise, [`--ffmpeg-ffmpeg`](https://streamlink.github.io/cli.html#cmdoption-ffmpeg-ffmpeg) needs to be set on the command line to enable muxed output streams.
- Python modules not part of the standard library will be byte-compiled upon first execution.


## Additional notes

Both the embedded Python builds and FFmpeg builds are unofficial and unsigned, as we're building them ourselves. Due to this circumstance, certain antivirus programs might trigger false positive alerts. The sources, build instructions and build logs can be read and observed in the repositories linked above.


## Developer notes

### Build requirements

- GNU/Linux environment
- [git](https://git-scm.com/)
- [Python 3.9+](https://www.python.org/) and the most recent version of [pip](https://pip.pypa.io/en/stable/)
  - [virtualenv](https://pypi.org/project/virtualenv/)
  - [pynsist](https://pypi.org/project/pynsist/) `==2.8`
  - [distlib](https://pypi.org/project/distlib/) `==0.3.6`
  - [freezegun](https://pypi.org/project/freezegun/)
- [NSIS](https://nsis.sourceforge.io/Main_Page)
- [jq](https://stedolan.github.io/jq/)
- [gawk](https://www.gnu.org/software/gawk/)
- [Imagemagick](https://imagemagick.org/index.php)
- [Inkscape](https://inkscape.org/)

### How to

The build configurations can be found in the `config.yml` file. Here, the default Streamlink source and version are defined that will be used when building, in addition to assets, and most importantly, the various build flavors.

The `installer.cfg` file defines the pynsist configuration, and the `installer.nsi` file is used as an extension for pynsist's default NSIS template. `portable.yml` on the other hand defines the configuration for the portable builds.

Each build flavor includes the source of an embedded Python build and the fixed set of Streamlink's dependency versions plus checksums for that specific build (Streamlink doesn't provide its own dependency lockfile).

In order to get an update for the dependency JSON data of a specific build flavor, run

```sh
./get-dependencies.sh "${FLAVOR}" "${GITSOURCE}" "${GITREF}" "${OPT_DEPS}"
```

with `GITSOURCE`, `GITREF` and `OPT_DEPS` being an optional override.

Building the installers and portable archives works the same way, by running

```sh
./build-installer.sh "${FLAVOR}" "${GITSOURCE}" "${GITREF}"
./build-portable.sh "${FLAVOR}" "${GITSOURCE}" "${GITREF}"
```

with `GITSOURCE` and `GITREF` being once again optional overrides.  
Building the installer and portable archives requires an activated virtual Python environment.

Successfully built installers and portable archives can be found in the `./dist` directory. NSIS unfortunately doesn't support reproducible builds, so the checksums of the installers will always vary. The portable archives however are reproducible if the `SOURCE_DATE_EPOCH` env var is set.
