/*
Copyright (c) 2014 Microsoft Corporation. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Author: Leonardo de Moura
*/
#include "library/util.h"
#include "library/definitional/equations.h"

namespace lean{
void initialize_definitional_module() {
    initialize_equations();
}

void finalize_definitional_module() {
    finalize_equations();
}
}
