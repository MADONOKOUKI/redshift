cimport index.hashes
from libcpp.utility cimport pair

from libc.stdint cimport int64_t, uint64_t
from ext.sparsehash cimport *

DEF MAX_PARAMS = 5000000


cdef struct DenseParams:
    double* w
    double* acc
    size_t* last_upd


cdef struct SquareFeature:
    DenseParams* parts    
    bint* seen
    double total
    size_t nr_seen


cdef struct DenseFeature:
    double* w
    double* acc
    double total
    size_t* last_upd
    uint64_t id
    size_t nr_seen
    size_t s
    size_t e


cdef class Perceptron:
    cdef size_t nr_class
    cdef double *scores
    cdef DenseFeature** _active_dense
    cdef SquareFeature** _active_square
    cdef object path
    cdef double n_corr
    cdef double total

    cdef size_t nr_raws
    cdef DenseFeature** raws

    cdef size_t div
    cdef size_t now
 
    cdef dense_hash_map[uint64_t, size_t] W
    cdef index.hashes.ScoresCache cache

    cdef int add_feature(self, uint64_t f)
    cdef int64_t update(self, size_t gold_i, size_t pred_i,
                        uint64_t* features, double weight) except -1
    cdef int fill_scores(self, uint64_t* features, double* scores)
