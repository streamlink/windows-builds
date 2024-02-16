Changelog - streamlink/windows-builds
====

## 6.6.0-1 (2024-02-16)

- Updated Streamlink to 6.6.0, updated its dependencies
- Updated Python from 3.12.1 to 3.12.2
- Updated Python from 3.8.18 to 3.8.18-18-g64c9fcc8

## 6.5.1-1 (2024-01-16)

- Updated Streamlink to 6.5.1, updated its dependencies
- Switched from Python 3.11 to Python 3.12

## 6.5.0-2 (2023-12-17)

- Fixed missing transitive dependencies of Python 3.8 builds

## 6.5.0-1 (2023-12-16)

- Updated Streamlink to 6.5.0, updated its dependencies
- Updated Python from 3.11.6 to 3.11.7
- Updated Python from 3.8.18 to 3.8.18-8-g575c99a5
- Added brotli dependency
- Rewritten dependencies setup (update/build scripts and config format)

## 6.4.2-1 (2023-11-28)

- Updated Streamlink to 6.4.2

## 6.4.1-1 (2023-11-22)

- Updated Streamlink to 6.4.1

## 6.4.0-1 (2023-11-21)

- Updated Streamlink to 6.4.0, updated its dependencies
- Updated FFmpeg to n6.1, with latest library versions

## 6.3.1-1 (2023-10-26)

- Updated Streamlink to 6.3.1

## 6.3.0-1 (2023-10-25)

- Updated Streamlink to 6.3.0, updated its dependencies
- Updated Python from 3.11.5 to 3.11.6

## 6.2.1-1 (2023-10-03)

- Updated Streamlink to 6.2.1, updated its dependencies
- Updated FFmpeg to n6.0-35, with latest library versions
- Switched build-config format from JSON to YML

## 6.2.0-1 (2023-09-14)

- Updated Streamlink to 6.2.0, updated its dependencies

## 6.1.0-2 (2023-08-27)

- Updated Python from 3.11.4 to 3.11.5 (OpenSSL 1.1.1u -> 3.0.9)
- Updated Python from 3.8.17 to 3.8.18
- Fixed DLL-loading issues of embedded Python builds ("SSL module is not available")

## 6.1.0-1 (2023-08-16)

- Updated Streamlink to 6.1.0, updated its dependencies
- Added param to get-dependencies script for optional dependency overrides

## 6.0.1-1 (2023-08-02)

- Updated Streamlink to 6.0.1, updated its dependencies

## 6.0.0-1 (2023-07-20)

- Updated Streamlink to 6.0.0, updated its dependencies
- Updated Python from 3.11.3 to 3.11.4
- Updated Python from 3.8.16 to 3.8.17
- Updated Streamlink config file ([`--player` breaking changes](https://streamlink.github.io/migrations.html#player-path-only-player-cli-argument))
- Added new page to installer for overwriting the existing config file

## 5.5.1-2 (2023-05-22)

- Updated dependencies ([urllib3 2.x](https://urllib3.readthedocs.io/en/2.0.2/v2-migration-guide.html#what-are-the-important-changes), [requests 2.31.0](https://github.com/psf/requests/releases/tag/v2.31.0))
- Updated Python from 3.8.16 to 3.8.16-18-g9f89c471

## 5.5.1-1 (2023-05-08)

- Updated Streamlink to 5.5.1, updated its dependencies

## 5.5.0-1 (2023-05-05)

- Updated Streamlink to 5.5.0, updated its dependencies

## 5.4.0-1 (2023-04-12)

- Updated Streamlink to 5.4.0, updated its dependencies
- Updated Python from 3.11.2 to 3.11.3
- Updated FFmpeg from n5.1.2-9 to n6.0-3

## 5.3.1-1 (2023-02-25)

- Updated Streamlink to 5.3.1

## 5.3.0-1 (2023-02-18)

- Updated Streamlink to 5.3.0, updated its dependencies
- Updated Python from 3.11.1 to 3.11.2

## 5.2.1-1 (2023-01-23)

- Updated Streamlink to 5.2.1, updated its dependencies
- Updated FFmpeg from n5.1-1 to n5.1.2-9

## 5.1.2-2 (2022-12-14)

- Switched from Python 3.10 to Python 3.11
- Updated Python from 3.8.15 to 3.8.16
- Updated dependencies

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
- Updated FFmpeg to n5.1-1
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
