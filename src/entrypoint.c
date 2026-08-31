// Forward routine registration from C to Rust so the linker retains the
// extendr static library.

void R_init_arity_extendr(void *dll);

void R_init_arity(void *dll) {
    R_init_arity_extendr(dll);
}
