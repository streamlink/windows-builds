Changelog - streamlink/windows-builds
====

## 5.1.2-1 (2022-12-03)

- Updated Streamlink to 5.1.2, updated its dependencies

## 5.1.1-1 (2022-11-23)

- Updated Streamlink to 5.1.1

## 5.1.0-1 (2022-11-14)

- Updated Streamlink to 5.1.0, updated its dependencies
- Updated Python from 3.8.14 to 3.8.15
- Updated Python from 3.10.7 to 3.10.8
- Bumped distlib from 0.3.3 to 0.3.6

## 5.0.1-1 (2022-09-22)

- Updated Streamlink to 5.0.1

## 5.0.0-1 (2022-09-16)

- Updated Streamlink to 5.0.0, updated its dependencies
- Updated Python from 3.8.13 to 3.8.14
- Updated Python from 3.10.6 to 3.10.7

## 4.3.0-1 (2022-08-15)

- Updated Streamlink to 4.3.0, updated its dependencies
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
