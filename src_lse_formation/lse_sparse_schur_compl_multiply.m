function [schur_out]=lse_sparse_schur_compl_multiply(schur_in, Ae, A_inv)

trace_call('lse_sparse_schur_compl_multiply');
trace_io('in', 'lse_sparse_schur_compl_multiply');
schur_out = Ae * A_inv * Ae' * schur_in;

fprintf ('+') ;
trace_io('out', 'lse_sparse_schur_compl_multiply');
