#!/usr/bin/python

import json
from operator import attrgetter
from itertools import groupby
import urllib2

URL = "https://scicast.org/trades/?user_id={0}&include_current_probs=False"


FILENAME = 'trades.txt'
ALL_KEYS = ['q_id', 'q_name', 'c_name', 'assumption_q_id', 'assumption_q_name',
            'assumption_c_name', 'exposure']
KEYS     = ALL_KEYS[:-1]

def download_trades(uid=1, file_name=FILENAME):
    url = URL.format(uid)
    u = urllib2.urlopen(url)
    f = open(file_name, 'wb')
    meta = u.info()
    file_size = int(meta.getheaders("Content-Length")[0])
    print "Downloading: %s Size: %s MiB" % (file_name, file_size // 1e6)
    
    file_size_dl = 0
    block_sz = 8192
    while True:
        buffer = u.read(block_sz)
        if not buffer:
            break
            
        file_size_dl += len(buffer)
        f.write(buffer)
        status = r"%10d  [%3.2f%%]" % (file_size_dl, file_size_dl * 100. / file_size)
        status = status + chr(8)*(len(status)+1)
        print status,
    f.close()


class Position(object):
    def __init__(self, **data):
        for key in ALL_KEYS:
            setattr(self, key, data[key])

    def to_tsv(self):
        fields = [getattr(self, key) for key in ALL_KEYS]
        return "\t".join(['{0}'.format(field) for field in fields])


def _remove_whitespace(string_):
    for char in ['\n', '\t', '\r']:
        string_ = string_.replace(char, '')
    return string_

class ScicastPosition(object):
    def __init__(self, uid=None):
        self.position = []
        self.edits = []
        if uid is not None:
            download_trades(uid=uid)

    def parse_edits(self, filename=FILENAME, exclude_resolved=True):
        with open(filename, 'r') as f:
            data = json.loads(f.readlines()[0])
        for edit in data:
            if exclude_resolved and edit['asset_resolution'] is not None:
                continue
            for ix, choice in enumerate(edit['question']['choices']):
                edit_data = {
                    'q_id'              : edit['question']['id'],
                    'q_name'            : _remove_whitespace(
                        edit['question']['name']
                    ),
                    'c_name'            : _remove_whitespace(
                        choice['name']
                    ),
                    'exposure'          : edit['assets_per_option'][ix],
                    'assumption_q_id'   : (None if edit['assumptions'] == [] else
                                         edit['assumptions'][0]['id']),
                    'assumption_q_name' : (None if edit['assumptions'] == [] else
                                           _remove_whitespace(
                                               edit['assumptions'][0]['name']
                                           )
                                       ),
                    'assumption_c_name' : (None if edit['assumptions'] == [] else
                                           _remove_whitespace(
                                               edit['assumptions'][0]['choices'][
                                                   edit['assumptions'][0]['dimension']
                                               ]['name']
                                           )
                                       )
                }
                self.edits.append(Position(**edit_data))
                self.edits.sort(key=attrgetter(*KEYS))

    def aggregate_position(self):
        for (q_id, q_name, c_name,
             assumption_q_id,
             assumption_q_name,
             assumption_c_name), edits in groupby(self.edits, key=attrgetter(*KEYS)):
            exposure = sum(getattr(edit, 'exposure') for edit in edits)
            position_data = dict([(key, locals()[key]) for key in ALL_KEYS])
            self.position.append(Position(**position_data))

    def save_position_as_tsv(self):
        with open('position.tsv', 'w') as f:
            f.write(self._position_to_tsv())
    def save_edits_as_tsv(self):
        with open('edits.tsv', 'w') as f:
            f.write(self._edits_to_tsv())

    def _position_to_tsv(self):
        output = ("Question id\tQuestion name\tChoice name\t"
                  "Assumption q id\tAssumption q name\t"
                  "Assumption choice name\texposure\n")
        for position in self.position:
            output += '\t'.join([repr(getattr(position, key)) for key in ALL_KEYS])
            output += '\n'
        return output

    def _edits_to_tsv(self):
        output = ("Question id\tQuestion name\tChoice name\t"
                  "Assumption q id\tAssumption q name\t"
                  "Assumption choice name\texposure\n")
        for position in self.edits:
            output += '\t'.join([repr(getattr(position, key)) for key in ALL_KEYS])
            output += '\n'
        return output


def go(exclude_resolved=True):
    parser = ScicastPosition()
    print 'Parsing...'
    parser.parse_edits(exclude_resolved=exclude_resolved)
    print 'done'
    print 'Aggregating ...'
    parser.aggregate_position()
    print 'done'
    print 'Saving...'
    parser.save_edits_as_tsv()
    parser.save_position_as_tsv()
    print 'done'

                
go()
