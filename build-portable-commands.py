import argparse
import datetime
import io
import os
import time
import yaml
from pathlib import Path
from textwrap import dedent

from freezegun import freeze_time
# https://github.com/takluyver/pynsist/blob/2.8/nsist/commands.py
from nsist.commands import prepare_bin_directory


def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=Path, default=Path(__file__).parent / "portable.yml")
    parser.add_argument("--target", type=Path, required=True)
    parser.add_argument("--bitness", type=int, choices=[32, 64], required=True)
    parser.add_argument("--prepend-ffmpeg", action="store_true", default=False)

    return parser.parse_args()


if __name__ == "__main__":
    args = get_args()

    with open(args.config, "r") as fp:
        data = yaml.load(fp, yaml.Loader)

    extra_preamble = io.StringIO()
    if args.prepend_ffmpeg:
        extra_preamble.write(dedent("""
            sys.argv.insert(1, f"--ffmpeg-ffmpeg={installdir}\\\\ffmpeg\\\\ffmpeg.exe")
        """))

    commands = data.get("commands")
    for command in commands.values():
        command.update(extra_preamble=extra_preamble)

    timestamp = int(os.getenv("SOURCE_DATE_EPOCH", time.time()))
    with freeze_time(datetime.datetime.utcfromtimestamp(timestamp)):
        prepare_bin_directory(
            args.target,
            commands,
            bitness=args.bitness,
        )
