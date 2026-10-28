#!/usr/bin/env python3
# Copyright 2026 Ego Hygiene
# SPDX-License-Identifier: MIT
"""Run a startup fixture with real terminal descriptors and a bounded lifetime."""

import argparse
import errno
import fcntl
import os
import pty
import select
import signal
import subprocess
import sys
import termios
import time


def stop_fixture_group(process):
    # Reap a completed session leader before signaling its group. Darwin can
    # report EPERM for a group containing only the unreaped leader's zombie.
    process.poll()
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        return
    except PermissionError as error:
        # A nonblocking poll can still miss the leader's exit while Darwin's
        # group iterator already excludes it. Allow a bounded reap before
        # deciding whether EPERM denotes a live, inaccessible group.
        try:
            process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            raise error
        # Other unreaped descendants can also leave a zombie-only group. Do
        # not hide a permission failure while any live group member remains.
        members = subprocess.run(
            ["ps", "-axo", "pgid=,stat="], check=True, timeout=2,
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
        )
        for line in members.stdout.splitlines():
            fields = line.split()
            if len(fields) == 2 and fields[0] == str(process.pid) and not fields[1].startswith("Z"):
                raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stdin-pipe", action="store_true")
    parser.add_argument("--stdout-pipe", action="store_true")
    parser.add_argument("--timeout", type=float, default=10)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    options = parser.parse_args()
    command = options.command
    if command and command[0] == "--":
        command = command[1:]
    if not command:
        parser.error("a command is required")

    master, slave = pty.openpty()

    def child_session():
        os.setsid()
        fcntl.ioctl(slave, termios.TIOCSCTTY, 0)

    process = subprocess.Popen(
        command,
        stdin=subprocess.DEVNULL if options.stdin_pipe else slave,
        stdout=subprocess.PIPE if options.stdout_pipe else slave,
        stderr=subprocess.STDOUT,
        preexec_fn=child_session,
        close_fds=True,
    )
    os.close(slave)
    descriptor = process.stdout.fileno() if options.stdout_pipe else master
    chunks = []
    deadline = time.monotonic() + options.timeout
    timed_out = False
    try:
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                timed_out = True
                break
            readable, _, _ = select.select([descriptor], [], [], min(remaining, 0.1))
            if readable:
                try:
                    chunk = os.read(descriptor, 65536)
                except OSError as error:
                    if error.errno != errno.EIO:
                        raise
                    break
                if not chunk:
                    break
                chunks.append(chunk)
            elif process.poll() is not None:
                break
    finally:
        # Also clean up a fixture's descendants if a broken startup hook leaks
        # them, so a failing regression test cannot leave background work behind.
        try:
            stop_fixture_group(process)
        finally:
            if process.poll() is None:
                process.kill()
            process.wait(timeout=2)
            os.close(master)
            if process.stdout is not None:
                process.stdout.close()

    sys.stdout.buffer.write(b"".join(chunks).replace(b"\r\n", b"\n"))
    if timed_out:
        print("startup fixture exceeded its deadline", file=sys.stderr)
        return 124
    return process.returncode if process.returncode >= 0 else 128 - process.returncode


if __name__ == "__main__":
    sys.exit(main())
