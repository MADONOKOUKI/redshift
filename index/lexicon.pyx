from cymem.cymem cimport Pool
from libc.stdint cimport uint64_t
from murmurhash.mrmr cimport hash64

import os.path


BLANK_WORD = Lexeme(0, 0, 0, 0, False, False, False)

cdef Lexicon _LEXICON = None

def load(): # Called in index/__init__.py
    global _LEXICON
    if _LEXICON is None:
        _LEXICON = Lexicon()


cpdef size_t lookup(bytes word):
    global _LEXICON
    return _LEXICON.lookup(word)


cpdef bytes get_str(size_t word):
    global _LEXICON
    if _LEXICON is None:
        _LEXICON = Lexicon()
    return _LEXICON.strings.get(word, '')

def lexicon_size():
    global _LEXICON
    if _LEXICON is None:
        _LEXICON = Lexicon()
    return _LEXICON.mem.size


cdef class Lexicon:
    def __cinit__(self, loc=None):
        self.mem = Pool()
        self.words = PreshMap()
        self.strings = {}
        cdef object line
        cdef size_t i, word_id, freq
        cdef float upper_pc, title_pc
        if loc is None:
            loc = os.path.join(os.path.dirname(__file__), 'bllip-clusters')
        case_stats = {}
        for line in open(os.path.join(os.path.dirname(__file__), 'english.case')):
            word, upper, title = line.split()
            case_stats[word] = (float(upper), float(title))
        print "Loading vocab from ", loc 
        cdef Lexeme* w
        for line in open(loc):
            cluster_str, word, freq_str = line.split()
            # Decode as a little-endian string, so that we can do & 15 to get
            # the first 4 bits. See _parse_features.pyx
            cluster = int(cluster_str[::-1], 2)
            #upper_pc = float(pieces[1])
            #title_pc = float(pieces[2])
            upper_pc, title_pc = case_stats.get(word.lower(), (0.0, 0.0))
            w = init_word(self.mem, word, cluster, upper_pc, title_pc, int(freq_str))
            self.words.set(_hash_str(word), w)
            self.strings[<size_t>w] = word

    cdef size_t lookup(self, bytes word):
        cdef uint64_t hashed = _hash_str(word)
        cdef Lexeme* w = <Lexeme*>self.words.get(hashed)
        if w == NULL:
            w = init_word(self.mem, word, 0, 0.0, 0.0, 0)
            self.words.set(hashed, w)
            self.strings[<size_t>w] = word
        return <size_t>w


cpdef bytes normalize_word(word):
    if '-' in word and word[0] != '-':
        return b'!HYPHEN'
    elif word.isdigit() and len(word) == 4:
        return b'!YEAR'
    elif word[0].isdigit():
        return b'!DIGITS'
    else:
        return word.lower()
    

cdef Lexeme* init_word(Pool mem, bytes py_word, size_t cluster,
                     float upper_pc, float title_pc, size_t freq) except NULL:
    cdef Lexeme* word = <Lexeme*>mem.alloc(1, sizeof(Lexeme))
    word.orig = _hash_str(py_word)
    if freq < 10:
        word.norm = 0
    else:
        word.norm = _hash_str(normalize_word(py_word))
    word.suffix = _hash_str(py_word[-3:])
    word.prefix = ord(py_word[0])
    
    # Cut points determined by maximum information gain
    word.oft_upper = upper_pc >= 0.05
    word.oft_title = title_pc >= 0.3
    word.non_alpha = not py_word.isalpha()
    # TODO: Fix cluster stuff
    word.cluster = cluster
    return word


cdef inline uint64_t _hash_str(bytes s):
    return hash64(<char*>s, len(s), 0)
