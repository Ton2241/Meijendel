#!/usr/bin/env python3
"""Validate physical TRIM trial output before callers create any directories."""
import argparse
import os
from pathlib import Path, PurePosixPath
import sys

sys.path.insert(0, str(Path.home() / 'Documents/GitHub/VWG_Project/scripts'))
import trial_storage as storage
from trial_storage import checked_output, T7, TRIALS


def checked_batch_output(value):
    output = checked_output(value)
    # saveRDS follows file symlinks; checkpoints and sidecars need their own gate.
    for suffix in ['', '.partial', '.manifest.rds']:
        candidate = Path(value + suffix)
        if candidate.is_symlink() or checked_output(str(candidate)).parent != output.parent:
            raise ValueError('batch, checkpoint of manifest is een ontsnappende verwijzing')
    return output


def checked_worker_output(directory, backend, forwarded):
    # The R CLI uses --output independently of --output-dir. Validate both.
    if forwarded.count('--output') != 1:
        raise ValueError('worker vereist precies één doorgestuurd --output-pad')
    pos = forwarded.index('--output') + 1
    if pos == len(forwarded) or forwarded[pos].startswith('--'):
        raise ValueError('doorgestuurd --output-pad ontbreekt')
    value = forwarded[pos]
    if backend == 'docker':
        container_path = PurePosixPath(value)
        base = PurePosixPath('/work/output')
        if '..' in container_path.parts or not container_path.is_relative_to(base) or container_path == base:
            raise ValueError('Docker --output moet onder /work/output liggen')
        value = str(directory / container_path.relative_to(base))
    output = checked_batch_output(value)
    if output == directory or not output.is_relative_to(directory):
        raise ValueError('--output ligt buiten --output-dir')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output')
    parser.add_argument('--worker-backend', choices=['local', 'docker'])
    parser.add_argument('--batch', action='store_true')
    parser.add_argument('--check-child', action='append', default=[])
    args, forwarded = parser.parse_known_args()
    try:
        directory = checked_batch_output(args.output) if args.batch else checked_output(args.output)
        for child in args.check_child:
            checked = checked_output(str(directory / child))
            if checked == directory or not checked.is_relative_to(directory):
                raise ValueError('kindpad ontsnapt aan de eigen proefmap: ' + child)
        if args.worker_backend:
            checked_worker_output(directory, args.worker_backend, forwarded)
        elif forwarded:
            raise ValueError('onbekende controleargumenten')
    except (OSError, RuntimeError, ValueError) as error:
        print('T7-uitvoer geweigerd: ' + str(error), file=sys.stderr)
        return 2
    print(directory)
    return 0


if __name__ == '__main__':
    sys.exit(main())
