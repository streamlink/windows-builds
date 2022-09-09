Changelog - streamlink/windows-builds
====

## master

- Updated Python from 3.8.13 to 3.8.14
- Updated Python from 3.10.5 to 3.10.6

## 4.3.0-1 (2022-08-15)

- Updated Python from 3.10.5 to 3.10.6

## 4.2.0-2 (2022-08-02)

- Fixed missing dist-info directory in installer, causing an error when `--loglevel=debug` was set due to missing metadata of the streamlink package
- Updated FFmpeg to 5.1
- Added `requirements.txt` for easier build dependency specification

## 4.2.0-1 (2022-07-09)

- Updated Streamlink to 4.2.0, updated its dependencies

## 4.1.0-3 (2022-06-11)

- Implemented portable builds
- Renamed repository from streamlink/windows-installer to streamlink/windows-builds
- Upgraded Python from 3.10.3 to 3.10.5
- Moved Python standard library into zip archive for both installers and portable builds
- Added changelog

## 4.1.0-2 (2022-06-01)

- Updated lxml dependency to 4.9.0

## 4.1.0-1 (2022-05-30)

- Updated Streamlink to 4.1.0, updated its dependencies

## 4.0.0-1 (2022-05-01)

- Updated Streamlink to 4.0.0, updated its dependencies
- Added check for removing old and unsupported `rtmp-rtmpdump` parameter from users' config files in the installers

## 3.2.0-1 (2022-03-22)

- Initial release, based on Streamlink 3.2.0
